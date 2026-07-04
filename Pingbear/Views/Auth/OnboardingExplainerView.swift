import SwiftUI

// MARK: - OnboardingExplainerView
//
// Replaces WelcomeBonusView as the final onboarding screen.
// Deliberately breaks the visual pattern of the rest of onboarding
// (which uses AppTheme.pageBackground / cardBackground) with a solid
// green background — the same green used for creator_payout / top_up /
// welcome_bonus in WalletView, so it borrows meaning users will later
// recognize rather than introducing an arbitrary new color.
//
// Shows a non-interactive example request card instead of explaining
// the mechanic in prose — the goal is recognition, not comprehension.

struct OnboardingExplainerView: View {

    let hadInviteGroups: Bool

    private let example = ExampleRequest(fromName: "Maya", description: "Eat a spoon of hot sauce", price: 5.00)

    var body: some View {
        ZStack {
            Color(hex: "#16A34A").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 28) {

                    ExampleRequestCard(example: example)

                    VStack(spacing: 2) {
                        Text("Paid requests")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundColor(.white)
                        Text("from friends")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 26)

                Spacer()

                Button(action: {
                    Analytics.shared.trackTap(elementId: "onboarding_explainer_continue", screenName: "onboarding_explainer")
                    completeOnboarding()
                }) {
                    Text("Let's go")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.white)
                        .cornerRadius(200)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Analytics.shared.trackScreen(name: "onboarding_explainer")
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        UserDefaults.standard.set(true, forKey: "isFriendActivated")
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .authStateDidChange, object: nil)
        Analytics.shared.track(
            event: "onboarding_completed",
            properties: ["had_invite_groups": hadInviteGroups]
        )
    }
}

// MARK: - ExampleRequestCard
//
// Deliberately mirrors StreamerRequestCard's visual language so the
// recognition carries over once someone sees a real request — but is
// fully non-interactive. Accept/Decline are static pills, not buttons,
// so there's no risk of ever wiring them to a live action by accident.

private struct ExampleRequestCard: View {
    let example: ExampleRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                // TODO: swap "ExampleFriendAvatar" for your actual asset
                // catalog image name.
                Image("ExampleFriendAvatar")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                Text(example.fromName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "#1C1C1A"))
                Spacer()
                Text("$\(String(format: "%.2f", example.price))")
                    .font(.system(size: 17, weight: .black))
                    .foregroundColor(Color(hex: "#16A34A"))
            }

            Text(example.description)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: "#3A3A38"))

            HStack(spacing: 8) {
                Text("Decline")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "#8A8880"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color(hex: "#F0EFE9"))
                    .clipShape(Capsule())

                Text("Accept")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color(hex: "#16A34A"))
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - ExampleRequest

private struct ExampleRequest {
    let fromName:    String
    let description: String
    let price:       Double
}
