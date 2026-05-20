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
    let withdrawalStatus: String?         // "pending" | "completed" | "rejected"
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

    // Staking progress
    // total_locked_credits — amount user must stake in rounds to unlock withdrawal
    // total_round_staked   — cumulative entry fees from completed rounds
    @Published var totalLockedCredits: Double = 0.0
    @Published var totalRoundStaked: Double = 0.0

    @Published var showTopUpSheet = false
    @Published var showCashOutSheet = false

    private let db = Firestore.firestore()
    private var balanceListener: ListenerRegistration?

    // ── Computed ──────────────────────────────────────────────

    /// Amount the user can withdraw right now.
    /// If bonus is still locked, only the outstanding locked amount
    /// (what they still need to stake) is held back — not the full
    /// total_locked_credits, which can exceed balance once they've
    /// been playing for a while.
    var maxWithdrawable: Double {
        let bonusLocked = bonusCredited && !bonusUnlocked
        guard bonusLocked else { return balance }
        let outstanding = max(0, totalLockedCredits - totalRoundStaked)
        let effectiveLocked = min(outstanding, balance)
        return max(0, balance - effectiveLocked)
    }

    /// Progress toward staking threshold (0.0 – 1.0).
    var stakingProgress: Double {
        guard totalLockedCredits > 0 else { return 1.0 }
        return min(totalRoundStaked / totalLockedCredits, 1.0)
    }

    /// How much more the user needs to stake to unlock.
    var stakingRemaining: Double {
        max(totalLockedCredits - totalRoundStaked, 0)
    }

    // ── Start real-time balance listener ──────────────────────

    func startListening() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isLoading = true

        balanceListener = db.collection("users").document(userId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let data = snapshot?.data()

                self.balance             = data?["wallet_balance"]        as? Double ?? 0.0
                self.bonusCredited       = data?["bonus_credited"]        as? Bool   ?? false
                self.totalLockedCredits  = data?["total_locked_credits"]  as? Double ?? 0.0
                self.totalRoundStaked    = data?["total_round_staked"]    as? Double ?? 0.0

                let unlocked             = data?["welcome_bonus_unlocked"] as? Bool ?? true
                self.bonusUnlocked       = self.bonusCredited ? unlocked : true
            }

        Task { await loadTransactions() }
    }

    func stopListening() {
        balanceListener?.remove()
        balanceListener = nil
    }

    // ── Load enriched transactions ────────────────────────────

    func loadTransactions() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            let snapshot = try await db.collection("wallet_transactions")
                .whereField("user_id", isEqualTo: userId)
                .order(by: "created_at", descending: true)
                .getDocuments()

            let raw: [(tx: [String: Any], id: String)] = snapshot.documents.map {
                ($0.data(), $0.documentID)
            }

            // Collect competition IDs for name lookup
            let competitionIds = Set(raw.compactMap {
                $0.tx["competition_id"] as? String
            })

            // Collect withdrawal IDs for status lookup
            let withdrawalIds = raw.compactMap { item -> String? in
                let reason = item.tx["reason"] as? String
                guard reason == "withdrawal_request" else { return nil }
                return (item.tx["metadata"] as? [String: Any])?["withdrawal_id"] as? String
            }

            // Batch fetch competition names
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

            // Fetch withdrawal statuses
            var withdrawalMap: [String: [String: Any]] = [:]
            for wid in withdrawalIds {
                let wDoc = try await db.collection("withdrawals").document(wid).getDocument()
                if let data = wDoc.data() {
                    withdrawalMap[wid] = data
                }
            }

            // Build enriched transactions
            let enriched: [EnrichedTransaction] = raw.compactMap { item in
                let tx = item.tx
                guard
                    let type      = tx["type"]      as? String,
                    let amount    = tx["amount"]    as? Double,
                    let reason    = tx["reason"]    as? String,
                    let createdAt = (tx["created_at"] as? Timestamp)?.dateValue()
                else { return nil }

                let competitionId   = tx["competition_id"] as? String
                let competitionName = competitionId.flatMap { nameMap[$0] }
                let metadata        = tx["metadata"] as? [String: Any]
                let withdrawalId    = metadata?["withdrawal_id"] as? String
                let withdrawalData  = withdrawalId.flatMap { withdrawalMap[$0] }

                return EnrichedTransaction(
                    id:                        item.id,
                    type:                      type,
                    amount:                    amount,
                    reason:                    reason,
                    competitionId:             competitionId,
                    competitionName:           competitionName,
                    balanceBefore:             tx["balance_before"] as? Double ?? 0,
                    balanceAfter:              tx["balance_after"]  as? Double ?? 0,
                    createdAt:                 createdAt,
                    withdrawalStatus:          withdrawalData?["status"]           as? String,
                    withdrawalRejectionReason: withdrawalData?["rejection_reason"] as? String,
                    paypalEmail:               withdrawalData?["paypal_email"]     as? String
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
