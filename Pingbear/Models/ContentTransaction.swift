import Foundation
import FirebaseFirestore

// ─────────────────────────────────────────────────────────────
// MARK: - TransactionType
// ─────────────────────────────────────────────────────────────

enum TransactionType: String, Codable {
    case request = "request"   // payer asks creator to record a video for them
    case offer   = "offer"     // creator records a mystery video, payer pays to unlock
}

// ─────────────────────────────────────────────────────────────
// MARK: - TransactionStatus
// ─────────────────────────────────────────────────────────────

enum TransactionStatus: String, Codable {
    case pendingSignup     = "pending_signup"      // toUser not on app yet
    case pendingAcceptance = "pending_acceptance"  // waiting for recipient to accept/decline
    case accepted          = "accepted"            // request only — creator accepted, awaiting fulfillment
    case fulfilled         = "fulfilled"           // request only — creator fulfilled, awaiting payer view
    case completed         = "completed"           // fully done — money has moved
    case declined          = "declined"            // recipient declined
    case cancelled         = "cancelled"           // request only — sender cancelled before fulfillment
}

// ─────────────────────────────────────────────────────────────
// MARK: - ContentTransaction
// ─────────────────────────────────────────────────────────────

struct ContentTransaction: Identifiable {
    let id:               String
    let type:             TransactionType
    let fromUserId:       String        // payer
    var toUserId:         String?       // creator
    let price:            Double
    let platformFee:      Double
    let creatorPayout:    Double
    let description:      String        // requests only — what video the payer wants ("" for offers)
    var status:           TransactionStatus
    var photoUrl:         String?       // the video URL (field name kept for backend/Firestore compatibility)
    var rating:           Int?
    let createdAt:        Date
    var acceptedAt:       Date?
    var fulfilledAt:      Date?
    var completedAt:      Date?
    var pendingPhoneHash: String?
    var pendingName:      String?

    // ─────────────────────────────────────────────────────────
    // MARK: - Computed
    // ─────────────────────────────────────────────────────────

    func otherUserId(currentUserId: String) -> String? {
        fromUserId == currentUserId ? toUserId : fromUserId
    }

    /// Request: creator = toUserId (asked to record).
    /// Offer:   creator = fromUserId (recorded and sent the mystery video).
    func isCreator(currentUserId: String) -> Bool {
        switch type {
        case .request: return toUserId == currentUserId
        case .offer:   return fromUserId == currentUserId
        }
    }

    /// The person who pays. Always the opposite of the creator.
    func isPayer(currentUserId: String) -> Bool {
        !isCreator(currentUserId: currentUserId)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Firestore init
    // ─────────────────────────────────────────────────────────

    init?(id: String, data: [String: Any]) {
        guard
            let typeRaw       = data["type"] as? String,
            let type          = TransactionType(rawValue: typeRaw),
            let fromUserId    = data["from_user_id"] as? String,
            let price         = data["price"] as? Double,
            let platformFee   = data["platform_fee"] as? Double,
            let creatorPayout = data["creator_payout"] as? Double,
            let statusRaw     = data["status"] as? String,
            let status        = TransactionStatus(rawValue: statusRaw),
            let createdAt     = (data["created_at"] as? Timestamp)?.dateValue()
        else { return nil }

        self.id               = id
        self.type             = type
        self.fromUserId       = fromUserId
        self.toUserId         = data["to_user_id"] as? String
        self.price            = price
        self.platformFee      = platformFee
        self.creatorPayout    = creatorPayout
        self.description      = data["description"] as? String ?? ""
        self.status           = status
        self.photoUrl         = data["photo_url"] as? String
        self.rating           = data["rating"] as? Int
        self.createdAt        = createdAt
        self.acceptedAt       = (data["accepted_at"] as? Timestamp)?.dateValue()
        self.fulfilledAt      = (data["fulfilled_at"] as? Timestamp)?.dateValue()
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
