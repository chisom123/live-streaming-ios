import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

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
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left").resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27).foregroundColor(AppTheme.iconColor)
                    }
                    Spacer()
                }
                .padding(20)
                Spacer()
                VStack {
                    Text("Enter the verification code sent to \(phoneNumber)")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .multilineTextAlignment(.center).lineSpacing(10)
                        .foregroundColor(AppTheme.primaryText)
                        .padding(.top, 20).padding(.bottom, 25).padding(.horizontal)
                        .onAppear { Analytics.shared.trackScreen(name: "verification") }

                    TextField("Enter verification code", text: $verificationCode)
                        .keyboardType(.numberPad).padding().frame(height: 60)
                        .background(AppTheme.inputBackground.clipShape(RoundedRectangle(cornerRadius: 10)))
                        .foregroundColor(AppTheme.primaryText)
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .tint(AppTheme.accent)

                    if let error = errorMessage {
                        Text(error).foregroundColor(.red).font(.system(size: 16, weight: .bold, design: .default))
                            .multilineTextAlignment(.center).lineSpacing(10).padding(.top, 20).padding(.horizontal)
                    }

                    if isLoading {
                        ProgressView().padding(.vertical, 20).tint(AppTheme.primaryText)
                    } else {
                        Button(action: { self.hideKeyboard(); self.verifyCode() }) {
                            Text("Continue").frame(maxWidth: .infinity, minHeight: 44)
                                .font(.system(size: 18, weight: .bold, design: .default))
                                .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .background(AppTheme.accent).foregroundColor(.white).cornerRadius(200)
                        }
                        .padding(.top, 20)

                        Button(action: { self.hideKeyboard(); resendVerificationCode() }) {
                            HStack(spacing: 4) {
                                Text("Didn\'t receive a code?").font(.system(size: 16)).foregroundColor(AppTheme.secondaryText)
                                Text("Resend Code").font(.system(size: 16, weight: .semibold, design: .default)).foregroundColor(AppTheme.primaryText)
                            }
                        }
                        .disabled(isResending).padding(.top, 25).padding(.bottom, 10)
                    }
                }
                .frame(maxWidth: .infinity).padding(20)
                .background(AppTheme.cardBackground).cornerRadius(10).padding(.horizontal, 20)

                NavigationLink(destination: RealNameEntryView(phoneNumber: self.phoneNumber), isActive: $navigateToNameEntry) { EmptyView() }.isDetailLink(false)
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    func verifyCode() {
        isLoading = true
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: verificationCode)
        Auth.auth().signIn(with: credential) { (authResult, error) in
            if let error = error {
                self.isLoading = false; self.errorMessage = error.localizedDescription
                Analytics.shared.track(event: "verification_failed", properties: ["error": error.localizedDescription]); return
            }
            guard let userID = Auth.auth().currentUser?.uid else { self.isLoading = false; self.errorMessage = "Error fetching user ID"; return }
            Analytics.shared.identify(userId: userID)
            let db = Firestore.firestore()
            db.collection("users").document(userID).getDocument { (document, error) in
                if let document = document, document.exists {
                    let data = document.data() ?? [:]
                    if data["username"] != nil {
                        if let winCode = data["winCode"] as? String { claimWinCodeInBackground(winCode: winCode, userID: userID) }
                        DispatchQueue.main.async {
                            self.isLoading = false
                            UserDefaults.standard.set(true, forKey: "isLoggedIn")
                            UserDefaults.standard.set(true, forKey: "isFriendActivated")
                            UserDefaults.standard.synchronize()
                            NotificationCenter.default.post(name: .authStateDidChange, object: nil)
                        }
                        Analytics.shared.track(event: "returning_user_signed_in")
                    } else { self.isLoading = false; self.navigateToNameEntry = true; Analytics.shared.track(event: "new_user_registration_started") }
                } else { self.isLoading = false; self.navigateToNameEntry = true; Analytics.shared.track(event: "user_document_not_found") }
            }
        }
    }

    private func claimWinCodeInBackground(winCode: String, userID: String) {
        let cloudFunctionURL = URL(string: "https://claimwincode-vt3x7ykt4a-uc.a.run.app")!
        var request = URLRequest(url: cloudFunctionURL)
        request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let requestBody: [String: Any] = ["data": ["code": winCode, "swiftUserId": userID]]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else { return }
        request.httpBody = httpBody
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let result = json["result"] as? [String: Any],
                   let success = result["success"] as? Bool, success,
                   let points = result["points"] as? Int {
                    Functions.functions().httpsCallable("awardLeaderboardPoints").call(["points": points]) { _, error in
                        if error == nil {
                            Firestore.firestore().collection("users").document(userID).updateData(["winCode": FieldValue.delete()])
                            Analytics.shared.track(event: "web_win_code_claimed_background", properties: ["user_id": userID, "points": points])
                        }
                    }
                }
            } catch {}
        }.resume()
    }

    func resendVerificationCode() {
        isResending = true
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { (newVerificationID, error) in
            self.isResending = false
            if let error = error {
                self.errorMessage = "Failed to resend code: \(error.localizedDescription)"
                Analytics.shared.track(event: "verification_code_resend_failed", properties: ["error": error.localizedDescription]); return
            }
            Analytics.shared.track(event: "verification_code_resent", properties: ["phone_number": self.phoneNumber])
        }
    }
}

extension Notification.Name {
    static let authStateDidChange = Notification.Name("authStateDidChange")
}
