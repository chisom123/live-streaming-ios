import SwiftUI

struct WhyAddFriendsView: View {

    @StateObject private var contactViewModel = ContactViewModel()
    @StateObject private var addFriendsModel  = AddFriendsModel()

    @State private var navigateToAddFriends = false

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 40))
                            .foregroundColor(AppTheme.accent)
                    }

                    VStack(spacing: 10) {
                        Text("SocialStar is more fun with friends")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppTheme.primaryText)
                            .multilineTextAlignment(.center)

                        Text("Add or invite a friend to unlock the full experience")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                            .padding(.horizontal, 10)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 40)
                .background(AppTheme.cardBackground)
                .cornerRadius(16)
                .padding(.horizontal, 20)

                Spacer()

                VStack(spacing: 25) {
                    Button(action: {
                        Analytics.shared.trackTap(elementId: "why_add_friends_cta", screenName: "why_add_friends")
                        navigateToAddFriends = true
                    }) {
                        Text("Add friends")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(AppTheme.accent)
                            .cornerRadius(200)
                    }

                    // Skip is intentionally available for now, so this ships
                    // as a soft nudge rather than a hard gate. Once we have
                    // completion-vs-retention data for this cohort, this
                    // button can be removed to make adding a friend mandatory.
                    Button(action: {
                        Analytics.shared.track(event: "why_add_friends_skipped", properties: [:])
                        OnboardingCompletion.finish(hasFriend: false)
                    }) {
                        Text("Skip for now")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)

                NavigationLink(
                    destination: AddFriendsStepView(
                        contactViewModel: contactViewModel,
                        addFriendsModel:  addFriendsModel
                    ),
                    isActive: $navigateToAddFriends
                ) { EmptyView() }
                    .isDetailLink(false)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Analytics.shared.trackScreen(name: "why_add_friends")
            // Deliberately NOT requesting contacts access here. This screen
            // is the explanation — the system permission dialog should only
            // fire once the user has read it and tapped "Add friends",
            // which happens in AddFriendsStepView.onAppear instead.
        }
    }

}

// MARK: - Onboarding completion helper
//
// Shared by WelcomeBonusView (friend already resolved via invite_groups)
// and AddFriendsStepView (friend added/invited here, or skipped).
// isFriendActivated reflects whether a real friend exists — not just
// whether onboarding was completed — so later screens (e.g. a home-tab
// banner) can distinguish "skipped" users and re-prompt them.

enum OnboardingCompletion {
    static func finish(hasFriend: Bool) {
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        UserDefaults.standard.set(hasFriend, forKey: "isFriendActivated")
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .authStateDidChange, object: nil)
        Analytics.shared.track(
            event: "onboarding_completed",
            properties: ["has_friend": hasFriend]
        )
    }
}
