import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct VerificationView: View {
    let phoneNumber: String
    let verificationID: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var verificationCode: String = ""
    @State private var errorMessage: String? = nil
    @State private var navigateToNameEntry = false
    @State private var isLoading: Bool = false
    @State private var isResending: Bool = false

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(Color.white)
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
                        Analytics.shared.trackScreen(name: "verification")
                    }
                
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
                            .background(Color(hex: "#32CD32"))
                            .foregroundColor(Color(hex: "#fff"))
                            .cornerRadius(200)
                    }
                    .padding(.top, 20)
                    
                    // Resend code button
                    Button(action: {
                        resendVerificationCode()
                    }) {
                        HStack(spacing: 4) {
                            Text("Didn't receive a code?")
                                .font(.system(size: 16))
                                .foregroundColor(Color.white.opacity(0.7))
                            
                            Text("Resend Code")
                                .font(.system(size: 16, weight: .semibold, design: .default))
                                .foregroundColor(Color.white)
                        }
                    }
                    .disabled(isResending)
                    .padding(.top, 25)
                    .padding(.bottom, 10)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color(hex: "#1A2245"))
            .cornerRadius(10)
            .padding(.horizontal, 20)
            
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
                Analytics.shared.track(
                    event: "verification_failed",
                    properties: ["error": error.localizedDescription]
                )
                return
            }
            
            guard let userID = Auth.auth().currentUser?.uid else {
                self.isLoading = false
                self.errorMessage = "Error fetching user ID"
                return
            }
            
            Analytics.shared.identify(userId: userID)
            
            let db = Firestore.firestore()
            db.collection("users").document(userID).getDocument { (document, error) in
                if let document = document, document.exists {
                    if document.data()?["username"] != nil {
                        self.isLoading = false
                        // User already has a username - just update UserDefaults
                        UserDefaults.standard.set(true, forKey: "isLoggedIn")
                        UserDefaults.standard.set(true, forKey: "isFriendActivated")
                        UserDefaults.standard.synchronize()
                        
                        // Post notification to trigger UI update
                        NotificationCenter.default.post(name: .authStateDidChange, object: nil)
                        
                        Analytics.shared.track(event: "returning_user_signed_in")
                    } else {
                        self.isLoading = false
                        self.navigateToNameEntry = true
                        Analytics.shared.track(event: "new_user_registration_started")
                    }
                } else {
                    self.isLoading = false
                    self.navigateToNameEntry = true
                    Analytics.shared.track(event: "user_document_not_found")
                }
            }
        }
    }
    
    func resendVerificationCode() {
        isResending = true
        
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { (newVerificationID, error) in
            self.isResending = false
            
            if let error = error {
                self.errorMessage = "Failed to resend code: \(error.localizedDescription)"
                Analytics.shared.track(
                    event: "verification_code_resend_failed",
                    properties: ["error": error.localizedDescription]
                )
                return
            }
            
            Analytics.shared.track(
                event: "verification_code_resent",
                properties: ["phone_number": self.phoneNumber]
            )
        }
    }
}

extension Notification.Name {
    static let authStateDidChange = Notification.Name("authStateDidChange")
}
