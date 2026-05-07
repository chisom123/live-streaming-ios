import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct RaceRecord: Identifiable {
    let id: String; let competitionId: String; let status: String; let duration: String
    let startDate: Date; let endDate: Date; let totalPot: Double; let totalStars: Int
    let participantCount: Int; let payoutComplete: Bool; let refunded: Bool
    var participants: [RaceRecordParticipant] = []
}

struct RaceRecordParticipant: Identifiable {
    let id: String; let username: String; let profilePictureUrl: String?
    let totalStars: Int; let payoutAmount: Double; let isCurrentUser: Bool
}

@MainActor
class RaceHistoryViewModel: ObservableObject {
    @Published var races: [RaceRecord] = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    private let db = Firestore.firestore()

    func load(competitionId: String) {
        isLoading = true
        db.collection("competition_races").whereField("competition_id", isEqualTo: competitionId)
            .order(by: "start_date", descending: true).getDocuments { [weak self] snapshot, error in
                guard let self else { return }
                if let error { self.errorMessage = error.localizedDescription; self.isLoading = false; return }
                guard let documents = snapshot?.documents, !documents.isEmpty else { self.isLoading = false; return }
                var records: [RaceRecord] = []
                for doc in documents {
                    let data = doc.data()
                    guard let startDate = (data["start_date"] as? Timestamp)?.dateValue(),
                          let endDate = (data["end_date"] as? Timestamp)?.dateValue() else { continue }
                    records.append(RaceRecord(id: doc.documentID, competitionId: competitionId,
                        status: data["status"] as? String ?? "closed", duration: data["duration"] as? String ?? "weekly",
                        startDate: startDate, endDate: endDate, totalPot: data["total_pot"] as? Double ?? 0.0,
                        totalStars: data["total_stars"] as? Int ?? 0, participantCount: data["participant_count"] as? Int ?? 0,
                        payoutComplete: data["payout_complete"] as? Bool ?? false, refunded: data["refunded"] as? Bool ?? false))
                }
                self.races = records
                self.loadParticipants(for: records)
            }
    }

    private func loadParticipants(for records: [RaceRecord]) {
        guard !records.isEmpty else { isLoading = false; return }
        let group = DispatchGroup()
        for (index, record) in records.enumerated() {
            group.enter()
            db.collection("competition_races").document(record.id).collection("race_participants")
                .order(by: "total_stars", descending: true).getDocuments { [weak self] snapshot, _ in
                    guard let self else { group.leave(); return }
                    let rawParticipants = snapshot?.documents.compactMap { doc -> (userId: String, stars: Int, payout: Double) in
                        let data = doc.data()
                        return (userId: doc.documentID, stars: data["total_stars"] as? Int ?? 0, payout: data["payout_amount"] as? Double ?? 0.0)
                    } ?? []
                    self.fetchParticipantNames(rawParticipants) { participants in
                        self.races[index].participants = participants; group.leave()
                    }
                }
        }
        group.notify(queue: .main) { [weak self] in self?.isLoading = false }
    }

    private func fetchParticipantNames(_ raw: [(userId: String, stars: Int, payout: Double)], completion: @escaping ([RaceRecordParticipant]) -> Void) {
        guard !raw.isEmpty else { completion([]); return }
        let group = DispatchGroup(); var result: [RaceRecordParticipant] = []
        let currentUserId = Auth.auth().currentUser?.uid
        for participant in raw {
            group.enter()
            db.collection("users").document(participant.userId).getDocument { doc, _ in
                let name = doc?.data()?["name"] as? String ?? "Unknown"
                let profileUrl = doc?.data()?["profilePictureUrl"] as? String
                let isMe = participant.userId == currentUserId
                result.append(RaceRecordParticipant(id: participant.userId, username: isMe ? "Me" : name,
                    profilePictureUrl: profileUrl, totalStars: participant.stars, payoutAmount: participant.payout, isCurrentUser: isMe))
                group.leave()
            }
        }
        group.notify(queue: .main) { completion(result.sorted { $0.totalStars > $1.totalStars }) }
    }
}

struct RaceHistoryView: View {
    let competition: Competition
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RaceHistoryViewModel()

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left").resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27).foregroundColor(AppTheme.iconColor)
                    }
                    Spacer()
                    Text("History").font(.system(size: 18, weight: .bold)).foregroundColor(AppTheme.primaryText)
                    Spacer()
                    Color.clear.frame(width: 27, height: 27)
                }
                .padding(.horizontal, 20).padding(.vertical, 20)

                if viewModel.isLoading {
                    Spacer(); ProgressView().tint(AppTheme.primaryText); Spacer()
                } else if viewModel.races.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "flag.checkered").font(.system(size: 48)).foregroundColor(AppTheme.secondaryText)
                        Text("No races yet").font(.system(size: 18, weight: .bold)).foregroundColor(AppTheme.secondaryText)
                        Text("Races start automatically when the first photo is posted or someone adds to the pot.")
                            .font(.system(size: 14)).foregroundColor(AppTheme.secondaryText).multilineTextAlignment(.center).padding(.horizontal, 40)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 16) { ForEach(viewModel.races) { race in RaceCard(race: race) } }
                            .padding(.horizontal, 20).padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { viewModel.load(competitionId: competition.id) }
        .alert("Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
    }
}

