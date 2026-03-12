import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct WelcomeBonusView: View {
    @State private var showPostSignupLeaderboard: Bool = false
    @State private var isVerifying: Bool = false

    var body: some View {
        ZStack {
            Color(hex: "#10183C")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    Image("gem")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(Color(hex: "#FFF"))
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 70, height: 70)
                        .padding(.top, -10)

                    VStack(spacing: 12) {
                        Text("Welcome Bonus")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text("You've been awarded 100 prize points to kick things off")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                            .padding(.horizontal, 10)
                    }

                    // Points badge
                    Text("+100")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .padding(EdgeInsets(top: 7, leading: 20, bottom: 7, trailing: 20))
                        .background(Color(hex: "#6A5ACD"))
                        .cornerRadius(200)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 50)
                .background(Color(hex: "#1A2245"))
                .cornerRadius(10)
                .padding(.horizontal, 20)

                Spacer()

                // CTA button
                Button(action: {
                    Analytics.shared.trackTap(
                        elementId: "see_my_position",
                        screenName: "welcome_bonus"
                    )
                    verifyAndShowLeaderboard()
                }) {
                    Text("Claim Prize Points")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color(hex: "#4169E1"))
                        .cornerRadius(200)
                }
                .disabled(isVerifying)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showPostSignupLeaderboard) {
            PostSignupLeaderboardView {
                completeOnboarding()
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "welcome_bonus")
        }
    }

    private func verifyAndShowLeaderboard() {
        guard let userId = Auth.auth().currentUser?.uid else {
            completeOnboarding()
            return
        }

        isVerifying = true
        verifyUserInPot(userId: userId) { isInPot in
            isVerifying = false
            if isInPot {
                showPostSignupLeaderboard = true
            } else {
                // Points not yet reflected — still complete onboarding gracefully
                print("⚠️ User not in pot yet, completing onboarding normally")
                completeOnboarding()
            }
        }
    }

    private func verifyUserInPot(userId: String, completion: @escaping (Bool) -> Void) {
        let maxAttempts = 10
        let delayBetweenAttempts: TimeInterval = 0.3

        func checkPot(attempt: Int) {
            Firestore.firestore().collection("users").document(userId).getDocument { document, error in
                if let activePotId = document?.data()?["active_pot_id"] as? String, !activePotId.isEmpty {
                    print("✅ Verified user in pot: \(activePotId)")
                    DispatchQueue.main.async {
                        completion(true)
                    }
                    return
                }

                if attempt < maxAttempts {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delayBetweenAttempts) {
                        checkPot(attempt: attempt + 1)
                    }
                } else {
                    print("⚠️ Max attempts reached, user not in pot")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            }
        }

        checkPot(attempt: 1)
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        UserDefaults.standard.set(true, forKey: "isFriendActivated")
        UserDefaults.standard.synchronize()

        NotificationCenter.default.post(name: .authStateDidChange, object: nil)

        Analytics.shared.track(
            event: "onboarding_completed",
            properties: [:]
        )
    }
}
