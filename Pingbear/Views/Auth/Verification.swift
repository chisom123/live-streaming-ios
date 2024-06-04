import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import PostHog

struct VerificationView: View {
    let phoneNumber: String
    let verificationID: String
    
    @State private var verificationCode: String = ""
    @State private var errorMessage: String? = nil
    // Updated to include navigation to the home view
    @State private var navigateToHome = false
    @State private var navigateToNameEntry = false

    var body: some View {
        VStack {
            Text("Enter verification code")
                .font(.system(size: 18, weight: .bold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(.black)
                .padding(.bottom, 40)
                .padding(.horizontal)
                .onAppear {
                    PostHogSDK.shared.capture("Verification Screen Viewed")
                }
            
            // Phone Number TextField
            TextField("Enter verification code", text: $verificationCode)
                .keyboardType(.numberPad)
                .padding()
                .background(Color(hex: "#F5F5F5"))
                .foregroundColor(Color(hex: "#000"))
                .cornerRadius(5)
                .font(.system(size: 16, weight: .bold, design: .default))
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(Color(hex: "#CC2255"))
                    .font(.system(size: 15, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .padding(.bottom, 10)
                    .padding(.top, 20)
                    .padding(.horizontal)
                    .onAppear {
                        PostHogSDK.shared.capture("Verification Error", properties: ["error": error])
                    }
            }

            Button(action: {
                self.verifyCode()
            }) {
                Text("Continue")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .background(Color(hex: "#1199FF"))
                    .foregroundColor(Color(hex: "#fff"))
                    .cornerRadius(200)
            }
            .padding(.top, 20)
            
            // Conditional navigation based on user state
            NavigationLink(destination: ContentView(), isActive: $navigateToHome) {
                EmptyView()
            }.isDetailLink(false)
            
            NavigationLink(destination: NameEntryView(phoneNumber: self.phoneNumber), isActive: $navigateToNameEntry) {
                EmptyView()
            }.isDetailLink(false)
        }
        .padding()
    }

    func verifyCode() {
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode)
        
        Auth.auth().signIn(with: credential) { (authResult, error) in
            if let error = error {
                self.errorMessage = error.localizedDescription
                PostHogSDK.shared.capture("Verification Failed", properties: ["error": error.localizedDescription])
                return
            }
            
            // After successful authentication, check for an existing username
            guard let userID = Auth.auth().currentUser?.uid else {
                self.errorMessage = "Error fetching user ID"
                return
            }
            
            PostHogSDK.shared.identify(userID)
            
            let db = Firestore.firestore()
            db.collection("users").document(userID).getDocument { (document, error) in
                if let document = document, document.exists {
                    if document.data()?["username"] != nil {
                        // User already has a username, navigate directly to home view
                        self.navigateToHome = true
                        UserDefaults.standard.set(true, forKey: "isLoggedIn")
                        UserDefaults.standard.set(true, forKey: "isFriendActivated")
                        UserDefaults.standard.synchronize()
                        PostHogSDK.shared.capture("Returning User Signed In")
                    } else {
                        // No username found, navigate to NameEntryView
                        self.navigateToNameEntry = true
                        PostHogSDK.shared.capture("New User Registration Started")
                    }
                } else {
                    // Error or user document does not exist, navigate to NameEntryView
                    self.navigateToNameEntry = true
                    PostHogSDK.shared.capture("User Document Not Found")
                }
            }
        }
    }
}
