// NameEntryView.swift
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import CryptoKit

struct NameEntryView: View {
    let phoneNumber: String
    let fullName: String
    @State private var username: String = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var navigateToWelcomeBonus = false
    @State private var pointsToAward: Int = 100 // default signup bonus
    @State private var isWebUser: Bool = false

    var body: some View {
        ZStack {
            Color(hex: "#10183C")
                .ignoresSafeArea()

            VStack {
                Spacer()
                
                VStack {
                    Text("Create a username")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(.white)
                        .padding(.top, 20)
                        .padding(.bottom, 25)
                        .onAppear {
                            Analytics.shared.trackScreen(name: "username_entry")
                        }
                    
                    TextField("Enter your username", text: $username)
                        .padding()
                        .frame(height: 60)
                        .background(
                            Color(hex: "#3B4374")
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        )
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .autocapitalization(.none)
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(Color(hex: "#FF0000"))
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .padding(.top, 20)
                            .padding(.horizontal)
                            .onAppear {
                                Analytics.shared.track(
                                    event: "username_entry_error",
                                    properties: ["error": error]
                                )
                            }
                    }
                    
                    if isLoading {
                        ProgressView()
                            .padding(.vertical, 20)
                            .tint(.white)
                    } else {
                        Button(action: {
                            self.hideKeyboard()
                            self.checkUsernameAndSaveToFirestore()
                        }) {
                            Text("Continue")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .font(.system(size: 18, weight: .bold, design: .default))
                                .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .background(Color(hex: "#4169E1"))
                                .foregroundColor(Color(hex: "#fff"))
                                .cornerRadius(200)
                        }
                        .padding(.vertical, 20)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color(hex: "#1A2245"))
                .cornerRadius(10)
                .padding(.horizontal, 20)
                
                NavigationLink(
                    destination: WelcomeBonusView(points: pointsToAward, isWebUser: isWebUser),
                    isActive: $navigateToWelcomeBonus
                ) {
                    EmptyView()
                }.isDetailLink(false)
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
    
    func checkUsernameAndSaveToFirestore() {
        isLoading = true
        let processedUsername = username.lowercased().replacingOccurrences(of: " ", with: "")
        
        let validation = isValidUsername(processedUsername)
        guard validation.isValid else {
            errorMessage = validation.error
            isLoading = false
            Analytics.shared.track(
                event: "username_validation_failed",
                properties: [
                    "username": processedUsername,
                    "error": validation.error ?? "No error provided"
                ]
            )
            return
        }

        let db = Firestore.firestore()
       
        db.collection("users").whereField("username", isEqualTo: processedUsername).getDocuments { (querySnapshot, err) in
            if let err = err {
                isLoading = false
                errorMessage = "Error checking username: \(err.localizedDescription)"
                Analytics.shared.track(
                    event: "username_check_failed",
                    properties: ["error": err.localizedDescription]
                )
            } else if querySnapshot!.documents.isEmpty {
                saveUsernameToFirestore(processedUsername: processedUsername)
            } else {
                isLoading = false
                errorMessage = "This username is already taken"
                Analytics.shared.track(
                    event: "username_already_taken",
                    properties: ["username": processedUsername]
                )
            }
        }
    }
    
    func hashPhoneNumber(_ phoneNumber: String) -> String {
        let cleanedNumber = phoneNumber
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        
        let salt = "5Ax1HpaMDwxIv15M6t4ZdGuC8"
        let hashInput = salt + cleanedNumber
        let hash = SHA256.hash(data: Data(hashInput.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    func saveUsernameToFirestore(processedUsername: String) {
        guard let userID = Auth.auth().currentUser?.uid else {
            isLoading = false
            errorMessage = "Error fetching user ID"
            return
        }
       
        let db = Firestore.firestore()
        let hashedPhoneNumber = hashPhoneNumber(phoneNumber)
       
        db.collection("users").document(userID).setData([
            "username": processedUsername,
            "phoneNumberHash": hashedPhoneNumber,
            "name": fullName
        ], merge: true) { error in
            if let error = error {
                self.isLoading = false
                self.errorMessage = "Error saving user: \(error.localizedDescription)"
                Analytics.shared.track(
                    event: "username_save_failed",
                    properties: ["error": error.localizedDescription]
                )
                return
            }
            
            Analytics.shared.track(
                event: "new_user_created",
                properties: [
                    "user_id": userID,
                    "username": processedUsername
                ]
            )
            
            // Check if this is a web user
            db.collection("users").document(userID).getDocument { document, error in
                let createdFromWeb = document?.data()?["createdFromWeb"] as? Bool ?? false
                let winCode = document?.data()?["winCode"] as? String
                
                if createdFromWeb, let winCode = winCode {
                    self.isWebUser = true
                    self.claimWinCodeAndAwardPoints(
                        userID: userID,
                        winCode: winCode
                    )
                } else {
                    self.isWebUser = false
                    self.awardSignupBonus(userID: userID)
                }
            }
        }
    }
    
    // ── Web user flow: claim win code from ss-web-rate ────────────────────────
    func claimWinCodeAndAwardPoints(userID: String, winCode: String) {
        let cloudFunctionURL = URL(string: "https://claimwincode-vt3x7ykt4a-uc.a.run.app")!
        var request = URLRequest(url: cloudFunctionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "data": [
                "code": winCode,
                "swiftUserId": userID
            ]
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            // Failed to prepare — fall back to signup bonus
            self.awardSignupBonus(userID: userID)
            return
        }
        
        request.httpBody = httpBody
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else {
                    // Network error — fall back to signup bonus
                    print("⚠️ claimWinCode network error: \(error?.localizedDescription ?? "unknown")")
                    self.awardSignupBonus(userID: userID)
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let result = json["result"] as? [String: Any],
                       let success = result["success"] as? Bool,
                       success,
                       let points = result["points"] as? Int {
                        
                        // Successfully claimed — award points to leaderboard
                        Analytics.shared.track(
                            event: "web_win_code_claimed",
                            properties: ["user_id": userID, "points": points]
                        )
                        self.awardWebPoints(userID: userID, points: points)
                        
                    } else {
                        // Code already claimed or invalid — fall back to signup bonus
                        print("⚠️ claimWinCode failed, falling back to signup bonus")
                        self.awardSignupBonus(userID: userID)
                    }
                } catch {
                    self.awardSignupBonus(userID: userID)
                }
            }
        }.resume()
    }
    
    // ── Award web points to leaderboard + set profileComplete ─────────────────
    func awardWebPoints(userID: String, points: Int) {
        let functions = Functions.functions()
        functions.httpsCallable("awardLeaderboardPoints").call(["points": points]) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("⚠️ Failed to award web points: \(error)")
                } else {
                    print("✅ Web points awarded: \(points)")
                    Analytics.shared.track(
                        event: "web_points_awarded",
                        properties: ["user_id": userID, "points": points]
                    )
                }
                
                // Set profileComplete: true
                Firestore.firestore().collection("users").document(userID).updateData([
                    "profileComplete": true
                ])
                
                self.pointsToAward = points
                self.isLoading = false
                self.navigateToWelcomeBonus = true
            }
        }
    }
    
    // ── Non-web user flow: existing signup bonus ──────────────────────────────
    func awardSignupBonus(userID: String) {
        let functions = Functions.functions()
        functions.httpsCallable("awardLeaderboardPoints").call(["points": 100]) { result, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("⚠️ Failed to award signup bonus: \(error)")
                } else {
                    Analytics.shared.track(
                        event: "signup_bonus_awarded",
                        properties: ["user_id": userID, "points": 100]
                    )
                }
                
                self.pointsToAward = 100
                self.navigateToWelcomeBonus = true
            }
        }
    }
}
