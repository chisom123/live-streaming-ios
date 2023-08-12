//
//  PhoneEntry.swift
//  Pingbear
//
//  Created by Ezi Agu on 20/05/1402 AP.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct PhoneEntryView: View {
    @State private var phoneNumber: String = ""
    @State private var verificationID: String? = nil
    @State private var errorMessage: String? = nil
    @State private var showVerificationView = false

    var body: some View {
        NavigationView {   // <-- Make sure you have NavigationView wrapping the content
            VStack(spacing: 20) {
                TextField("Enter phone number", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .padding()
                    .border(Color.gray, width: 0.5)

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }

                Button("Send Verification Code") {
                    self.sendVerificationCode()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)

                NavigationLink(destination: VerificationView(phoneNumber: phoneNumber, verificationID: verificationID ?? ""), isActive: $showVerificationView) {
                    EmptyView() // This will be automatically triggered due to isActive binding
                }.isDetailLink(false)  // This ensures there are no conflicts with other navigation links
            }
            .padding()
        }
    }

    func sendVerificationCode() {
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { (verificationID, error) in
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }

            // Successfully sent verification ID
            self.verificationID = verificationID
            self.showVerificationView = true
        }
    }
}
