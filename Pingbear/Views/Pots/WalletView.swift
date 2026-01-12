import SwiftUI
import FirebaseAuth

struct WalletView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WalletViewModel()
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .resizable() // Allows resizing of the image
                            .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                            .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                            .foregroundColor(Color.white) // Your desired color
                    }
                    
                    Spacer()
                    
                    Text("Wallet")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .onAppear {
                            Analytics.shared.trackScreen(name: "wallet_view")
                        }
                    
                    Spacer()
                    
                    Button(action: {
                     
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable() // Allows resizing of the image
                            .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                            .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                            .foregroundColor(Color.white) // Your desired color
                    }
                    .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Balance Card
                            VStack(spacing: 16) {
                                Text("Available Balance")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text("$\(String(format: "%.2f", viewModel.balance))")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Button(action: {
                                    if viewModel.balance >= 5.0 {
                                        viewModel.showCashOutSheet = true
                                        
                                        Analytics.shared.trackTap(
                                            elementId: "cash_out_button",
                                            screenName: "wallet_view"
                                        )
                                    }
                                }) {
                                    Text("Cash Out")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(viewModel.balance >= 5.0 ? .white : Color(hex: "#D3D3D3").opacity(0.2))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 15)
                                        .background(viewModel.balance >= 5.0 ? Color(hex: "#00AA00") : Color(hex: "#D3D3D3").opacity(0.2))
                                        .cornerRadius(200)
                                }
                                .disabled(viewModel.balance < 5.0)

                                if viewModel.balance > 0 && viewModel.balance < 5.0 {
                                    Text("Minimum cash out is $5.00")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.top, 8)
                                }
                            }
                            .padding(24)
                            .background(Color(hex: "#1A2245"))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                            
                            // Withdrawals History
                            if !viewModel.withdrawals.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Withdrawal History")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.bottom, 10)
                                    
                                    VStack(spacing: 0) {
                                        ForEach(viewModel.withdrawals) { withdrawal in
                                            WithdrawalRow(
                                                withdrawal: withdrawal,
                                                isLast: withdrawal.id == viewModel.withdrawals.last?.id
                                            )
                                        }
                                    }
                                    .background(Color(hex: "#1A2245"))
                                    .cornerRadius(12)
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(Color(hex: "#10183C"))
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $viewModel.showCashOutSheet) {
            CashOutSheet(
                balance: viewModel.balance,
                onCashOut: { paymentMethod, details in
                    viewModel.processCashOut(paymentMethod: paymentMethod, details: details)
                }
            )
        }
        .onAppear {
            viewModel.loadWalletData()
        }
    }
}

struct WithdrawalRow: View {
    let withdrawal: Withdrawal
    let isLast: Bool // Add this parameter
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("$\(String(format: "%.2f", withdrawal.amount))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(dateString(withdrawal.requestedAt))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    statusBadge
                }
                
                // Show rejection reason if rejected
                if withdrawal.status == "rejected", let reason = withdrawal.rejectionReason {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                        
                        Text(reason)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.red.opacity(0.9))
                            .lineLimit(2)
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(16)
            
            if !isLast {
                Divider()
                    .background(Color.white.opacity(0.2))
            }
        }
    }
    
    @ViewBuilder
    var statusBadge: some View {
        switch withdrawal.status {
        case "pending":
            HStack(spacing: 6) {
                Text("Pending")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange)
            .cornerRadius(200)
            
        case "completed":
            HStack(spacing: 6) {
                Text("Completed")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: "#00AA00"))
            .cornerRadius(200)
            
        case "rejected":
            HStack(spacing: 6) {
                Text("Rejected")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.red)
            .cornerRadius(200)
            
        default:
            EmptyView()
        }
    }
    
    func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
