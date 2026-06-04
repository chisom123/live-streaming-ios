import SwiftUI

struct DemoCompleteView: View {

    @ObservedObject var coordinator: DemoFlowCoordinator

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Card ──────────────────────────────────────
                VStack(spacing: 28) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.12))
                            .frame(width: 88, height: 88)
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 36))
                            .foregroundColor(AppTheme.accent)
                    }

                    VStack(spacing: 12) {
                        Text("Practice round done")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(AppTheme.primaryText)
                            .multilineTextAlignment(.center)

                        Text("Now invite friends and play for real. The more you put in, the more you can win.")
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(28)
                .background(AppTheme.cardBackground)
                .cornerRadius(20)
                .padding(.horizontal, 24)

                Spacer()

                Button(action: {
                    Analytics.shared.trackTap(
                        elementId: "demo_complete_continue",
                        screenName: "demo_complete"
                    )
                    coordinator.goToHome()
                }) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(AppTheme.accent)
                        .cornerRadius(200)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "demo_complete")
        }
    }
}
