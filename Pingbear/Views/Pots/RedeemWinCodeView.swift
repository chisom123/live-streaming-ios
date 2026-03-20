import SwiftUI
import FirebaseAuth
import FirebaseFunctions

extension Notification.Name {
    static let winCodeRedeemed = Notification.Name("winCodeRedeemed")
}

struct RedeemWinCodeView: View {
    @Environment(\.dismiss) private var dismiss
    
    var prefilledCode: String? = nil
    var onSuccess: (() -> Void)? = nil
    
    @State private var enteredCode: String = ""
    @State private var isRedeeming: Bool = false
    @State private var showSuccess: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var pointsEarned: Int = 0
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ZStack {
            Color(hex: "#10183C")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        Analytics.shared.trackTap(
                            elementId: "back_button",
                            screenName: "redeem_win_code"
                        )
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(Color.white)
                    }
                    
                    Spacer()
                    
                    Text("Claim Winnings")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    Color.clear
                        .frame(width: 27, height: 27)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                ScrollView {
                    VStack(spacing: 30) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Enter Your Win Code")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Enter the 10-character code you received after rating a story")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        
                        VStack(spacing: 0) {
                            TextField("Win Code", text: $enteredCode)
                                .padding()
                                .frame(height: 70)
                                .background(
                                    Color(hex: "#3B4374")
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                )
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .textCase(.uppercase)
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .accentColor(.white)
                                .onChange(of: enteredCode) { newValue in
                                    enteredCode = String(newValue.uppercased().prefix(10))
                                    
                                    if showError {
                                        showError = false
                                        errorMessage = ""
                                    }
                                }
                                .focused($isTextFieldFocused)
            
                            if showError && !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .foregroundColor(Color(hex: "#FF0000"))
                                    .font(.system(size: 16, weight: .bold, design: .default))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(10)
                                    .padding(.top, 20)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                Button(action: {
                    isTextFieldFocused = false
                    Analytics.shared.trackTap(
                        elementId: "claim_button",
                        screenName: "redeem_win_code"
                    )
                    redeemCode()
                }) {
                    HStack(spacing: 10) {
                        if isRedeeming {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Claim")
                                .font(.system(size: 18, weight: .bold))
                        }
                    }
                    .foregroundColor(
                        enteredCode.count == 10 && !isRedeeming
                        ? Color(.white)
                            : Color.gray.opacity(0.5)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(
                        enteredCode.count == 10 && !isRedeeming
                            ? Color(red: 65/255, green: 105/255, blue: 225/255)
                            : Color.gray.opacity(0.5)
                    )
                }
                .disabled(enteredCode.count != 10 || isRedeeming)
                .cornerRadius(200)
                .padding(.horizontal)
                .padding(.bottom)
            }
            
            // Success Overlay
            if showSuccess {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                VStack(spacing: 25) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 16/255, green: 185/255, blue: 129/255))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 12) {
                        Text("Code Claimed")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            Text("+\(pointsEarned)")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                            
                            Image("gem")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 49, height: 49)
                        }
                        
                        Text("Points Added")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Button(action: {
                        Analytics.shared.trackTap(
                            elementId: "claim_success_done_button",
                            screenName: "redeem_win_code"
                        )
                        showSuccess = false
                        onSuccess?()
                        NotificationCenter.default.post(name: .winCodeRedeemed, object: nil)
                        dismiss()
                    }) {
                        Text("Done")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(red: 65/255, green: 105/255, blue: 225/255))
                            .cornerRadius(200)
                    }
                    .padding(.horizontal, 40)
                }
                .padding(30)
                .background(Color(red: 26/255, green: 34/255, blue: 69/255))
                .cornerRadius(20)
                .padding(.horizontal, 30)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "redeem_win_code")
            
            if let code = prefilledCode {
                enteredCode = String(code.uppercased().prefix(10))
                Analytics.shared.trackTap(
                    elementId: "deep_link_code_prefilled",
                    screenName: "redeem_win_code"
                )
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
    
    private func redeemCode() {
        guard enteredCode.count == 10 else { return }
        guard Auth.auth().currentUser != nil else {
            errorMessage = "You must be signed in to claim codes"
            showError = true
            Analytics.shared.trackTap(
                elementId: "claim_failed_not_signed_in",
                screenName: "redeem_win_code"
            )
            return
        }
        
        isRedeeming = true
        
        let cloudFunctionURL = URL(string: "https://claimwincode-vt3x7ykt4a-uc.a.run.app")!
        var request = URLRequest(url: cloudFunctionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "data": [
                "code": enteredCode,
                "swiftUserId": Auth.auth().currentUser?.uid ?? ""
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            DispatchQueue.main.async {
                isRedeeming = false
                errorMessage = "Failed to prepare request"
                showError = true
                Analytics.shared.trackTap(
                    elementId: "claim_failed_request_serialization",
                    screenName: "redeem_win_code"
                )
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    isRedeeming = false
                    errorMessage = "Network error: \(error.localizedDescription)"
                    showError = true
                    Analytics.shared.trackTap(
                        elementId: "claim_failed_network_error",
                        screenName: "redeem_win_code"
                    )
                    return
                }
                
                guard let data = data else {
                    isRedeeming = false
                    errorMessage = "No response from server"
                    showError = true
                    Analytics.shared.trackTap(
                        elementId: "claim_failed_no_response",
                        screenName: "redeem_win_code"
                    )
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let result = json["result"] as? [String: Any],
                       let success = result["success"] as? Bool,
                       success,
                       let points = result["points"] as? Int {
                        
                        pointsEarned = points
                        awardLeaderboardPoints(points: points)
                        
                    } else if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let error = json["error"] as? [String: Any],
                              let message = error["message"] as? String {
                        isRedeeming = false
                        handleErrorMessage(message)
                        Analytics.shared.trackTap(
                            elementId: "claim_failed_server_error",
                            screenName: "redeem_win_code",
                            properties: ["error": message]
                        )
                    } else {
                        isRedeeming = false
                        errorMessage = "Invalid response from server"
                        showError = true
                        Analytics.shared.trackTap(
                            elementId: "claim_failed_invalid_response",
                            screenName: "redeem_win_code"
                        )
                    }
                } catch {
                    isRedeeming = false
                    errorMessage = "Failed to parse response"
                    showError = true
                    Analytics.shared.trackTap(
                        elementId: "claim_failed_parse_error",
                        screenName: "redeem_win_code"
                    )
                }
            }
        }.resume()
    }
    
    private func awardLeaderboardPoints(points: Int) {
        let functions = Functions.functions()
        functions.httpsCallable("awardLeaderboardPoints").call(["points": points]) { result, error in
            DispatchQueue.main.async {
                isRedeeming = false
                
                if let error = error {
                    print("⚠️ Failed to award leaderboard points: \(error)")
                    // Still show success — code was claimed, leaderboard is best-effort
                } else {
                    print("✅ Points awarded to leaderboard")
                    Analytics.shared.trackTap(
                        elementId: "claim_success",
                        screenName: "redeem_win_code",
                        properties: ["points_earned": points]
                    )
                }
                
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showSuccess = true
                }
            }
        }
    }
    
    private func handleErrorMessage(_ message: String) {
        switch message {
        case "Invalid win code":
            errorMessage = "This code doesn't exist. Please check and try again."
        case "Code already claimed":
            errorMessage = "This code has already been claimed."
        case "INTERNAL":
            errorMessage = "Valid code not found"
        default:
            errorMessage = message
        }
        showError = true
    }
}
