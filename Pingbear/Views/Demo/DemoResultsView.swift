import SwiftUI
import FirebaseAuth

struct DemoResultsView: View {

    @ObservedObject var coordinator: DemoFlowCoordinator
    let result: DemoRoundResult

    // Sort so winner is always first
    private var sortedCards: [(photoUrl: String, name: String, score: Double, reason: String, isWinner: Bool)] {
        let user = (
            photoUrl: result.userPhotoUrl,
            name:     "You",
            score:    result.userScore,
            reason:   result.userReason,
            isWinner: result.userWon || result.isTie
        )
        let bot = (
            photoUrl: result.botPhotoUrl,
            name:     result.botName,
            score:    result.botScore,
            reason:   result.botReason,
            isWinner: !result.userWon || result.isTie
        )
        return result.userScore >= result.botScore ? [user, bot] : [bot, user]
    }

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                winnerBanner
                    .padding(.top, 24)
                    .padding(.horizontal, 20)

                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Array(sortedCards.enumerated()), id: \.offset) { index, card in
                            resultCard(
                                photoUrl: card.photoUrl,
                                name:     card.name,
                                score:    card.score,
                                reason:   card.reason,
                                isWinner: card.isWinner
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(AppTheme.cardBackground)
                                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                            )
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 12)
                }

                Button(action: {
                    Analytics.shared.trackTap(
                        elementId: "demo_results_continue",
                        screenName: "demo_results",
                        properties: [
                            "user_won":   result.userWon,
                            "is_tie":     result.isTie,
                            "winnings":   result.winnings,
                            "user_score": result.userScore,
                            "bot_score":  result.botScore
                        ]
                    )
                    coordinator.proceedFromResults()
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, 8)
                        .background(AppTheme.accent)
                        .cornerRadius(200)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .padding(.top, 12)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Analytics.shared.trackScreen(
                name: "demo_results",
                properties: [
                    "user_won":   result.userWon,
                    "is_tie":     result.isTie,
                    "winnings":   result.winnings,
                    "user_score": result.userScore,
                    "bot_score":  result.botScore,
                    "entry_fee":  result.totalPot / 2
                ]
            )
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Winner Banner
    // ─────────────────────────────────────────────────────────

    private var winnerBanner: some View {
        VStack(spacing: 15) {
            if result.isTie {
                Text("It's a tie!")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(AppTheme.primaryText)
            } else if result.userWon {
                Text("You beat Sarah!")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(AppTheme.primaryText)
            } else {
                Text("Sarah wins this one")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(AppTheme.primaryText)
            }

            if result.roundReward > 0 {
                Text("+$\(String(format: "%.2f", result.roundReward))")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.green)
                    .cornerRadius(200)
            }
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Result Card
    // ─────────────────────────────────────────────────────────

    private func resultCard(
        photoUrl: String,
        name:     String,
        score:    Double,
        reason:   String,
        isWinner: Bool
    ) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topLeading) {
                AsyncImage(url: URL(string: photoUrl)) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(AppTheme.pageBackground)
                            .frame(width: 110, height: 140)
                            .overlay(ProgressView())
                    case .success(let image):
                        image.resizable()
                            .scaledToFill()
                            .frame(width: 110, height: 140)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(AppTheme.pageBackground)
                            .frame(width: 110, height: 140)
                            .overlay(Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(AppTheme.secondaryText))
                    @unknown default:
                        Rectangle().fill(AppTheme.pageBackground)
                            .frame(width: 110, height: 140)
                    }
                }

                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.black.opacity(0.4), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 140 * 0.35)
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.4)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 140 * 0.35)
                }
                .frame(width: 110, height: 140)

                Text(name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.top, 9)
            }
            .frame(width: 110, height: 140)
            .cornerRadius(12)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                Text(reason)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.primaryText)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Text(String(format: "%.1f", score))
                .font(.system(size: 20, weight: .black))
                .foregroundColor(isWinner ? AppTheme.gold : AppTheme.primaryText)
                .frame(width: 48)
        }
        .padding(14)
    }
}
