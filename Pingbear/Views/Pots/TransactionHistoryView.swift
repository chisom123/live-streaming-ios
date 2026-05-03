import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// ─────────────────────────────────────────────────────────────
// MARK: - Model
// ─────────────────────────────────────────────────────────────

struct WalletTransaction: Identifiable {
    let id: String
    let type: String            // "credit" | "debit"
    let amount: Double
    let reason: String          // "top_up" | "race_win" | "race_contribution" | "race_refund" | "withdrawal_request" | "withdrawal_rejected" | "simulated_top_up"
    let competitionId: String?
    let competitionName: String?
    let balanceBefore: Double
    let balanceAfter: Double
    let createdAt: Date
}

// ─────────────────────────────────────────────────────────────
// MARK: - TransactionHistoryViewModel
// ─────────────────────────────────────────────────────────────

@MainActor
class TransactionHistoryViewModel: ObservableObject {

    @Published var transactions: [WalletTransaction] = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()

    func load() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isLoading = true

        db.collection("wallet_transactions")
            .whereField("user_id", isEqualTo: userId)
            .order(by: "created_at", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    self.isLoading = false
                    return
                }

                // Parse raw transactions
                var raw: [WalletTransaction] = documents.compactMap { doc in
                    let data = doc.data()
                    guard
                        let type      = data["type"] as? String,
                        let amount    = data["amount"] as? Double,
                        let reason    = data["reason"] as? String,
                        let createdAt = (data["created_at"] as? Timestamp)?.dateValue()
                    else { return nil }

                    return WalletTransaction(
                        id:               doc.documentID,
                        type:             type,
                        amount:           amount,
                        reason:           reason,
                        competitionId:    data["competition_id"] as? String,
                        competitionName:  nil, // fetched below
                        balanceBefore:    data["balance_before"] as? Double ?? 0,
                        balanceAfter:     data["balance_after"] as? Double ?? 0,
                        createdAt:        createdAt
                    )
                }

                // Collect unique competition IDs that need name lookups
                let competitionIds = Set(raw.compactMap { $0.competitionId })

                guard !competitionIds.isEmpty else {
                    self.transactions = raw
                    self.isLoading = false
                    return
                }

                // Batch fetch competition names
                self.fetchCompetitionNames(ids: Array(competitionIds)) { nameMap in
                    self.transactions = raw.map { tx in
                        guard let compId = tx.competitionId,
                              let name = nameMap[compId] else { return tx }
                        return WalletTransaction(
                            id:              tx.id,
                            type:            tx.type,
                            amount:          tx.amount,
                            reason:          tx.reason,
                            competitionId:   tx.competitionId,
                            competitionName: name,
                            balanceBefore:   tx.balanceBefore,
                            balanceAfter:    tx.balanceAfter,
                            createdAt:       tx.createdAt
                        )
                    }
                    self.isLoading = false
                }
            }
    }

    private func fetchCompetitionNames(ids: [String], completion: @escaping ([String: String]) -> Void) {
        // Firestore whereIn supports up to 30 items
        let chunks = stride(from: 0, to: ids.count, by: 30).map {
            Array(ids[$0..<min($0 + 30, ids.count)])
        }

        var nameMap: [String: String] = [:]
        let group = DispatchGroup()

        for chunk in chunks {
            group.enter()
            db.collection("competitions")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments { snapshot, _ in
                    snapshot?.documents.forEach { doc in
                        let name = doc.data()["description"] as? String ?? "Competition"
                        nameMap[doc.documentID] = name
                    }
                    group.leave()
                }
        }

        group.notify(queue: .main) { completion(nameMap) }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - TransactionHistoryView
// ─────────────────────────────────────────────────────────────

struct TransactionHistoryView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TransactionHistoryViewModel()

    var body: some View {
        ZStack {
            Color(hex: "#10183C").ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text("Transaction History")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Color.clear.frame(width: 27, height: 27)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                } else if viewModel.transactions.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.3))

                        Text("No transactions yet")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))

                        Text("Your wallet activity will appear here.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.transactions.enumerated()), id: \.element.id) { index, tx in
                                TransactionRow(transaction: tx)

                                if index < viewModel.transactions.count - 1 {
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                        .padding(.leading, 68)
                                }
                            }
                        }
                        .background(Color(hex: "#1A2245"))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { viewModel.load() }
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

// ─────────────────────────────────────────────────────────────
// MARK: - TransactionRow
// ─────────────────────────────────────────────────────────────

private struct TransactionRow: View {

    let transaction: WalletTransaction

    var body: some View {
        HStack(spacing: 16) {

            // ── Icon ──────────────────────────────────────────
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 44, height: 44)

                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }
            .padding(.leading, 16)

            // ── Title + subtitle ──────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            // ── Amount ────────────────────────────────────────
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(transaction.type == "credit" ? "+" : "-")$\(String(format: "%.2f", transaction.amount))")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(transaction.type == "credit" ? Color(hex: "#00AA00") : .white)

                Text("$\(String(format: "%.2f", transaction.balanceAfter))")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 16)
    }

    // ── Title per reason ──────────────────────────────────────

    private var title: String {
        switch transaction.reason {
        case "top_up":                return "Top Up"
        case "simulated_top_up":      return "Top Up (Test)"
        case "race_win":              return "Race Win"
        case "race_contribution":     return "Race Contribution"
        case "race_refund":           return "Race Refund"
        case "withdrawal_request":    return "Withdrawal"
        case "withdrawal_rejected":   return "Withdrawal Returned"
        case "welcome_bonus":         return "Welcome Bonus"
        default:                      return transaction.reason.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    // ── Subtitle — date + competition name if available ───────

    private var subtitle: String {
        let dateStr = dateString(transaction.createdAt)
        if let name = transaction.competitionName, !name.isEmpty, name != "Competition" {
            return "\(dateStr) · \(name)"
        }
        return dateStr
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    // ── Icon per reason ───────────────────────────────────────

    private var iconName: String {
        switch transaction.reason {
        case "top_up", "simulated_top_up": return "plus.circle.fill"
        case "race_win":                   return "trophy.fill"
        case "race_contribution":          return "dollarsign.circle.fill"
        case "race_refund":                return "arrow.counterclockwise.circle.fill"
        case "withdrawal_request":         return "arrow.up.circle.fill"
        case "withdrawal_rejected":        return "arrow.down.circle.fill"
        case "welcome_bonus":              return "gift.fill"
        default:                           return "dollarsign.circle.fill"
        }
    }

    private var iconColor: Color {
        switch transaction.reason {
        case "top_up", "simulated_top_up": return Color(hex: "#4169E1")
        case "race_win":                   return Color(hex: "#FFD700")
        case "race_contribution":          return .white
        case "race_refund":                return .orange
        case "withdrawal_request":         return .white
        case "withdrawal_rejected":        return Color(hex: "#00AA00")
        case "welcome_bonus":              return Color(hex: "#FF69B4")
        default:                           return .white
        }
    }

    private var iconBackground: Color {
        switch transaction.reason {
        case "top_up", "simulated_top_up": return Color(hex: "#4169E1").opacity(0.15)
        case "race_win":                   return Color(hex: "#FFD700").opacity(0.15)
        case "race_contribution":          return Color.white.opacity(0.08)
        case "race_refund":                return Color.orange.opacity(0.15)
        case "withdrawal_request":         return Color.white.opacity(0.08)
        case "withdrawal_rejected":        return Color(hex: "#00AA00").opacity(0.15)
        case "welcome_bonus":              return Color(hex: "#FF69B4").opacity(0.15)
        default:                           return Color.white.opacity(0.08)
        }
    }
}
