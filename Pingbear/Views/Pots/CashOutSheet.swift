import SwiftUI

struct CashOutSheet: View {
    let balance: Double
    let onCashOut: (String, [String: String]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var paypalEmail = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Cash Out $\(String(format: "%.2f", balance))")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                    .onAppear {
                        Analytics.shared.trackScreen(name: "cash_out_sheet")
                    }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("PayPal Email")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    TextField("email@example.com", text: $paypalEmail)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color(hex: "#1A2245"))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                }
                .padding(.horizontal, 20)
                
                Text("Processing takes 1-3 business days")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
                
                Button(action: {
                    onCashOut("PayPal", ["email": paypalEmail])
                    Analytics.shared.trackTap(
                        elementId: "confirm_cash_out",
                        screenName: "cash_out_sheet"
                    )
                    dismiss()
                }) {
                    Text("Confirm Cash Out")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#00AA00"))
                        .cornerRadius(200)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .disabled(paypalEmail.isEmpty)
                .opacity(paypalEmail.isEmpty ? 0.5 : 1.0)
            }
            .background(Color(hex: "#10183C"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}
