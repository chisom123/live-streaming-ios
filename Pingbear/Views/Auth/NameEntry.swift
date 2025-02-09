import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import CryptoKit
import PostHog

struct NameEntryView: View {
    let phoneNumber: String
    @State private var username: String = ""
    @State private var errorMessage: String? = nil
    @State private var navigateToHome = false
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
                        PostHogSDK.shared.capture("Username Entry View Opened")
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
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(Color(hex: "#FF0000"))
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .padding(.top, 20)
                        .padding(.horizontal)
                        .onAppear {
                            PostHogSDK.shared.capture("Username Entry Error", properties: ["error": error])
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
                            .background(Color(hex: "#FF4081"))
                            .foregroundColor(Color(hex: "#fff"))
                            .cornerRadius(200)
                    }
                    .padding(.top, 20)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color(hex: "#1A2245"))
            .cornerRadius(10)
            .padding(.horizontal, 20)

            NavigationLink(destination: MyCompsView(), isActive: $navigateToHome) {
                EmptyView()
            }.isDetailLink(false)
            
            Spacer()
        }
        .background(Color(hex: "#10183C"))
        .navigationBarHidden(true)
    }
    
    func checkUsernameAndSaveToFirestore() {
        isLoading = true
        let processedUsername = username.lowercased().replacingOccurrences(of: " ", with: "")
        
        // Use the new validation function
        let validation = isValidUsername(processedUsername)
        guard validation.isValid else {
            errorMessage = validation.error
            isLoading = false
            PostHogSDK.shared.capture("Username Validation Failed", properties: ["username": processedUsername, "error": validation.error ?? "No error provided"])
            return
        }

        let db = Firestore.firestore()
       
        // Check if username is already taken
        db.collection("users").whereField("username", isEqualTo: processedUsername).getDocuments { (querySnapshot, err) in
            if let err = err {
                isLoading = false
                errorMessage = "Error checking username: \(err.localizedDescription)"
                PostHogSDK.shared.capture("Username Check Failed", properties: ["error": err.localizedDescription])
            } else if querySnapshot!.documents.isEmpty {
                // Username is unique, proceed to save
                saveUsernameToFirestore(processedUsername: processedUsername)
            } else {
                isLoading = false
                errorMessage = "This username is already taken"
                PostHogSDK.shared.capture("Username Already Taken", properties: ["username": processedUsername])
            }
        }
    }
    
    func hashPhoneNumber(_ phoneNumber: String) -> String {
        // Normalize phone number (remove non-digit characters)
        let cleanedNumber = phoneNumber
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        
        // Use a fixed, app-wide salt
        let salt = "5Ax1HpaMDwxIv15M6t4ZdGuC8"
        
        // Hash the normalized number with the consistent salt
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
        
        // Hash the phone number before storing
        let hashedPhoneNumber = hashPhoneNumber(phoneNumber)
       
        db.collection("users").document(userID).setData([
            "username": processedUsername,
            "phoneNumberHash": hashedPhoneNumber // Store hashed phone number instead
        ], merge: true) { error in
            isLoading = false
            if let error = error {
                self.errorMessage = "Error saving user: \(error.localizedDescription)"
                PostHogSDK.shared.capture("Username Save Failed", properties: ["error": error.localizedDescription])
            } else {
                self.navigateToHome = true
                UserDefaults.standard.set(true, forKey: "isLoggedIn")
                UserDefaults.standard.synchronize()
                PostHogSDK.shared.capture("New User Created", properties: ["userID": userID, "username": processedUsername])
            }
        }
    }
}
