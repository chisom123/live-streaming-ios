import Foundation
import FirebaseFirestore

// ─────────────────────────────────────────────────────────────
// MARK: - TransactionStatus
// ─────────────────────────────────────────────────────────────

enum TransactionStatus: String, Codable {
    case pendingSignup     = "pending_signup"      // toUser not on app yet
    case pendingAcceptance = "pending_acceptance"  // waiting for recipient to accept/decline
    case completed         = "completed"           // payer accepted and paid
    case declined          = "declined"            // recipient declined
}

// ─────────────────────────────────────────────────────────────
// MARK: - ContentTransaction
// ─────────────────────────────────────────────────────────────

struct ContentTransaction: Identifiable {
    let id:               String
    let fromUserId:       String
    var toUserId:         String?
    let price:            Double
    let platformFee:      Double
    let creatorPayout:    Double
    var status:           TransactionStatus
    var photoUrl:         String?
    var rating:           Int?
    let createdAt:        Date
    var acceptedAt:       Date?
    var completedAt:      Date?
    var pendingPhoneHash: String?
    var pendingName:      String?

    // ─────────────────────────────────────────────────────────
    // MARK: - Computed
    // ─────────────────────────────────────────────────────────

    func otherUserId(currentUserId: String) -> String? {
        fromUserId == currentUserId ? toUserId : fromUserId
    }

    /// Creator is always the sender (from_user_id) for offers
    func isCreator(currentUserId: String) -> Bool {
        fromUserId == currentUserId
    }

    func isPayer(currentUserId: String) -> Bool {
        toUserId == currentUserId
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Firestore init
    // ─────────────────────────────────────────────────────────

    init?(id: String, data: [String: Any]) {
        guard
            let fromUserId    = data["from_user_id"] as? String,
            let price         = data["price"] as? Double,
            let platformFee   = data["platform_fee"] as? Double,
            let creatorPayout = data["creator_payout"] as? Double,
            let statusRaw     = data["status"] as? String,
            let status        = TransactionStatus(rawValue: statusRaw),
            let createdAt     = (data["created_at"] as? Timestamp)?.dateValue()
        else { return nil }

        self.id               = id
        self.fromUserId       = fromUserId
        self.toUserId         = data["to_user_id"] as? String
        self.price            = price
        self.platformFee      = platformFee
        self.creatorPayout    = creatorPayout
        self.status           = status
        self.photoUrl         = data["photo_url"] as? String
        self.rating           = data["rating"] as? Int
        self.createdAt        = createdAt
        self.acceptedAt       = (data["accepted_at"] as? Timestamp)?.dateValue()
        self.completedAt      = (data["completed_at"] as? Timestamp)?.dateValue()
        self.pendingPhoneHash = data["pending_phone_hash"] as? String
        self.pendingName      = data["pending_name"] as? String
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - EnrichedContentTransaction
// ─────────────────────────────────────────────────────────────

struct EnrichedContentTransaction: Identifiable {
    let transaction:  ContentTransaction
    let otherProfile: UserProfile?

    var id: String { transaction.id }
}
