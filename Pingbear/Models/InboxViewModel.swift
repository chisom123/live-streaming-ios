import Foundation
import FirebaseAuth
import FirebaseFirestore

// ─────────────────────────────────────────────────────────────
// MARK: - InboxViewModel
//
// Inbox behaves like an email inbox:
// - Transactions stay until the user explicitly dismisses them
// - Active items show highlighted (needs action / in progress)
// - Completed/declined/cancelled show dimmed (recent)
// - Dismissed items are hidden (dismissed_by contains currentUserId)
// ─────────────────────────────────────────────────────────────

@MainActor
final class InboxViewModel: ObservableObject {

    @Published var incoming: [EnrichedContentTransaction] = []
    @Published var outgoing: [EnrichedContentTransaction] = []
    @Published var isLoading    = true
    @Published var errorMessage: String? = nil

    private let db            = Firestore.firestore()
    private let currentUserId = Auth.auth().currentUser?.uid ?? ""
    private var listeners:    [ListenerRegistration] = []
    private var profileCache: [String: UserProfile]  = [:]

    private let incomingStatuses: [String] = [
        TransactionStatus.pendingAcceptance.rawValue,
        TransactionStatus.accepted.rawValue,
        TransactionStatus.fulfilled.rawValue,
        TransactionStatus.completed.rawValue,
        TransactionStatus.declined.rawValue,
        TransactionStatus.cancelled.rawValue
    ]

    private let outgoingStatuses: [String] = [
        TransactionStatus.pendingSignup.rawValue,
        TransactionStatus.pendingAcceptance.rawValue,
        TransactionStatus.accepted.rawValue,
        TransactionStatus.fulfilled.rawValue,
        TransactionStatus.completed.rawValue,
        TransactionStatus.declined.rawValue,
        TransactionStatus.cancelled.rawValue
    ]

    // ─────────────────────────────────────────────────────────
    // MARK: - Lifecycle
    // ─────────────────────────────────────────────────────────

    func start() {
        guard !currentUserId.isEmpty else { return }
        listenIncoming()
        listenOutgoing()
    }

    func stop() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Listeners
    // ─────────────────────────────────────────────────────────

    private func listenIncoming() {
        let ref = db.collection("content_transactions")
            .whereField("to_user_id", isEqualTo: currentUserId)
            .whereField("status", in: incomingStatuses)
            .order(by: "created_at", descending: true)

        let listener = ref.addSnapshotListener { [weak self] (snap: QuerySnapshot?, error: Error?) in
            guard let self else { return }
            if let error { self.errorMessage = error.localizedDescription; return }
            let txs = snap?.documents.compactMap { doc -> ContentTransaction? in
                let data = doc.data()
                let dismissedBy = data["dismissed_by"] as? [String] ?? []
                if dismissedBy.contains(self.currentUserId) { return nil }
                return ContentTransaction(id: doc.documentID, data: data)
            } ?? []
            Task { await self.enrich(txs: txs, into: \.incoming) }
        }
        listeners.append(listener)
    }

    private func listenOutgoing() {
        let ref = db.collection("content_transactions")
            .whereField("from_user_id", isEqualTo: currentUserId)
            .whereField("status", in: outgoingStatuses)
            .order(by: "created_at", descending: true)

        let listener = ref.addSnapshotListener { [weak self] (snap: QuerySnapshot?, error: Error?) in
            guard let self else { return }
            if let error { self.errorMessage = error.localizedDescription; return }
            let txs = snap?.documents.compactMap { doc -> ContentTransaction? in
                let data = doc.data()
                let dismissedBy = data["dismissed_by"] as? [String] ?? []
                if dismissedBy.contains(self.currentUserId) { return nil }
                return ContentTransaction(id: doc.documentID, data: data)
            } ?? []
            Task { await self.enrich(txs: txs, into: \.outgoing) }
        }
        listeners.append(listener)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Enrichment
    //
    // For pending_signup transactions, toUserId is nil so
    // otherUserId() returns nil. In that case we build a
    // placeholder UserProfile from pendingName (the contact name
    // stored at send time). Once the recipient signs up,
    // resolveInviteTransaction sets toUserId → the listener fires
    // → otherUserId() returns a real ID → we fetch their actual
    // profile and the name updates automatically.
    // ─────────────────────────────────────────────────────────

    private func enrich(
        txs: [ContentTransaction],
        into keyPath: ReferenceWritableKeyPath<InboxViewModel, [EnrichedContentTransaction]>
    ) async {
        var enriched: [EnrichedContentTransaction] = []

        for tx in txs {
            guard let otherId = tx.otherUserId(currentUserId: currentUserId) else {
                // pending_signup — no user ID yet, use stored contact name
                let placeholder = tx.pendingName.map { name in
                    UserProfile(
                        id:                "",
                        name:              name,
                        username:          "",
                        profilePictureUrl: nil,
                        totalEarned:       0,
                        averageRating:     0,
                        ratingCount:       0
                    )
                }
                enriched.append(EnrichedContentTransaction(transaction: tx, otherProfile: placeholder))
                continue
            }

            let profile: UserProfile?
            if let cached = profileCache[otherId] {
                profile = cached
            } else {
                let fetched = await fetchProfile(userId: otherId)
                if let fetched { profileCache[otherId] = fetched }
                profile = fetched
            }

            enriched.append(EnrichedContentTransaction(transaction: tx, otherProfile: profile))
        }

        self[keyPath: keyPath] = enriched
        isLoading = false
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Fetch profile
    // ─────────────────────────────────────────────────────────

    private func fetchProfile(userId: String) async -> UserProfile? {
        await withCheckedContinuation { continuation in
            db.collection("users").document(userId).getDocument { snap, _ in
                guard let data = snap?.data() else {
                    continuation.resume(returning: nil); return
                }
                continuation.resume(returning: UserProfile(
                    id:                userId,
                    name:              data["name"] as? String ?? "",
                    username:          data["username"] as? String ?? "",
                    profilePictureUrl: data["profilePictureUrl"] as? String,
                    totalEarned:       data["totalEarned"] as? Double ?? 0,
                    averageRating:     data["averageRating"] as? Double ?? 0,
                    ratingCount:       data["ratingCount"] as? Int ?? 0
                ))
            }
        }
    }
}
