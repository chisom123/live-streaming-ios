import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import PostHog

struct VerificationView: View {
    let phoneNumber: String
    let verificationID: String
    @Environment(\.presentationMode) var presentationMode
    
    @State private var verificationCode: String = ""
    @State private var errorMessage: String? = nil
    // Updated to include navigation to the home view
    @State private var navigateToHome = false
    @State private var navigateToNameEntry = false
    @State private var isLoading: Bool = false

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    // Dismiss the current view to go back
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .resizable() // Allows resizing of the image
                        .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                        .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                        .foregroundColor(Color.white) // Your desired color
                }
                Spacer()
            }
            .padding(20)
            
            Spacer()
            
            VStack {
                Text("Enter the verification code sent to \(phoneNumber)")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.white)
                    .padding(.top, 20)
                    .padding(.bottom, 25)
                    .padding(.horizontal)
                    .onAppear {
                        PostHogSDK.shared.capture("Verification Screen Viewed")
                    }
                
                // Verification Code TextField
                TextField("Enter verification code", text: $verificationCode)
                    .keyboardType(.numberPad)
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
                }
            
                if isLoading {
                    ProgressView()
                        .padding(.vertical, 20)
                        .tint(.white)
                } else {
                    Button(action: {
                        self.verifyCode()
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
            
            // Navigation links
            NavigationLink(destination: MyCompsView(), isActive: $navigateToHome) {
                EmptyView()
            }.isDetailLink(false)
            
            NavigationLink(destination: NameEntryView(phoneNumber: self.phoneNumber), isActive: $navigateToNameEntry) {
                EmptyView()
            }.isDetailLink(false)
            
            Spacer()
        }
        .background(Color(hex: "#10183C"))
        .navigationBarBackButtonHidden(true)
    }

    func verifyCode() {
        isLoading = true
        
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode)
        
        Auth.auth().signIn(with: credential) { (authResult, error) in
            if let error = error {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                PostHogSDK.shared.capture("Verification Failed", properties: ["error": error.localizedDescription])
                return
            }
            
            // After successful authentication, check for an existing username
            guard let userID = Auth.auth().currentUser?.uid else {
                self.isLoading = false
                self.errorMessage = "Error fetching user ID"
                return
            }
            
            PostHogSDK.shared.identify(userID)
            
            let db = Firestore.firestore()
            db.collection("users").document(userID).getDocument { (document, error) in
                if let document = document, document.exists {
                    if document.data()?["username"] != nil {
                        self.isLoading = false
                        // User already has a username, navigate directly to home view
                        self.navigateToHome = true
                        UserDefaults.standard.set(true, forKey: "isLoggedIn")
                        UserDefaults.standard.set(true, forKey: "isFriendActivated")
                        UserDefaults.standard.synchronize()
                        PostHogSDK.shared.capture("Returning User Signed In")
                    } else {
                        self.isLoading = false
                        // No username found, navigate to NameEntryView
                        self.navigateToNameEntry = true
                        PostHogSDK.shared.capture("New User Registration Started")
                    }
                } else {
                    self.isLoading = false
                    // Error or user document does not exist, navigate to NameEntryView
                    self.navigateToNameEntry = true
                    PostHogSDK.shared.capture("User Document Not Found")
                }
            }
        }
    }
}
