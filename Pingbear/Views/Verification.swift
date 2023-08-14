import SwiftUI
import Firebase
import FirebaseAuth

struct VerificationView: View {
    let phoneNumber: String
    let verificationID: String
    
    @State private var verificationCode: String = ""
    @State private var errorMessage: String? = nil
    @State private var isAuthenticated = false

    var body: some View {
        VStack {
            TextField("Enter verification code", text: $verificationCode)
                .keyboardType(.numberPad)
                .padding()
                .border(Color.gray, width: 0.5)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
            
            Button("Continue") {
                self.verifyCode()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            NavigationLink(destination: NameEntryView(phoneNumber: self.phoneNumber), isActive: $isAuthenticated) {
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
                return
            }
            
            self.isAuthenticated = true
        }
    }
}
