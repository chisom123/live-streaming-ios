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

                    // ── Header ────────────────────────────────
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
                            .onAppear {
                                Analytics.shared.trackScreen(name: "wallet_view")
                            }

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

                                // ── Balance card ──────────────
                                BalanceCard(viewModel: viewModel)

                                // ── Activity ──────────────────
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
            .sheet(isPresented: $viewModel.showTopUpSheet) {
                TopUpSheet()
            }
            .sheet(isPresented: $viewModel.showCashOutSheet) {
                CashOutSheet(
                    balance:            viewModel.balance,
                    maxWithdrawable:    viewModel.maxWithdrawable,
                    bonusCredited:      viewModel.bonusCredited,
                    bonusUnlocked:      viewModel.bonusUnlocked,
                    totalLockedCredits: viewModel.totalLockedCredits,
                    stakingRemaining:   viewModel.stakingRemaining,
                    onCashOut: { email, amount in
                        Task {
                            let success = await viewModel.requestWithdrawal(
                                amount: amount,
                                paypalEmail: email
                            )
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

            // ── Action buttons ────────────────────────────────
            HStack(spacing: 12) {
                Button {
                    viewModel.showTopUpSheet = true
                    Analytics.shared.trackTap(
                        elementId: "top_up_sheet_open",
                        screenName: "wallet_view"
                    )
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
                    if canCashOut { viewModel.showCashOutSheet = true }
                    Analytics.shared.trackTap(
                        elementId: "cash_out_sheet_open",
                        screenName: "wallet_view"
                    )
                } label: {
                    Text("Cash Out")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(canCashOut ? .white : AppTheme.disabledText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canCashOut ? AppTheme.accent : AppTheme.disabledBackground)
                        .cornerRadius(200)
                }
                .disabled(!canCashOut)
            }

            // ── Hint text ─────────────────────────────────────
            if viewModel.bonusCredited && !viewModel.bonusUnlocked {
                Text("Enter $\(String(format: "%.2f", viewModel.stakingRemaining)) more into competition rounds to unlock your bonus")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top)
            } else if viewModel.maxWithdrawable > 0 && viewModel.maxWithdrawable < 5.0 {
                Text("Minimum cash out is $5.00")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.secondaryText)
                    .padding(.top)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var canCashOut: Bool {
        viewModel.maxWithdrawable >= 5.00
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
                        Divider()
                            .background(AppTheme.divider)
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

                // ── Icon ──────────────────────────────────────
                ZStack {
                    Circle()
                        .fill(iconBackground)
                        .frame(width: 44, height: 44)
                    Image(systemName: iconName)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }
                .padding(.leading, 16)

                // ── Title + subtitle ──────────────────────────
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

                // ── Amount + withdrawal status ─────────────────
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

    // ── Withdrawal status badge ───────────────────────────────

    @ViewBuilder
    private func withdrawalBadge(_ status: String) -> some View {
        switch status {
        case "pending":
            Text("Pending")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange)
                .cornerRadius(200)
        case "completed":
            Text("Sent")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppTheme.green)
                .cornerRadius(200)
        case "rejected":
            Text("Rejected")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.red)
                .cornerRadius(200)
        default:
            EmptyView()
        }
    }

    // ── Title ─────────────────────────────────────────────────

    private var title: String {
        switch transaction.reason {
        case "top_up":               return "Top Up"
        case "simulated_top_up":     return "Top Up (Test)"
        case "round_win":            return "Round Win"
        case "round_entry_fee":      return "Round Entry"
        case "round_entry_refund":   return "Round Refund"
        case "withdrawal_request":   return "Withdrawal"
        case "withdrawal_rejected":  return "Withdrawal Returned"
        case "welcome_bonus":        return "Welcome Bonus"
        case "promo_credit":         return "Bonus Credit"
        default:
            return transaction.reason
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    // ── Subtitle ──────────────────────────────────────────────

    private var subtitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        let dateStr = formatter.string(from: transaction.createdAt)

        if let email = transaction.paypalEmail, transaction.reason == "withdrawal_request" {
            return "\(dateStr) · \(email)"
        }

        if let name = transaction.competitionName,
           !name.isEmpty, name != "Competition" {
            return "\(dateStr) · \(name)"
        }

        return dateStr
    }

    // ── Icon name ─────────────────────────────────────────────

    private var iconName: String {
        switch transaction.reason {
        case "top_up", "simulated_top_up": return "plus.circle.fill"
        case "round_win":                  return "trophy.fill"
        case "round_entry_fee":            return "arrow.right.circle.fill"
        case "practice_round_win":                  return "trophy.fill"
        case "practice_round_entry":            return "arrow.right.circle.fill"
        case "round_entry_refund":         return "arrow.counterclockwise.circle.fill"
        case "withdrawal_request":         return "arrow.up.circle.fill"
        case "withdrawal_rejected":        return "arrow.down.circle.fill"
        case "welcome_bonus":              return "gift.fill"
        case "promo_credit":               return "gift.fill"
        default:                           return "dollarsign"
        }
    }

    // ── Icon colour ───────────────────────────────────────────

    private var iconColor: Color {
        switch transaction.reason {
        case "top_up", "simulated_top_up": return AppTheme.green
        case "round_win":                  return AppTheme.gold
        case "round_entry_fee":            return AppTheme.secondaryText
        case "practice_round_win":                  return AppTheme.gold
        case "practice_round_entry":            return AppTheme.secondaryText
        case "round_entry_refund":         return .orange
        case "withdrawal_request":         return AppTheme.secondaryText
        case "withdrawal_rejected":        return AppTheme.green
        case "welcome_bonus":              return AppTheme.green
        case "promo_credit":               return AppTheme.green
        default:                           return AppTheme.secondaryText
        }
    }

    // ── Icon background ───────────────────────────────────────

    private var iconBackground: Color {
        switch transaction.reason {
        case "top_up", "simulated_top_up": return AppTheme.green.opacity(0.12)
        case "round_win":                  return AppTheme.gold.opacity(0.12)
        case "round_entry_fee":            return AppTheme.cardHighlight
        case "practice_round_win":                  return AppTheme.gold.opacity(0.12)
        case "practice_round_entry":            return AppTheme.cardHighlight
        case "round_entry_refund":         return Color.orange.opacity(0.12)
        case "withdrawal_request":         return AppTheme.cardHighlight
        case "withdrawal_rejected":        return AppTheme.green.opacity(0.12)
        case "welcome_bonus":              return AppTheme.green.opacity(0.12)
        case "promo_credit":               return AppTheme.green.opacity(0.12)
        default:                           return AppTheme.cardHighlight
        }
    }
}
