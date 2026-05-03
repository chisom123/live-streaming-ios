import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

// ─────────────────────────────────────────────────────────────
// MARK: - RaceSettingsViewModel
// ─────────────────────────────────────────────────────────────

@MainActor
class RaceSettingsViewModel: ObservableObject {

    @Published var currentDuration: String = "weekly"   // "daily" | "weekly"
    @Published var isRaceActive: Bool = false
    @Published var isLoading: Bool = true
    @Published var isSaving: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil

    private let db = Firestore.firestore()

    // ── Load current settings ─────────────────────────────────

    func load(competitionId: String) {
        isLoading = true

        let group = DispatchGroup()

        // 1. Read race_duration from competition document
        group.enter()
        db.collection("competitions").document(competitionId).getDocument { [weak self] snapshot, _ in
            guard let self else { group.leave(); return }
            self.currentDuration = snapshot?.data()?["race_duration"] as? String ?? "weekly"
            group.leave()
        }

        // 2. Check if there's an active race
        group.enter()
        db.collection("competition_races")
            .whereField("competition_id", isEqualTo: competitionId)
            .whereField("status", isEqualTo: "active")
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, _ in
                guard let self else { group.leave(); return }

                if let doc = snapshot?.documents.first,
                   let endDate = (doc.data()["end_date"] as? Timestamp)?.dateValue(),
                   Date() < endDate {
                    self.isRaceActive = true
                    // Read actual duration from the active race document
                    self.currentDuration = doc.data()["duration"] as? String ?? self.currentDuration
                } else {
                    self.isRaceActive = false
                }
                group.leave()
            }

        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
        }
    }

    // ── Save duration ─────────────────────────────────────────

    func setDuration(_ duration: String, competitionId: String) async {
        guard !isRaceActive else {
            errorMessage = "Cannot change duration while a race is active"
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let functions = Functions.functions()
            _ = try await functions
                .httpsCallable("setRaceDuration")
                .call(["competitionId": competitionId, "duration": duration])

            currentDuration = duration
            successMessage = "Race duration updated to \(duration)"
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - RaceSettingsView
// ─────────────────────────────────────────────────────────────

struct RaceSettingsView: View {

    let competition: Competition

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RaceSettingsViewModel()

    var body: some View {
        ZStack {
            Color(hex: "#10183C").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // ── Header ────────────────────────────────────
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text("Duration")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    // Invisible balance item for centering
                    Color.clear
                        .frame(width: 27, height: 27)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)

                if viewModel.isLoading {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView().tint(.white)
                        Spacer()
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {

                            // ── Race active warning ───────────
                            if viewModel.isRaceActive {
                                HStack(spacing: 12) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.orange)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Race in progress")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.orange)

                                        Text("Duration cannot be changed while a race is active. Settings will apply to the next race.")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                                .padding(16)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal, 20)
                            }

                            // ── Duration selector ─────────────
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Race Duration")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 20)

                                VStack(spacing: 0) {

                                    // Weekly option
                                    DurationOptionRow(
                                        title: "Weekly",
                                        subtitle: "7 days — contribute once, play daily all week",
                                        icon: "calendar",
                                        isSelected: viewModel.currentDuration == "weekly",
                                        isLocked: viewModel.isRaceActive,
                                        isLoading: viewModel.isSaving && viewModel.currentDuration != "weekly"
                                    ) {
                                        Task {
                                            await viewModel.setDuration("weekly", competitionId: competition.id)
                                        }
                                    }

                                    Divider().background(Color.white.opacity(0.1))

                                    // Daily option
                                    DurationOptionRow(
                                        title: "Daily",
                                        subtitle: "24 hours — fresh race and pot every day",
                                        icon: "clock",
                                        isSelected: viewModel.currentDuration == "daily",
                                        isLocked: viewModel.isRaceActive,
                                        isLoading: viewModel.isSaving && viewModel.currentDuration != "daily"
                                    ) {
                                        Task {
                                            await viewModel.setDuration("daily", competitionId: competition.id)
                                        }
                                    }
                                }
                                .background(Color(hex: "#1A2245"))
                                .cornerRadius(12)
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { viewModel.load(competitionId: competition.id) }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Saved", isPresented: Binding(
            get: { viewModel.successMessage != nil },
            set: { if !$0 { viewModel.successMessage = nil } }
        )) {
            Button("OK") { viewModel.successMessage = nil }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - DurationOptionRow
// ─────────────────────────────────────────────────────────────

private struct DurationOptionRow: View {

    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let isLocked: Bool
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            if !isLocked && !isSelected {
                onTap()
            }
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Color(hex: "#4169E1") : .white.opacity(0.5))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isLocked ? .white.opacity(0.5) : .white)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer()

                if isLoading {
                    ProgressView().tint(.white)
                } else if isSelected {
                    Image(systemName: isLocked ? "checkmark.circle" : "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(isLocked ? .white.opacity(0.4) : Color(hex: "#4169E1"))
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.2))
                }
            }
            .padding(20)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLocked || isSelected || isLoading)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - InfoRow
// ─────────────────────────────────────────────────────────────

private struct InfoRow: View {

    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#4169E1"))
                .frame(width: 20)
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
