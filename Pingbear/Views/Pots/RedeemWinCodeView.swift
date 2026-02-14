import SwiftUI
import FirebaseAuth
import FirebaseFunctions

struct RedeemWinCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var enteredCode: String = ""
    @State private var isRedeeming: Bool = false
    @State private var showSuccess: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var pointsEarned: Int = 0
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ZStack {
            Color(hex: "#1A2245")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable() // Allows resizing of the image
                            .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                            .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                            .foregroundColor(Color.white) // Your desired color
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
                        // Instructions
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
                        
                        // Code Input and Button (wrapped together with no spacing)
                        VStack(spacing: 0) {
                            // Code Input
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
                                .autocapitalization(.words)
                                .onChange(of: enteredCode) { newValue in
                                    // Auto-uppercase and limit to 10 characters
                                    enteredCode = String(newValue.uppercased().prefix(10))
                                    
                                    // Clear error when user starts typing again
                                    if showError {
                                        showError = false
                                        errorMessage = ""
                                    }
                                }
                                .focused($isTextFieldFocused)
            
                            // Error Message Text
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
                
                // Redeem Button
                Button(action: {
                    isTextFieldFocused = false
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
                    // Success Icon
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
                                .frame(width: 42, height: 42)
                        }
                        
                        Text("Points Added")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Button(action: {
                        showSuccess = false
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
    
    private func redeemCode() {
        guard enteredCode.count == 10 else { return }
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be signed in to claim codes"
            showError = true
            return
        }
        
        isRedeeming = true
        
        // Call Cloud Function on Firebase A (React project)
        let cloudFunctionURL = URL(string: "https://claimwincode-vt3x7ykt4a-uc.a.run.app")!
        var request = URLRequest(url: cloudFunctionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "data": [
                "code": enteredCode,
                "swiftUserId": userId
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            DispatchQueue.main.async {
                isRedeeming = false
                errorMessage = "Failed to prepare request"
                showError = true
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isRedeeming = false
                
                if let error = error {
                    errorMessage = "Network error: \(error.localizedDescription)"
                    showError = true
                    return
                }
                
                guard let data = data else {
                    errorMessage = "No response from server"
                    showError = true
                    return
                }
                
                // Parse response
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let result = json["result"] as? [String: Any],
                       let success = result["success"] as? Bool,
                       success,
                       let points = result["points"] as? Int {
                        
                        // Success!
                        pointsEarned = points
                        
                        // Add points to global leaderboard
                        GlobalLeaderboardManager.shared.handleStarAwarded(
                            userId: userId,
                            stars: points,
                            competitionId: "web_ratings"
                        ) { success in
                            if success {
                                print("✅ Points added to global leaderboard")
                            } else {
                                print("⚠️ Failed to add points to leaderboard")
                            }
                        }
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showSuccess = true
                        }
                    } else if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let error = json["error"] as? [String: Any],
                              let message = error["message"] as? String {
                        // Error from Cloud Function
                        handleErrorMessage(message)
                    } else {
                        errorMessage = "Invalid response from server"
                        showError = true
                    }
                } catch {
                    errorMessage = "Failed to parse response"
                    showError = true
                }
            }
        }.resume()
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
