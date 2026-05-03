import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

// ─────────────────────────────────────────────────────────────
// MARK: - Model
// ─────────────────────────────────────────────────────────────

struct RaceContributor: Identifiable {
    let id       = UUID()
    let userId:   String
    let username: String
    let amount:   Double
}

// ─────────────────────────────────────────────────────────────
// MARK: - ContributeViewModel
// ─────────────────────────────────────────────────────────────

@MainActor
class ContributeViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var contributors: [RaceContributor] = []
    @Published var walletBalance: Double = 0.0
    @Published var isLoadingBalance = true

    let quickAmounts: [Double] = [1, 5, 10, 20]

    private let db = Firestore.firestore()
    private var balanceListener: ListenerRegistration?

    // ── Load wallet balance ───────────────────────────────────
    // Starts a real-time listener so the balance shown in the
    // sheet is always accurate. Stops when sheet dismisses.

    func startBalanceListener() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isLoadingBalance = true

        balanceListener = db.collection("users").document(userId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                self.walletBalance = snapshot?.data()?["wallet_balance"] as? Double ?? 0.0
                self.isLoadingBalance = false
            }
    }

    func stopBalanceListener() {
        balanceListener?.remove()
        balanceListener = nil
    }

    // ── Contribute to race pot ────────────────────────────────
    // Calls contributeToRace Cloud Function which deducts from
    // wallet and adds to race total_pot atomically.
    // The server always does the final balance check —
    // client-side check is just for UX.

    func contribute(competitionId: String, amount: Double) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            _ = try await Functions.functions()
                .httpsCallable("contributeToRace")
                .call(["competitionId": competitionId, "amount": amount])
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // ── Can afford a given amount ─────────────────────────────
    // Client-side check for UI only. Server is the real gatekeeper.

    func canAfford(_ amount: Double) -> Bool {
        walletBalance >= amount
    }

    // ── Load contributors ─────────────────────────────────────

    func loadContributors(raceId: String) {
        db.collection("competition_races")
            .document(raceId)
            .collection("contributions")
            .order(by: "contributed_at", descending: false)
            .getDocuments { [weak self] snapshot, _ in
                guard let self else { return }

                var totals: [String: Double] = [:]
                snapshot?.documents.forEach { doc in
                    let data = doc.data()
                    let userId = data["user_id"] as? String ?? ""
                    let amount = data["amount"] as? Double ?? 0
                    totals[userId] = (totals[userId] ?? 0) + amount
                }

                guard !totals.isEmpty else {
                    self.contributors = []
                    return
                }

                let group = DispatchGroup()
                var result: [RaceContributor] = []
                let currentUserId = Auth.auth().currentUser?.uid

                for (userId, total) in totals {
                    group.enter()
                    self.db.collection("users").document(userId).getDocument { doc, _ in
                        let name = doc?.data()?["name"] as? String ?? "Unknown"
                        result.append(RaceContributor(
                            userId:   userId,
                            username: userId == currentUserId ? "Me" : name,
                            amount:   total
                        ))
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    self.contributors = result.sorted { $0.amount > $1.amount }
                }
            }
    }
}
