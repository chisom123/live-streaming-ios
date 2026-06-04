import SwiftUI

// ─────────────────────────────────────────────────────────────
// MARK: - DemoIntroView
//
// First screen of the demo flow. A single card explaining
// the practice round. User taps Continue to proceed to lobby.
// ─────────────────────────────────────────────────────────────

struct DemoIntroView: View {

    @ObservedObject var coordinator: DemoFlowCoordinator

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Card ──────────────────────────────────────
                VStack(spacing: 28) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.12))
                            .frame(width: 88, height: 88)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 36))
                            .foregroundColor(AppTheme.accent)
                    }

                    // Text
                    VStack(spacing: 12) {
                        Text("Try a practice round")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(AppTheme.primaryText)
                            .multilineTextAlignment(.center)

                        Text("Take a photo and go head-to-head with Sarah. Put some of your bonus in the pool — beat Sarah and win more.")
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

                // ── CTA ───────────────────────────────────────
                Button(action: { coordinator.proceedFromIntro() }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .bold))
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
            Analytics.shared.trackScreen(name: "demo_intro")
        }
    }

}
