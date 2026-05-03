import SwiftUI

struct WelcomeBonusView: View {

    var body: some View {
        ZStack {
            Color(hex: "#10183C").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Bonus card ────────────────────────────────
                VStack(spacing: 24) {

                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#00AA00").opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "gift.fill")
                            .font(.system(size: 44))
                            .foregroundColor(Color(hex: "#00AA00"))
                    }

                    // Title
                    VStack(spacing: 10) {
                        Text("Welcome Bonus")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text("We've added $5 to your wallet to get you started")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                            .padding(.horizontal, 10)
                    }

                    // Amount badge
                    Text("+$5")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .padding(EdgeInsets(top: 10, leading: 28, bottom: 10, trailing: 28))
                        .background(Color(hex: "#00AA00"))
                        .cornerRadius(200)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 50)
                .background(Color(hex: "#1A2245"))
                .cornerRadius(16)
                .padding(.horizontal, 20)

                Spacer()

                // ── CTA button ────────────────────────────────
                Button(action: {
                    Analytics.shared.trackTap(
                        elementId: "welcome_bonus_lets_go",
                        screenName: "welcome_bonus"
                    )
                    completeOnboarding()
                }) {
                    Text("Claim Bonus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color(hex: "#4169E1"))
                        .cornerRadius(200)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Analytics.shared.trackScreen(name: "welcome_bonus")
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        UserDefaults.standard.set(true, forKey: "isFriendActivated")
        UserDefaults.standard.synchronize()

        NotificationCenter.default.post(name: .authStateDidChange, object: nil)

        Analytics.shared.track(event: "onboarding_completed")
    }
}
