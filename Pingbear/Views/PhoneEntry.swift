import SwiftUI
import Firebase
import FirebaseAuth

struct PhoneEntryView: View {
    @State private var phoneNumber: String = ""
    @State private var verificationID: String? = nil
    @State private var errorMessage: String? = nil
    @State private var showVerificationView = false

    var body: some View {
        VStack {
            Text("Enter your phone number")
                .font(.system(size: 18, weight: .semibold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(.black)
                .padding(.bottom, 40)
                .padding(.horizontal)
            
            TextField("Enter phone number", text: $phoneNumber)
                .keyboardType(.phonePad)
                .padding()
                .border(Color.gray, width: 0.5)

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(Color(hex: "#CC2255"))
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .padding(.bottom, 40)
                    .padding(.horizontal)
            }

            Button("Continue") {
                self.sendVerificationCode()
            }
            .padding(EdgeInsets(top: 18, leading: 0, bottom: 18, trailing: 0))
            .frame(maxWidth: .infinity)
            .background(Color(hex: "#1199FF"))
            .foregroundColor(Color(hex: "#fff"))
            .font(.system(size: 18, weight: .bold, design: .default))
            .cornerRadius(200)
            .padding(.horizontal)
            .padding(.bottom, 20)

            NavigationLink(destination: VerificationView(phoneNumber: phoneNumber, verificationID: verificationID ?? ""), isActive: $showVerificationView) {
                EmptyView()
            }.isDetailLink(false)
        }
        .padding()
        .navigationBarBackButtonHidden(true)
    }

    func sendVerificationCode() {
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { (verificationID, error) in
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }

            self.verificationID = verificationID
            self.showVerificationView = true
        }
    }
}
