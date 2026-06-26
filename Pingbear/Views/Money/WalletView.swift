import SwiftUI
import FirebaseFirestore

// ─────────────────────────────────────────────────────────────
// MARK: - WalletView
// ─────────────────────────────────────────────────────────────

struct WalletView: View {

    @StateObject private var viewModel = WalletViewModel()
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        if let onDismiss {
                            Button(action: onDismiss) {
                                Image(systemName: "arrow.left")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(AppTheme.iconColor)
                            }
                        } else {
                            Color.clear.frame(width: 30, height: 30)
                        }
                        Spacer()
                        Text("Wallet")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.primaryText)
                            .onAppear { Analytics.shared.trackScreen(name: "wallet_view") }
                        Spacer()
                        Color.clear.frame(width: 30, height: 30)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)

                    if viewModel.isLoading {
                        Spacer()
                        ProgressView().tint(AppTheme.primaryText)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 20) {
                                BalanceCard(viewModel: viewModel)
                                if !viewModel.transactions.isEmpty {
                                    ActivitySection(transactions: viewModel.transactions)
                                }
                            }
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .onAppear { viewModel.startListening() }
            .onDisappear { viewModel.stopListening() }
            .sheet(isPresented: $viewModel.showTopUpSheet) { TopUpSheet() }
            .sheet(isPresented: $viewModel.showCashOutSheet) {
                CashOutSheet(
                    withdrawableBalance: viewModel.withdrawableBalance,
                    onCashOut: { email, amount in
                        Task {
                            let success = await viewModel.requestWithdrawal(amount: amount, paypalEmail: email)
                            if success { viewModel.showCashOutSheet = false }
                        }
                    }
                )
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - BalanceCard
// ─────────────────────────────────────────────────────────────

struct BalanceCard: View {

    @ObservedObject var viewModel: WalletViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Available Balance")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.secondaryText)

            Text("$\(String(format: "%.2f", viewModel.balance))")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(AppTheme.primaryText)

            if viewModel.bonusBalance > 0 {
                Text("Includes $\(String(format: "%.2f", viewModel.bonusBalance)) bonus credit — spendable, not withdrawable")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.showTopUpSheet = true
                    Analytics.shared.trackTap(elementId: "top_up_sheet_open", screenName: "wallet_view")
                } label: {
                    Text("Top Up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.green)
                        .cornerRadius(200)
                }

                Button {
                    if viewModel.canCashOut {
                        viewModel.showCashOutSheet = true
                        Analytics.shared.trackTap(elementId: "cash_out_sheet_open", screenName: "wallet_view")
                    }
                } label: {
                    Text("Cash Out")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(viewModel.canCashOut ? AppTheme.secondaryText : AppTheme.disabledText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(viewModel.canCashOut ? AppTheme.cardBackground : AppTheme.disabledBackground)
                        .cornerRadius(200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 200)
                                .stroke(viewModel.canCashOut ? AppTheme.secondaryText.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                }
                .disabled(!viewModel.canCashOut)
            }

            if !viewModel.canCashOut {
                if viewModel.bonusBalance > 0 && viewModel.balance >= 1.00 {
                    // They have $5+ total but it's locked up as bonus credit —
                    // "minimum is $5" would be misleading here since adding
                    // $0.01 more bonus still wouldn't unlock cash out.
                } else if viewModel.balance > 0 {
                    Text("Minimum cash out is $5.00")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.secondaryText)
                        .padding(.top, 4)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - ActivitySection
// ─────────────────────────────────────────────────────────────

struct ActivitySection: View {

    let transactions: [EnrichedTransaction]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.primaryText)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(transactions.enumerated()), id: \.element.id) { index, tx in
                    ActivityRow(transaction: tx)
                    if index < transactions.count - 1 {
                        Divider().background(AppTheme.divider)
                    }
                }
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - ActivityRow
// ─────────────────────────────────────────────────────────────

struct ActivityRow: View {

    let transaction: EnrichedTransaction

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconBackground)
                        .frame(width: 44, height: 44)
                    Image(systemName: iconName)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }
                .padding(.leading, 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(transaction.type == "credit" ? "+" : "-")$\(String(format: "%.2f", transaction.amount))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(transaction.type == "credit" ? AppTheme.green : AppTheme.primaryText)

                    if transaction.reason == "withdrawal_request",
                       let status = transaction.withdrawalStatus {
                        withdrawalBadge(status)
                    }
                }
                .padding(.trailing, 16)
            }
            .padding(.vertical, 16)

            if transaction.reason == "withdrawal_request",
               transaction.withdrawalStatus == "rejected",
               let reason = transaction.withdrawalRejectionReason {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    Text(reason)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.red.opacity(0.9))
                        .lineLimit(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder
    private func withdrawalBadge(_ status: String) -> some View {
        switch status {
        case "pending":
            Text("Pending")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.orange).cornerRadius(200)
        case "completed":
            Text("Sent")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(AppTheme.green).cornerRadius(200)
        case "rejected":
            Text("Rejected")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.red).cornerRadius(200)
        default:
            EmptyView()
        }
    }

    // Reward payouts (creator_payout) are shared by both request
    // fulfillment and offer unlocks — branch on the content
    // transaction's type (stashed in wallet tx metadata) so the
    // two don't show the same generic label.
    private var title: String {
        switch transaction.reason {
        case "top_up":              return "Top Up"
        case "request_escrow":      return "Request Sent"
        case "offer_escrow":        return "Offer Unlocked"
        case "creator_payout":
            return transaction.contentTransactionType == "offer"
                ? "Offer Payment"
                : "Request Reward"
        case "escrow_refund":       return "Refund"
        case "withdrawal_request":  return "Withdrawal"
        case "withdrawal_rejected": return "Withdrawal Returned"
        case "promo_credit":        return "Bonus Credit"
        case "welcome_bonus":       return "Welcome Bonus"
        default:
            return transaction.reason
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    private var subtitle: String {
        let formatter        = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        let dateStr          = formatter.string(from: transaction.createdAt)
        if let email = transaction.paypalEmail, transaction.reason == "withdrawal_request" {
            return "\(dateStr) · \(email)"
        }
        return dateStr
    }

    private var iconName: String {
        switch transaction.reason {
        case "top_up":              return "plus.circle.fill"
        case "request_escrow":      return "arrow.right.circle.fill"
        case "offer_escrow":        return "lock.open.fill"
        case "creator_payout":      return "trophy.fill"
        case "escrow_refund":       return "arrow.counterclockwise.circle.fill"
        case "withdrawal_request":  return "arrow.up.circle.fill"
        case "withdrawal_rejected": return "arrow.down.circle.fill"
        case "promo_credit":        return "gift.fill"
        case "welcome_bonus":       return "gift.fill"
        default:                    return "dollarsign"
        }
    }

    private var iconColor: Color {
        switch transaction.reason {
        case "top_up":              return AppTheme.green
        case "request_escrow":      return AppTheme.secondaryText
        case "offer_escrow":        return AppTheme.accent
        case "creator_payout":      return AppTheme.green
        case "escrow_refund":       return .orange
        case "withdrawal_request":  return AppTheme.secondaryText
        case "withdrawal_rejected": return AppTheme.green
        case "promo_credit":        return AppTheme.green
        case "welcome_bonus":       return AppTheme.green
        default:                    return AppTheme.secondaryText
        }
    }

    private var iconBackground: Color {
        switch transaction.reason {
        case "top_up":              return AppTheme.green.opacity(0.12)
        case "request_escrow":      return AppTheme.secondaryText.opacity(0.12)
        case "offer_escrow":        return AppTheme.accent.opacity(0.12)
        case "creator_payout":      return AppTheme.green.opacity(0.12)
        case "escrow_refund":       return Color.orange.opacity(0.12)
        case "withdrawal_request":  return AppTheme.cardHighlight
        case "withdrawal_rejected": return AppTheme.green.opacity(0.12)
        case "promo_credit":        return AppTheme.green.opacity(0.12)
        case "welcome_bonus":       return AppTheme.green.opacity(0.12)
        default:                    return AppTheme.cardHighlight
        }
    }
}
