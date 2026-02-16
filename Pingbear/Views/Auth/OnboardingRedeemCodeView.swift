import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct OnboardingRedeemCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var enteredCode: String = ""
    @State private var isRedeeming: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var showPostSignupLeaderboard: Bool = false
    
    var body: some View {
        ZStack {
            Color(hex: "#1A2245")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with Skip button
                HStack {
                    Spacer()
                    
                    Button(action: {
                        completeOnboarding()
                    }) {
                        Text("Skip")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Welcome message
                        VStack(alignment: .center, spacing: 16) {
                            Image("gem")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(Color(hex: "#FFF"))
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 64, height: 64)
                            
                            Text("Do you have a win code?")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("If you have a win code from rating stories on the web, enter it below to claim your points and see your prize pool position!")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(20)
                        
                        // Code Input Section
                        VStack(spacing: 0) {
                            // Code Input
                            TextField("Win Code", text: $enteredCode)
                                .focused($isTextFieldFocused)
                                .padding()
                                .frame(height: 70)
                                .background(
                                    Color(hex: "#3B4374")
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                )
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .textCase(.uppercase)
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .accentColor(.white)
                                .onChange(of: enteredCode) { newValue in
                                    // Auto-uppercase and limit to 10 characters
                                    enteredCode = String(newValue.uppercased().prefix(10))
                                    
                                    // Clear error when user starts typing again
                                    if showError {
                                        showError = false
                                        errorMessage = ""
                                    }
                                }
            
                            // Error Message Text
                            if showError && !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .foregroundColor(Color(hex: "#FF0000"))
                                    .font(.system(size: 16, weight: .bold, design: .default))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(10)
                                    .padding(.top, 20)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Claim Button
                Button(action: {
                    isTextFieldFocused = false
                    redeemCode()
                }) {
                    HStack(spacing: 10) {
                        if isRedeeming {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Claim")
                                .font(.system(size: 18, weight: .bold))
                        }
                    }
                    .foregroundColor(
                        enteredCode.count == 10 && !isRedeeming
                        ? Color(.white)
                            : Color.gray.opacity(0.5)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(
                        enteredCode.count == 10 && !isRedeeming
                            ? Color(red: 65/255, green: 105/255, blue: 225/255)
                            : Color.gray.opacity(0.5)
                    )
                }
                .disabled(enteredCode.count != 10 || isRedeeming)
                .cornerRadius(200)
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showPostSignupLeaderboard) {
            PostSignupLeaderboardView {
                // When user taps Continue, complete onboarding
                completeOnboarding()
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "onboarding_redeem_code")
        }
    }
    
    private func redeemCode() {
        guard enteredCode.count == 10 else { return }
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be signed in to claim codes"
            showError = true
            return
        }
        
        isRedeeming = true
        
        // Call Cloud Function on Firebase A (React project)
        let cloudFunctionURL = URL(string: "https://claimwincode-vt3x7ykt4a-uc.a.run.app")!
        var request = URLRequest(url: cloudFunctionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "data": [
                "code": enteredCode,
                "swiftUserId": userId
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            DispatchQueue.main.async {
                isRedeeming = false
                errorMessage = "Failed to prepare request"
                showError = true
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isRedeeming = false
                
                if let error = error {
                    errorMessage = "Network error: \(error.localizedDescription)"
                    showError = true
                    return
                }
                
                guard let data = data else {
                    errorMessage = "No response from server"
                    showError = true
                    return
                }
                
                // Parse response
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let result = json["result"] as? [String: Any],
                       let success = result["success"] as? Bool,
                       success,
                       let points = result["points"] as? Int {
                        
                        // Success!
                        // Add points to global leaderboard
                        GlobalLeaderboardManager.shared.handleStarAwarded(
                            userId: userId,
                            stars: points,
                            competitionId: "web_ratings"
                        ) { success in
                            if success {
                                print("✅ Points added to global leaderboard")
                                
                                // Verify user is actually in pot before showing leaderboard
                                self.verifyUserInPot(userId: userId) { isInPot in
                                    if isInPot {
                                        // Show the PostSignupLeaderboardView
                                        self.showPostSignupLeaderboard = true
                                    } else {
                                        // Fallback: complete onboarding without showing leaderboard
                                        print("⚠️ User not in pot yet, completing onboarding normally")
                                        self.completeOnboarding()
                                    }
                                }
                            } else {
                                print("⚠️ Failed to add points to leaderboard")
                                // Still complete onboarding
                                self.completeOnboarding()
                            }
                        }
                        
                        Analytics.shared.track(
                            event: "onboarding_code_claimed",
                            properties: [
                                "points": points,
                                "code": enteredCode
                            ]
                        )
                    } else if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let error = json["error"] as? [String: Any],
                              let message = error["message"] as? String {
                        // Error from Cloud Function
                        handleErrorMessage(message)
                    } else {
                        errorMessage = "Invalid response from server"
                        showError = true
                    }
                } catch {
                    errorMessage = "Failed to parse response"
                    showError = true
                }
            }
        }.resume()
    }
    
    private func verifyUserInPot(userId: String, completion: @escaping (Bool) -> Void) {
        let maxAttempts = 10
        let delayBetweenAttempts: TimeInterval = 0.3
        
        func checkPot(attempt: Int) {
            Firestore.firestore().collection("users").document(userId).getDocument { document, error in
                if let activePotId = document?.data()?["active_pot_id"] as? String, !activePotId.isEmpty {
                    // Success! User has been added to a pot
                    print("✅ Verified user in pot: \(activePotId)")
                    DispatchQueue.main.async {
                        completion(true)
                    }
                    return
                }
                
                // Not in pot yet
                if attempt < maxAttempts {
                    // Try again after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + delayBetweenAttempts) {
                        checkPot(attempt: attempt + 1)
                    }
                } else {
                    // Max attempts reached, give up
                    print("⚠️ Max attempts reached, user not in pot")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            }
        }
        
        // Start checking
        checkPot(attempt: 1)
    }
    
    private func handleErrorMessage(_ message: String) {
        switch message {
        case "Invalid win code":
            errorMessage = "This code doesn't exist. Please check and try again."
        case "Code already claimed":
            errorMessage = "This code has already been claimed."
        case "INTERNAL":
            errorMessage = "Valid code not found"
        default:
            errorMessage = message
        }
        showError = true
        
        Analytics.shared.track(
            event: "onboarding_code_claim_failed",
            properties: [
                "error": errorMessage,
                "code": enteredCode
            ]
        )
    }
    
    private func completeOnboarding() {
        // Mark onboarding as complete
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        UserDefaults.standard.set(true, forKey: "isFriendActivated")
        UserDefaults.standard.synchronize()
        
        // Post notification to trigger UI update
        NotificationCenter.default.post(name: .authStateDidChange, object: nil)
        
        Analytics.shared.track(
            event: "onboarding_completed",
            properties: ["skipped_code": enteredCode.isEmpty]
        )
    }
}