private struct RaceCard: View {
    let race: RaceRecord
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                VStack(spacing: 12) {
                    HStack {
                        statusBadge; Spacer()
                        Text(race.duration.capitalized).font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppTheme.secondaryText).padding(.horizontal, 10).padding(.vertical, 4)
                            .background(AppTheme.cardHighlight).cornerRadius(200)
                    }
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dateRangeString).font(.system(size: 14)).foregroundColor(AppTheme.secondaryText)
                            if race.totalPot > 0 {
                                Text("$\(String(format: "%.2f", race.totalPot)) pot").font(.system(size: 22, weight: .bold)).foregroundColor(AppTheme.green)
                            } else {
                                Text("No prize pool").font(.system(size: 16)).foregroundColor(AppTheme.secondaryText)
                            }
                        }
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.system(size: 14)).foregroundColor(AppTheme.secondaryText)
                    }
                }
                .padding(20)
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                Divider().background(AppTheme.divider)
                if race.refunded {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise.circle.fill").foregroundColor(.orange)
                        Text("No stars earned — all contributions refunded").font(.system(size: 13)).foregroundColor(AppTheme.secondaryText)
                    }.padding(16)
                } else if race.participants.isEmpty {
                    Text("No participants").font(.system(size: 14)).foregroundColor(AppTheme.secondaryText).padding(16)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(race.participants.enumerated()), id: \.element.id) { index, participant in
                            ParticipantRow(rank: index + 1, participant: participant, hasPot: race.totalPot > 0, isActive: race.status == "active")
                            if index < race.participants.count - 1 { Divider().background(AppTheme.divider).padding(.leading, 60) }
                        }
                    }
                }
            }
        }
        .background(AppTheme.cardBackground).cornerRadius(12)
    }

    @ViewBuilder private var statusBadge: some View {
        if race.status == "active" {
            HStack(spacing: 6) {
                Circle().fill(AppTheme.green).frame(width: 8, height: 8)
                Text("In Progress").font(.system(size: 13, weight: .bold)).foregroundColor(AppTheme.green)
            }
            .padding(.horizontal, 10).padding(.vertical, 4).background(AppTheme.green.opacity(0.1)).cornerRadius(200)
        } else if race.refunded {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise").font(.system(size: 11)).foregroundColor(.orange)
                Text("Refunded").font(.system(size: 13, weight: .bold)).foregroundColor(.orange)
            }
            .padding(.horizontal, 10).padding(.vertical, 4).background(Color.orange.opacity(0.1)).cornerRadius(200)
        } else {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundColor(AppTheme.accent)
                Text("Completed").font(.system(size: 13, weight: .bold)).foregroundColor(AppTheme.accent)
            }
            .padding(.horizontal, 10).padding(.vertical, 4).background(AppTheme.accent.opacity(0.1)).cornerRadius(200)
        }
    }

    private var dateRangeString: String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return "\(f.string(from: race.startDate)) — \(f.string(from: race.endDate))"
    }
}

private struct ParticipantRow: View {
    let rank: Int; let participant: RaceRecordParticipant; let hasPot: Bool; let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)").font(.system(size: 14, weight: .bold)).foregroundColor(AppTheme.secondaryText).frame(width: 24).padding(.leading, 16)
            ProfilePictureView(url: participant.profilePictureUrl, size: 36)
            Text(participant.username).font(.system(size: 15, weight: .bold))
                .foregroundColor(participant.isCurrentUser ? AppTheme.accent : AppTheme.primaryText).lineLimit(1)
            Spacer()
            HStack(spacing: 4) {
                Text("\(participant.totalStars)").font(.system(size: 14, weight: .bold)).foregroundColor(AppTheme.primaryText)
                Image(systemName: "star.fill").font(.system(size: 12)).foregroundColor(AppTheme.gold)
            }
            .padding(.horizontal, 8).padding(.vertical, 4).background(AppTheme.gold.opacity(0.15)).cornerRadius(200)

            if hasPot {
                if isActive {
                    Text("~$\(String(format: "%.2f", participant.payoutAmount))").font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.secondaryText).padding(.trailing, 16)
                } else if participant.payoutAmount > 0 {
                    Text("$\(String(format: "%.2f", participant.payoutAmount))").font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.green).padding(.trailing, 16)
                } else {
                    Text("$0.00").font(.system(size: 14, weight: .bold)).foregroundColor(AppTheme.secondaryText).padding(.trailing, 16)
                }
            } else { Color.clear.frame(width: 16) }
        }
        .padding(.vertical, 14)
        .background(participant.isCurrentUser ? AppTheme.cardHighlight : Color.clear)
    }
}
