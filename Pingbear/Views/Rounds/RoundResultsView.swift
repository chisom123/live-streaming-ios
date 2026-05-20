import SwiftUI
import FirebaseAuth

struct RoundResultsView: View {

    let roundInfo: RoundInfo
    let submissions: [RoundSubmission]
    let userProfiles: [String: UserProfile]
    let isPlayingAgain: Bool          // true while awaiting the next round lobby
    let onPlayAgain: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let currentUserId = Auth.auth().currentUser?.uid ?? ""

    private var sortedSubmissions: [RoundSubmission] {
        submissions.sorted { ($0.aiScore ?? 0) > ($1.aiScore ?? 0) }
    }

    private var winners: [RoundSubmission] {
        guard let topScore = sortedSubmissions.first?.aiScore else { return [] }
        return sortedSubmissions.filter { $0.aiScore == topScore }
    }

    private var isTie: Bool { winners.count > 1 }

    private var currentUserIsWinner: Bool {
        roundInfo.winnerIds.contains(currentUserId)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Body
    // ─────────────────────────────────────────────────────────────

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                winnerBanner

                HStack {
                    Text("\(roundInfo.themeName)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                    Spacer()
                }
                .padding(.horizontal, 20)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(sortedSubmissions.enumerated()), id: \.element.id) { index, submission in
                            resultCard(submission: submission, rank: index + 1)
                        }
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                }

                // ── Play Again button ─────────────────────────────
                Button(action: {
                    if !isPlayingAgain {
                        Analytics.shared.trackTap(
                            elementId: "play_again",
                            screenName: "round_results"
                        )
                        onPlayAgain()
                    }
                }) {
                    HStack(spacing: 10) {
                        if isPlayingAgain {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.85)
                        }
                        Text(isPlayingAgain ? "Starting..." : "Play Again")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, 8)
                    .background(isPlayingAgain ? AppTheme.disabledBackground : AppTheme.accent)
                    .cornerRadius(200)
                }
                .disabled(isPlayingAgain)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .padding(.top, 24)
        }
        .navigationBarHidden(true)
        .onAppear {
            Analytics.shared.trackScreen(
                name: "round_results",
                properties: [
                    "is_winner": currentUserIsWinner,
                    "is_tie": isTie,
                    "participant_count": submissions.count,
                    "round_reward": roundInfo.roundReward
                ]
            )
            print("RoundResultsView: \(submissions.count) submissions")
            submissions.forEach { sub in
                print("  userId: \(sub.userId), photoUrl: '\(sub.photoUrl)', score: \(sub.aiScore ?? -1)")
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Winner Banner
    // ─────────────────────────────────────────────────────────────

    private var winnerBanner: some View {
        VStack(spacing: 15) {

            HStack {
                Button(action: {
                    Analytics.shared.trackTap(
                        elementId: "dismiss_results",
                        screenName: "round_results"
                    )
                    onDismiss()
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.secondaryText)
                        .clipShape(Circle())
                }
                Spacer()
            }

            Image("trophy")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(AppTheme.gold)
                .frame(width: 56, height: 56)

            if currentUserIsWinner {
                Text(isTie ? "You tied for the win!" : "You won!")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(AppTheme.primaryText)
            } else {
                let winnerName = winners.first.flatMap { userProfiles[$0.userId]?.username } ?? "Someone"
                Text(isTie ? "It's a tie!" : "\(winnerName) wins!")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(AppTheme.primaryText)
            }

            if currentUserIsWinner && roundInfo.roundReward > 0 {
                Text("+$\(String(format: "%.2f", roundInfo.roundReward / Double(winners.count)))")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.green)
                    .cornerRadius(200)
            }
            
            if roundInfo.roundReward > 0 {
                Text("Platform fee (10%)")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Result Card
    // ─────────────────────────────────────────────────────────────

    private func resultCard(submission: RoundSubmission, rank: Int) -> some View {
        let profile = userProfiles[submission.userId]
        let isWinner = roundInfo.winnerIds.contains(submission.userId)
        let isMe = submission.userId == currentUserId
        let score = submission.aiScore ?? 0.0

        return HStack(spacing: 10) {

            // ── Rank (outside the card) ──────────────────────────────
            Text("\(rank)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(isWinner ? AppTheme.gold : AppTheme.secondaryText)
                .frame(width: 24)

            // ── Card ─────────────────────────────────────────────────
            HStack(spacing: 12) {

                AsyncImage(url: URL(string: submission.photoUrl)) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(AppTheme.pageBackground)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure(let error):
                        Rectangle()
                            .fill(AppTheme.pageBackground)
                            .overlay(
                                VStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(AppTheme.secondaryText)
                                    Text("Failed")
                                        .font(.system(size: 9))
                                        .foregroundColor(AppTheme.secondaryText)
                                }
                            )
                            .onAppear {
                                print("AsyncImage failed for \(submission.userId): \(error.localizedDescription)")
                                print("URL was: '\(submission.photoUrl)'")
                            }
                    @unknown default:
                        Rectangle().fill(AppTheme.pageBackground)
                    }
                }
                .frame(width: 80, height: 100)
                .clipped()
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 6) {
                    Text(profile?.username ?? "...")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)

                    if let reason = submission.aiReason {
                        Text(reason)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if isWinner && roundInfo.roundReward > 0 {
                        let payout = roundInfo.roundReward / Double(winners.count)
                        Text("+$\(String(format: "%.2f", payout))")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppTheme.green)
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                VStack(spacing: 0) {
                    Text(String(format: "%.1f", score))
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(isWinner ? AppTheme.gold : AppTheme.primaryText)
                    Text("/ 9.9")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.secondaryText)
                }
                .frame(width: 48)
            }
            .padding(14)
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
        }
    }
}
