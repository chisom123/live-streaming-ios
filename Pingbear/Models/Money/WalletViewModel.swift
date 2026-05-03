import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

// ─────────────────────────────────────────────────────────────
// MARK: - EnrichedTransaction
//
// A wallet transaction enriched with withdrawal status if applicable
// ─────────────────────────────────────────────────────────────

struct EnrichedTransaction: Identifiable {
    let id: String
    let type: String
    let amount: Double
    let reason: String
    let competitionId: String?
    let competitionName: String?
    let balanceBefore: Double
    let balanceAfter: Double
    let createdAt: Date

    // Only set for withdrawal_request transactions
    let withdrawalStatus: String?       // "pending" | "completed" | "rejected"
    let withdrawalRejectionReason: String?
    let paypalEmail: String?
}

// ─────────────────────────────────────────────────────────────
// MARK: - WalletViewModel
// ─────────────────────────────────────────────────────────────

@MainActor
class WalletViewModel: ObservableObject {

    @Published var balance: Double = 0.0
    @Published var transactions: [EnrichedTransaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    // Bonus unlock state
    @Published var bonusCredited: Bool = false
    @Published var bonusUnlocked: Bool = true
    @Published var hasEarnedStars: Bool = false
    @Published var totalContributed: Double = 0.0

    @Published var showTopUpSheet = false
    @Published var showCashOutSheet = false

    private let db = Firestore.firestore()
    private var balanceListener: ListenerRegistration?
    
    var maxWithdrawable: Double {
        let bonusLocked = bonusCredited && !bonusUnlocked
        return bonusLocked ? max(0, balance - 5.00) : balance
    }

    // ── Start real-time balance listener ──────────────────────

    func startListening() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isLoading = true

        balanceListener = db.collection("users").document(userId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let data = snapshot?.data()

                self.balance          = data?["wallet_balance"] as? Double ?? 0.0
                self.bonusCredited    = data?["bonus_credited"] as? Bool ?? false
                self.hasEarnedStars   = data?["has_earned_stars"] as? Bool ?? false
                self.totalContributed = data?["total_contributed"] as? Double ?? 0.0

                let unlocked = data?["welcome_bonus_unlocked"] as? Bool ?? true
                self.bonusUnlocked = self.bonusCredited ? unlocked : true
            }

        Task { await loadTransactions() }
    }

    func stopListening() {
        balanceListener?.remove()
        balanceListener = nil
    }

    // ── Bonus progress ────────────────────────────────────────

    var contributionProgress: Double { min(totalContributed / 5.0, 1.0) }
    var contributionRemaining: Double { max(5.0 - totalContributed, 0) }

    // ── Load enriched transactions ────────────────────────────

    func loadTransactions() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            // 1. Load all transactions
            let snapshot = try await db.collection("wallet_transactions")
                .whereField("user_id", isEqualTo: userId)
                .order(by: "created_at", descending: true)
                .getDocuments()

            var raw: [(tx: [String: Any], id: String)] = snapshot.documents.map {
                ($0.data(), $0.documentID)
            }

            // 2. Collect competition IDs for name lookup
            let competitionIds = Set(raw.compactMap {
                $0.tx["competition_id"] as? String
            })

            // 3. Collect withdrawal IDs for status lookup
            let withdrawalIds = raw.compactMap { item -> String? in
                let reason = item.tx["reason"] as? String
                guard reason == "withdrawal_request" else { return nil }
                return (item.tx["metadata"] as? [String: Any])?["withdrawal_id"] as? String
            }

            // 4. Batch fetch competition names
            var nameMap: [String: String] = [:]
            if !competitionIds.isEmpty {
                let chunks = stride(from: 0, to: competitionIds.count, by: 10).map {
                    Array(competitionIds)[$0..<min($0 + 10, competitionIds.count)]
                }
                for chunk in chunks {
                    let compSnap = try await db.collection("competitions")
                        .whereField(FieldPath.documentID(), in: Array(chunk))
                        .getDocuments()
                    compSnap.documents.forEach { doc in
                        nameMap[doc.documentID] = doc.data()["description"] as? String ?? "Competition"
                    }
                }
            }

            // 5. Fetch withdrawal statuses
            var withdrawalMap: [String: [String: Any]] = [:]
            for wid in withdrawalIds {
                let wDoc = try await db.collection("withdrawals").document(wid).getDocument()
                if let data = wDoc.data() {
                    withdrawalMap[wid] = data
                }
            }

            // 6. Build enriched transactions
            let enriched: [EnrichedTransaction] = raw.compactMap { item in
                let tx = item.tx
                guard
                    let type      = tx["type"] as? String,
                    let amount    = tx["amount"] as? Double,
                    let reason    = tx["reason"] as? String,
                    let createdAt = (tx["created_at"] as? Timestamp)?.dateValue()
                else { return nil }

                let competitionId = tx["competition_id"] as? String
                let competitionName = competitionId.flatMap { nameMap[$0] }
                let metadata = tx["metadata"] as? [String: Any]
                let withdrawalId = metadata?["withdrawal_id"] as? String
                let withdrawalData = withdrawalId.flatMap { withdrawalMap[$0] }

                return EnrichedTransaction(
                    id:                        item.id,
                    type:                      type,
                    amount:                    amount,
                    reason:                    reason,
                    competitionId:             competitionId,
                    competitionName:           competitionName,
                    balanceBefore:             tx["balance_before"] as? Double ?? 0,
                    balanceAfter:              tx["balance_after"] as? Double ?? 0,
                    createdAt:                 createdAt,
                    withdrawalStatus:          withdrawalData?["status"] as? String,
                    withdrawalRejectionReason: withdrawalData?["rejection_reason"] as? String,
                    paypalEmail:               withdrawalData?["paypal_email"] as? String
                )
            }

            transactions = enriched
            isLoading = false

        } catch {
            errorMessage = "Failed to load activity"
            isLoading = false
        }
    }

    // ── Request withdrawal ────────────────────────────────────

    func requestWithdrawal(amount: Double, paypalEmail: String) async -> Bool {
        do {
            _ = try await Functions.functions()
                .httpsCallable("requestWithdrawal")
                .call(["amount": amount, "paypalEmail": paypalEmail])
            await loadTransactions()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
