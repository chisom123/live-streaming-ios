import SwiftUI

struct WelcomeBonusView: View {

    let hadInviteGroups: Bool

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.green.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: "gift.fill")
                            .font(.system(size: 44))
                            .foregroundColor(AppTheme.green)
                    }
                    VStack(spacing: 10) {
                        Text("Welcome Bonus")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppTheme.primaryText)
                            .multilineTextAlignment(.center)
                        Text("We've added $5 to your wallet to get you started")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                            .padding(.horizontal, 10)
                    }
                    Text("+$5")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .padding(EdgeInsets(top: 10, leading: 28, bottom: 10, trailing: 28))
                        .background(AppTheme.green)
                        .cornerRadius(200)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 50)
                .background(AppTheme.cardBackground)
                .cornerRadius(16)
                .padding(.horizontal, 20)

                Spacer()

                Button(action: {
                    Analytics.shared.trackTap(elementId: "welcome_bonus_continue", screenName: "welcome_bonus")
                    completeOnboarding()
                }) {
                    Text("Continue")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(AppTheme.accent)
                        .cornerRadius(200)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .navigationBarHidden(true)
        .onAppear { Analytics.shared.trackScreen(name: "welcome_bonus") }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        UserDefaults.standard.set(true, forKey: "isFriendActivated")
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .authStateDidChange, object: nil)
        Analytics.shared.track(event: "onboarding_completed",
                                properties: ["had_invite_groups": hadInviteGroups])
    }
}
