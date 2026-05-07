import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

@MainActor
class RaceSettingsViewModel: ObservableObject {
    @Published var currentDuration: String = "weekly"
    @Published var isRaceActive: Bool = false
    @Published var isLoading: Bool = true
    @Published var isSaving: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil
    private let db = Firestore.firestore()

    func load(competitionId: String) {
        isLoading = true
        let group = DispatchGroup()
        group.enter()
        db.collection("competitions").document(competitionId).getDocument { [weak self] snapshot, _ in
            guard let self else { group.leave(); return }
            self.currentDuration = snapshot?.data()?["race_duration"] as? String ?? "weekly"
            group.leave()
        }
        group.enter()
        db.collection("competition_races").whereField("competition_id", isEqualTo: competitionId)
            .whereField("status", isEqualTo: "active").limit(to: 1)
            .getDocuments { [weak self] snapshot, _ in
                guard let self else { group.leave(); return }
                if let doc = snapshot?.documents.first, let endDate = (doc.data()["end_date"] as? Timestamp)?.dateValue(), Date() < endDate {
                    self.isRaceActive = true
                    self.currentDuration = doc.data()["duration"] as? String ?? self.currentDuration
                } else { self.isRaceActive = false }
                group.leave()
            }
        group.notify(queue: .main) { [weak self] in self?.isLoading = false }
    }

    func setDuration(_ duration: String, competitionId: String) async {
        guard !isRaceActive else { errorMessage = "Cannot change duration while a competition is active"; return }
        isSaving = true; errorMessage = nil; successMessage = nil
        do {
            _ = try await Functions.functions().httpsCallable("setRaceDuration").call(["competitionId": competitionId, "duration": duration])
            currentDuration = duration
            successMessage = "Competition duration updated to \(duration)"
        } catch { errorMessage = error.localizedDescription }
        isSaving = false
    }
}

struct RaceSettingsView: View {
    let competition: Competition
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RaceSettingsViewModel()

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left").resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27).foregroundColor(AppTheme.iconColor)
                    }
                    Spacer()
                    Text("Duration").font(.system(size: 18, weight: .bold)).foregroundColor(AppTheme.primaryText)
                    Spacer()
                    Color.clear.frame(width: 27, height: 27)
                }
                .padding(.horizontal, 20).padding(.vertical, 20)

                if viewModel.isLoading {
                    Spacer()
                    HStack { Spacer(); ProgressView().tint(AppTheme.primaryText); Spacer() }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            if viewModel.isRaceActive {
                                HStack(spacing: 12) {
                                    Image(systemName: "lock.fill").font(.system(size: 16)).foregroundColor(.orange)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Competition in progress").font(.system(size: 15, weight: .bold)).foregroundColor(.orange)
                                        Text("Duration cannot be changed while a competition is active. Settings will apply to the next competition.")
                                            .font(.system(size: 13)).foregroundColor(AppTheme.secondaryText)
                                    }
                                }
                                .padding(16).background(Color.orange.opacity(0.1)).cornerRadius(12).padding(.horizontal, 20)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Competition Duration").font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.secondaryText).padding(.horizontal, 20)
                                VStack(spacing: 0) {
                                    DurationOptionRow(title: "Weekly", subtitle: "7 days — contribute once, play daily all week",
                                        icon: "calendar", isSelected: viewModel.currentDuration == "weekly",
                                        isLocked: viewModel.isRaceActive, isLoading: viewModel.isSaving && viewModel.currentDuration != "weekly"
                                    ) { Task { await viewModel.setDuration("weekly", competitionId: competition.id) } }
                                    Divider().background(AppTheme.divider)
                                    DurationOptionRow(title: "Daily", subtitle: "24 hours — fresh competition and prize pool every day",
                                        icon: "clock", isSelected: viewModel.currentDuration == "daily",
                                        isLocked: viewModel.isRaceActive, isLoading: viewModel.isSaving && viewModel.currentDuration != "daily"
                                    ) { Task { await viewModel.setDuration("daily", competitionId: competition.id) } }
                                }
                                .background(AppTheme.cardBackground).cornerRadius(12).padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 8).padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { viewModel.load(competitionId: competition.id) }
        .alert("Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
        .alert("Saved", isPresented: Binding(get: { viewModel.successMessage != nil }, set: { if !$0 { viewModel.successMessage = nil } })) {
            Button("OK") { viewModel.successMessage = nil }
        } message: { Text(viewModel.successMessage ?? "") }
    }
}

private struct DurationOptionRow: View {
    let title: String; let subtitle: String; let icon: String
    let isSelected: Bool; let isLocked: Bool; let isLoading: Bool; let onTap: () -> Void

    var body: some View {
        Button(action: { if !isLocked && !isSelected { onTap() } }) {
            HStack(spacing: 16) {
                Image(systemName: icon).font(.system(size: 20))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.secondaryText).frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 16, weight: .bold))
                        .foregroundColor(isLocked ? AppTheme.secondaryText : AppTheme.primaryText)
                    Text(subtitle).font(.system(size: 13)).foregroundColor(AppTheme.secondaryText)
                }
                Spacer()
                if isLoading { ProgressView().tint(AppTheme.primaryText) }
                else if isSelected {
                    Image(systemName: isLocked ? "checkmark.circle" : "checkmark.circle.fill").font(.system(size: 22))
                        .foregroundColor(isLocked ? AppTheme.secondaryText : AppTheme.accent)
                } else {
                    Image(systemName: "circle").font(.system(size: 22)).foregroundColor(AppTheme.secondaryText)
                }
            }
            .padding(20)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLocked || isSelected || isLoading)
    }
}
