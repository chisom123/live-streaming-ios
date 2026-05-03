import SwiftUI

struct CashOutSheet: View {

    let balance:         Double
    let maxWithdrawable: Double
    let bonusCredited:   Bool
    let bonusUnlocked:   Bool
    let onCashOut: (String, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var paypalEmail  = ""
    @State private var amountString = ""
    @State private var isSubmitting = false

    private var amount: Double { Double(amountString) ?? 0 }
    private var bonusLocked: Bool { bonusCredited && !bonusUnlocked }
    private var lockedAmount: Double { bonusLocked ? max(0, balance - maxWithdrawable) : 0 }

    private var amountIsValid: Bool {
        amount >= 5.0 && amount <= maxWithdrawable
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
            Color(hex: "#10183C").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Cash Out")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Invisible placeholder for balance
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(Color(hex: "#1A2245"))
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {

                        // ── Balance display ───────────────────────
                        VStack(spacing: 7) {
                            Text("Available to Withdraw")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.7))
                            Text("$\(String(format: "%.2f", maxWithdrawable))")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 8)

                        // ── Locked bonus notice ───────────────────
                        if bonusLocked && lockedAmount > 0 {
                            HStack(spacing: 10) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(hex: "#00AA00"))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("$\(String(format: "%.2f", lockedAmount)) welcome bonus")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Unlocks after your first competition")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(Color(hex: "#00AA00").opacity(0.08))
                            .cornerRadius(10)
                            .padding(.horizontal, 20)
                        }

                        // ── Amount input ──────────────────────────
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amount")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))

                            HStack(spacing: 0) {
                                Text("$")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.leading, 12)

                                TextField("0.00", text: $amountString)
                                    .textFieldStyle(.plain)
                                    .keyboardType(.decimalPad)
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .bold, design: .default))
                                    .tint(.white)
                                    .padding(.leading, 4)

                                Button("Max") {
                                    amountString = String(format: "%.2f", maxWithdrawable)
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.trailing, 12)
                            }
                            .padding()
                            .frame(height: 60)
                            .background(
                                Color(hex: "#3B4374")
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            )

                            if !amountString.isEmpty && !amountIsValid {
                                Text(
                                    amount < 5.0
                                        ? "Minimum withdrawal is $5.00"
                                        : "Amount exceeds your available balance"
                                )
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.red.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 20)

                        // ── PayPal email ──────────────────────────
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PayPal Email")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))

                            TextField("email@example.com", text: $paypalEmail)
                                .textFieldStyle(.plain)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .tint(.white)
                                .padding()
                                .frame(height: 60)
                                .background(
                                    Color(hex: "#3B4374")
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                )
                            
                            // PayPal sign up link
                            Link(destination: URL(string: "https://www.paypal.com/signup")!) {
                                HStack(spacing: 4) {
                                    Text("Don't have PayPal?")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.6))
                                    Text("Sign up here")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(.horizontal, 20)

                        // ── Processing note ───────────────────────
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.4))
                            Text("Withdrawals are reviewed manually and processed within 1–3 business days.")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 20)

                        // ── No withdrawable funds message ─────────
                        if maxWithdrawable < 5.0 && bonusLocked {
                            Text("Top up your wallet or complete your first competition to unlock your welcome bonus.")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                }
                
                // ── Request Withdrawal button (fixed at bottom) ──
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
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .background(
                        canSubmit
                            ? Color(hex: "#00AA00")
                            : Color(hex: "#D3D3D3").opacity(0.2)
                    )
                    .foregroundColor(
                        canSubmit
                            ? Color(hex: "#FFF")
                            : Color(hex: "#D3D3D3").opacity(0.2)
                    )
                    .cornerRadius(200)
                }
                .disabled(!canSubmit)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(hex: "#10183C"))
            }
        }
    }
}
