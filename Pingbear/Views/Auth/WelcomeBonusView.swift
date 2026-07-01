import SwiftUI

struct WelcomeBonusView: View {

    let hasExistingFriend: Bool

    @State private var navigateToAddFriends = false

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
                        Text("We've added $0.50 to your wallet to get you started")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                            .padding(.horizontal, 10)
                    }
                    Text("+$0.50")
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
                    proceed()
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

                NavigationLink(
                    destination: WhyAddFriendsView(),
                    isActive: $navigateToAddFriends
                ) { EmptyView() }
                    .isDetailLink(false)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Analytics.shared.trackScreen(name: "welcome_bonus")
            Analytics.shared.track(
                event: "onboarding_bonus_shown",
                properties: ["has_existing_friend": hasExistingFriend]
            )
        }
    }

    // MARK: - Routing
    //
    // Users who already resolved a friend via invite_groups (they were
    // invited by someone, or someone accepted their invite before they
    // finished onboarding) skip the friend-adding gate entirely — they
    // already have a functional experience waiting. Everyone else goes
    // through the explainer + add-friends flow before the main app.

    private func proceed() {
        if hasExistingFriend {
            UserDefaults.standard.set(true, forKey: "isLoggedIn")
            UserDefaults.standard.set(true, forKey: "isFriendActivated")
            UserDefaults.standard.synchronize()
            NotificationCenter.default.post(name: .authStateDidChange, object: nil)
            Analytics.shared.track(event: "onboarding_completed",
                                    properties: ["had_invite_groups": hasExistingFriend])
        } else {
            navigateToAddFriends = true
        }
    }
}
