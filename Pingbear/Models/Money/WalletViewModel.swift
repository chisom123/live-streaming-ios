import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

// ─────────────────────────────────────────────────────────────
// MARK: - EnrichedTransaction
// ─────────────────────────────────────────────────────────────

struct EnrichedTransaction: Identifiable {
    let id:                        String
    let type:                      String
    let amount:                    Double
    let reason:                    String
    let createdAt:                 Date
    let paypalEmail:               String?
    let withdrawalStatus:          String?
    let withdrawalRejectionReason: String?
    // "request" | "offer" — only present on creator_payout rows, lets
    // the UI distinguish "Reward Received" (request) from "Offer
    // Unlocked" payout (offer) instead of showing one generic label.
    let contentTransactionType:    String?
}

// ─────────────────────────────────────────────────────────────
// MARK: - WalletViewModel
// ─────────────────────────────────────────────────────────────

@MainActor
class WalletViewModel: ObservableObject {

    @Published var balance:       Double               = 0.0
    // Subset of `balance` that's non-withdrawable (welcome bonus,
    // promo credit). Not a separate pot — see bonus_balance docs in
    // walletHelpers.js for the full model.
    @Published var bonusBalance:  Double               = 0.0
    @Published var transactions:  [EnrichedTransaction] = []
    @Published var isLoading      = false
    @Published var errorMessage:  String?              = nil
    @Published var showTopUpSheet  = false
    @Published var showCashOutSheet = false

    private let db             = Firestore.firestore()
    private var balanceListener: ListenerRegistration?

    /// What's actually withdrawable — total balance minus whatever's
    /// still tagged as bonus credit.
    var withdrawableBalance: Double { max(0, balance - bonusBalance) }

    var canCashOut: Bool { withdrawableBalance >= 5.00 }

    // ─────────────────────────────────────────────────────────
    // MARK: - Lifecycle
    // ─────────────────────────────────────────────────────────

    func startListening() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isLoading = true

        balanceListener = db.collection("users").document(userId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                self.balance      = snapshot?.data()?["wallet_balance"] as? Double ?? 0.0
                self.bonusBalance = snapshot?.data()?["bonus_balance"] as? Double ?? 0.0
                self.isLoading    = false
            }

        Task { await loadTransactions() }
    }

    func stopListening() {
        balanceListener?.remove()
        balanceListener = nil
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Load transactions
    // ─────────────────────────────────────────────────────────

    func loadTransactions() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            let snapshot = try await db.collection("wallet_transactions")
                .whereField("user_id", isEqualTo: userId)
                .order(by: "created_at", descending: true)
                .limit(to: 50)
                .getDocuments()

            // Collect withdrawal IDs for status lookup
            let withdrawalIds: [String] = snapshot.documents.compactMap { doc in
                let data   = doc.data()
                let reason = data["reason"] as? String
                guard reason == "withdrawal_request" else { return nil }
                return (data["metadata"] as? [String: Any])?["withdrawal_id"] as? String
            }

            // Fetch withdrawal statuses
            var withdrawalMap: [String: [String: Any]] = [:]
            for wid in withdrawalIds {
                let wDoc = try await db.collection("withdrawals").document(wid).getDocument()
                if let data = wDoc.data() { withdrawalMap[wid] = data }
            }

            transactions = snapshot.documents.compactMap { doc -> EnrichedTransaction? in
                let data = doc.data()
                guard
                    let type      = data["type"]      as? String,
                    let amount    = data["amount"]    as? Double,
                    let reason    = data["reason"]    as? String,
                    let createdAt = (data["created_at"] as? Timestamp)?.dateValue()
                else { return nil }

                let metadata       = data["metadata"] as? [String: Any]
                let withdrawalId   = metadata?["withdrawal_id"] as? String
                let withdrawalData = withdrawalId.flatMap { withdrawalMap[$0] }

                return EnrichedTransaction(
                    id:                        doc.documentID,
                    type:                      type,
                    amount:                    amount,
                    reason:                    reason,
                    createdAt:                 createdAt,
                    paypalEmail:               withdrawalData?["paypal_email"]     as? String,
                    withdrawalStatus:          withdrawalData?["status"]           as? String,
                    withdrawalRejectionReason: withdrawalData?["rejection_reason"] as? String,
                    contentTransactionType:    metadata?["transaction_type"]       as? String
                )
            }

        } catch {
            errorMessage = "Failed to load activity"
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Withdrawal
    // ─────────────────────────────────────────────────────────

    func requestWithdrawal(amount: Double, paypalEmail: String) async -> Bool {
        do {
            try await Functions.functions()
                .httpsCallable("requestWithdrawal")
                .call(["amount": amount, "paypalEmail": paypalEmail])
            Analytics.shared.track(
                event: AnalyticsEvent.walletWithdrawalRequested,
                properties: [AnalyticsProperty.amount: amount]
            )
            await loadTransactions()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
