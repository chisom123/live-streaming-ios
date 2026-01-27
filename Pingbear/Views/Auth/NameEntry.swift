import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import CryptoKit

struct NameEntryView: View {
    let phoneNumber: String
    let fullName: String
    @State private var username: String = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false

    var body: some View {
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
            
            Spacer()
        }
        .background(Color(hex: "#10183C"))
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
            isLoading = false
            if let error = error {
                self.errorMessage = "Error saving user: \(error.localizedDescription)"
                Analytics.shared.track(
                    event: "username_save_failed",
                    properties: ["error": error.localizedDescription]
                )
            } else {
                Analytics.shared.track(
                    event: "new_user_created",
                    properties: [
                        "user_id": userID,
                        "username": processedUsername
                    ]
                )
                
                // Just update UserDefaults
                UserDefaults.standard.set(true, forKey: "isLoggedIn")
                UserDefaults.standard.synchronize()
                
                // Post notification to trigger UI update
                NotificationCenter.default.post(name: .authStateDidChange, object: nil)
            }
        }
    }
}
