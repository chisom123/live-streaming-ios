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

    var body: some View {
        ZStack {
            Color(hex: "#10183C").ignoresSafeArea()

            VStack {
                Spacer()

                VStack {
                    Text("Create a username")
                        .font(.system(size: 18, weight: .bold))
                        .multilineTextAlignment(.center)
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
                        .font(.system(size: 16, weight: .bold))
                        .autocapitalization(.none)

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(Color(hex: "#FF0000"))
                            .font(.system(size: 16, weight: .bold))
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)
                            .padding(.horizontal)
                    }

                    if isLoading {
                        ProgressView()
                            .padding(.vertical, 20)
                            .tint(.white)
                    } else {
                        Button(action: {
                            self.hideKeyboard()
                            self.checkUsernameAndSave()
                        }) {
                            Text("Continue")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .font(.system(size: 18, weight: .bold))
                                .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .background(Color(hex: "#4169E1"))
                                .foregroundColor(.white)
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
                    destination: WelcomeBonusView(),
                    isActive: $navigateToWelcomeBonus
                ) {
                    EmptyView()
                }.isDetailLink(false)

                Spacer()
            }
        }
        .navigationBarHidden(true)
    }

    // ── Validate username ─────────────────────────────────────

    func checkUsernameAndSave() {
        isLoading = true
        let processedUsername = username.lowercased()
            .replacingOccurrences(of: " ", with: "")

        let validation = isValidUsername(processedUsername)
        guard validation.isValid else {
            errorMessage = validation.error
            isLoading = false
            return
        }

        let db = Firestore.firestore()

        db.collection("users")
            .whereField("username", isEqualTo: processedUsername)
            .getDocuments { snapshot, error in
                if let error {
                    self.isLoading = false
                    self.errorMessage = "Error checking username: \(error.localizedDescription)"
                    return
                }

                guard snapshot?.documents.isEmpty == true else {
                    self.isLoading = false
                    self.errorMessage = "This username is already taken"
                    return
                }

                self.saveUser(username: processedUsername)
            }
    }

    // ── Save user then credit welcome bonus ───────────────────

    func saveUser(username: String) {
        guard let user = Auth.auth().currentUser else {
            isLoading = false
            errorMessage = "Error fetching user ID"
            return
        }

        let userID = user.uid
        let db = Firestore.firestore()
        let hashedPhone = hashPhoneNumber(phoneNumber)

        // Step 1 — save username to Firestore
        db.collection("users").document(userID).setData([
            "username":        username,
            "phoneNumberHash": hashedPhone,
            "name":            fullName
        ], merge: true) { error in
            if let error {
                self.isLoading = false
                self.errorMessage = "Error saving user: \(error.localizedDescription)"
                return
            }

            Analytics.shared.track(
                event: "new_user_created",
                properties: ["user_id": userID, "username": username]
            )

            // Step 2 — force token refresh so Functions SDK has
            // a valid auth token before calling creditWelcomeBonus
            user.getIDTokenForcingRefresh(true) { _, _ in
                Functions.functions()
                    .httpsCallable("creditWelcomeBonus")
                    .call([:]) { _, error in
                        DispatchQueue.main.async {
                            self.isLoading = false

                            if let error {
                                print("⚠️ creditWelcomeBonus failed: \(error.localizedDescription)")
                            }

                            self.navigateToWelcomeBonus = true
                        }
                    }
            }
        }
    }

    // ── Hash phone number ─────────────────────────────────────

    func hashPhoneNumber(_ phoneNumber: String) -> String {
        let cleaned = phoneNumber
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        let salt = "5Ax1HpaMDwxIv15M6t4ZdGuC8"
        let hash = SHA256.hash(data: Data((salt + cleaned).utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
