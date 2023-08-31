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
            Text("Enter verification code")
                .font(.system(size: 18, weight: .semibold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(.black)
                .padding(.bottom, 40)
                .padding(.horizontal)
            
            // Phone Number TextField
            TextField("Enter verification code", text: $verificationCode)
                .keyboardType(.numberPad)
                .padding()
                .background(Color(hex: "#F5F5F5"))
                .foregroundColor(Color(hex: "#000"))
                .cornerRadius(5)
                .font(.system(size: 16, weight: .medium, design: .default))
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(Color(hex: "#CC2255"))
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .padding(.bottom, 10)
                    .padding(.top, 20)
                    .padding(.horizontal)
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
