import SwiftUI

struct CashOutSheet: View {

    let balance:   Double
    let onCashOut: (String, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var paypalEmail  = ""
    @State private var amountString = ""
    @State private var isSubmitting = false

    private var amount: Double { Double(amountString) ?? 0 }

    private var amountIsValid: Bool {
        amount >= 5.0 && amount <= balance
    }

    private var emailIsValid: Bool {
        let regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
        return paypalEmail.wholeMatch(of: regex) != nil
    }

    private var canSubmit: Bool {
        amountIsValid && emailIsValid && !isSubmitting
    }

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(AppTheme.iconColor)
                    }
                    Spacer()
                    Text("Cash Out")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                        .onAppear { Analytics.shared.trackScreen(name: "cash_out_sheet") }
                    Spacer()
                    Color.clear.frame(width: 27, height: 27)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(AppTheme.cardBackground)

                // ── Content ───────────────────────────────────
                ScrollView {
                    VStack(spacing: 24) {

                        // Balance display
                        VStack(spacing: 7) {
                            Text("Available to Withdraw")
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.secondaryText)
                            Text("$\(String(format: "%.2f", balance))")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(AppTheme.primaryText)
                        }
                        .padding(.top, 8)

                        // Amount input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amount")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.secondaryText)

                            HStack(spacing: 0) {
                                Text("$")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(AppTheme.primaryText)
                                    .padding(.leading, 12)

                                TextField("0.00", text: $amountString)
                                    .textFieldStyle(.plain)
                                    .keyboardType(.decimalPad)
                                    .foregroundColor(AppTheme.primaryText)
                                    .font(.system(size: 16, weight: .bold))
                                    .tint(AppTheme.accent)
                                    .padding(.leading, 4)

                                Button("Max") {
                                    amountString = String(format: "%.2f", balance)
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.accent)
                                .padding(.trailing, 12)
                            }
                            .padding()
                            .frame(height: 60)
                            .background(AppTheme.cardBackground.clipShape(RoundedRectangle(cornerRadius: 10)))

                            if !amountString.isEmpty && !amountIsValid {
                                Text(amount < 5.0
                                     ? "Minimum withdrawal is $5.00"
                                     : "Amount exceeds your available balance")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 20)

                        // PayPal email
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PayPal Email")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.secondaryText)

                            TextField("email@example.com", text: $paypalEmail)
                                .textFieldStyle(.plain)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .foregroundColor(AppTheme.primaryText)
                                .font(.system(size: 16, weight: .bold))
                                .tint(AppTheme.accent)
                                .padding()
                                .frame(height: 60)
                                .background(AppTheme.cardBackground.clipShape(RoundedRectangle(cornerRadius: 10)))

                            Link(destination: URL(string: "https://www.paypal.com/signup")!) {
                                HStack(spacing: 4) {
                                    Text("Don't have PayPal?")
                                        .font(.system(size: 13))
                                        .foregroundColor(AppTheme.secondaryText)
                                    Text("Sign up here")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.accent)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(.horizontal, 20)

                        // Processing note
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.secondaryText)
                            Text("Withdrawals are reviewed manually and processed within 1–3 business days.")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.secondaryText)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                }

                // ── Submit button ─────────────────────────────
                Button {
                    isSubmitting = true
                    onCashOut(
                        paypalEmail.trimmingCharacters(in: .whitespaces),
                        amount
                    )
                } label: {
                    Group {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Request Withdrawal")
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .font(.system(size: 18, weight: .bold))
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .background(canSubmit ? AppTheme.green : AppTheme.disabledBackground)
                    .foregroundColor(canSubmit ? .white : AppTheme.disabledText)
                    .cornerRadius(200)
                }
                .disabled(!canSubmit)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(AppTheme.pageBackground)
            }
        }
    }
}
