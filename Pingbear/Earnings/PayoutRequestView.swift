import SwiftUI

struct PayoutRequestView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: HostEarningsViewModel
    @State private var paypalEmail: String = ""
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isSuccess = false
    @State private var errorMessage: String? = nil
    
    // Validate email format
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email) && !email.isEmpty
    }
    
    // Request payout function
    private func requestPayout() {
        guard isValidEmail(paypalEmail) else {
            errorMessage = "Please enter a valid PayPal email address"
            return
        }
        
        if viewModel.availableEarnings <= 0 {
            errorMessage = "You don't have any available funds to withdraw"
            return
        }
        
        viewModel.requestPayout(paypalEmail: paypalEmail) { success, error in
            if success {
                alertTitle = "Success"
                alertMessage = "Your payout request has been submitted successfully. You will receive an email notification when the payment is processed."
                isSuccess = true
                showAlert = true
            } else {
                errorMessage = error ?? "An unknown error occurred. Please try again later."
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - styled like EditCompetitionView
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("Request Payout")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Empty space to balance the header
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 27, height: 27)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color(hex: "#1A2245"))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Amount info
                    VStack(alignment: .center, spacing: 5) {
                        Text("Available for payout")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(formatUSD(viewModel.availableEarnings))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.top, 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    
                    // PayPal email field label
                    Text("PayPal Email")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Email text field - styled like EditCompetitionView
                    TextField("Enter your PayPal email", text: $paypalEmail)
                        .padding()
                        .frame(height: 60)
                        .background(Color(hex: "#3B4374"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(Color(hex: "#FF0000"))
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .multilineTextAlignment(.leading)
                    }
                    
                    // Info text
                    Text("Your payout will be processed within 5-7 business days. You will receive an email notification when the payment is sent to your PayPal account.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                        .padding(.top, 10)
                    
                    // Spacer to push content up
                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Button(action: requestPayout) {
                    ZStack {
                        Text("Submit Request")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(isValidEmail(paypalEmail) && viewModel.availableEarnings > 0 ? Color(hex: "#FFF") : Color(hex: "#D3D3D3").opacity(0.2))
                        
                        if viewModel.requestingPayout {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .background(isValidEmail(paypalEmail) && viewModel.availableEarnings > 0 ? Color(hex: "#FF4081") : Color(hex: "#D3D3D3").opacity(0.2))
                    .cornerRadius(200)
                    .padding(.horizontal, 20)
                }
                .disabled(!isValidEmail(paypalEmail) || viewModel.availableEarnings <= 0 || viewModel.requestingPayout)
            }
        }
        .background(Color(hex: "#10183C"))
        .accentColor(.white)
        .ignoresSafeArea()
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if isSuccess {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            )
        }
    }
}

