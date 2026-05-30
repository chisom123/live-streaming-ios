import Foundation
import FirebaseFirestore
import UIKit

// ─────────────────────────────────────────────────────────────
// MARK: - Session
// ─────────────────────────────────────────────────────────────

struct Session: Identifiable {
    let id: String
    let status: SessionStatus
    let createdBy: String
    let participantIds: [String]
    let invitedIds: [String]
    let lastCompletedRoundId: String?
    let createdAt: Date
    let endedAt: Date?

    enum SessionStatus: String {
        case active = "active"
        case ended  = "ended"
    }

    init?(id: String, data: [String: Any]) {
        guard let createdBy = data["created_by"] as? String else { return nil }
        self.id                   = id
        self.createdBy            = createdBy
        self.participantIds       = data["participant_ids"]          as? [String] ?? []
        self.invitedIds           = data["invited_ids"]              as? [String] ?? []
        self.lastCompletedRoundId = data["last_completed_round_id"]  as? String
        self.createdAt            = (data["created_at"] as? Timestamp)?.dateValue() ?? Date()
        self.endedAt              = (data["ended_at"]   as? Timestamp)?.dateValue()
        self.status               = SessionStatus(rawValue: data["status"] as? String ?? "") ?? .active
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Round
// ─────────────────────────────────────────────────────────────

struct Round: Identifiable, Equatable {
    let id: String
    let sessionId: String
    let status: RoundStatus
    let roundNumber: Int
    let totalPot: Double
    let platformFee: Double
    let roundReward: Double
    let winnerIds: [String]
    let participantCount: Int
    let createdBy: String
    let createdAt: Date
    let startedAt: Date?
    let endedAt: Date?

    enum RoundStatus: String {
        case waiting   = "waiting"
        case judging   = "judging"
        case complete  = "complete"
        case failed    = "failed"
        case cancelled = "cancelled"
    }

    var isWaiting:  Bool { status == .waiting }
    var isJudging:  Bool { status == .judging }
    var isComplete: Bool { status == .complete }
    var isActive:   Bool { status == .waiting || status == .judging }

    static func == (lhs: Round, rhs: Round) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status && lhs.participantCount == rhs.participantCount
    }

    init?(id: String, sessionId: String, data: [String: Any]) {
        guard let createdBy = data["created_by"] as? String else { return nil }
        self.id               = id
        self.sessionId        = sessionId
        self.createdBy        = createdBy
        self.roundNumber      = data["round_number"]      as? Int    ?? 1
        self.totalPot         = data["total_pot"]         as? Double ?? 0
        self.platformFee      = data["platform_fee"]      as? Double ?? 0
        self.roundReward      = data["round_reward"]      as? Double ?? 0
        self.winnerIds        = data["winner_ids"]        as? [String] ?? []
        self.participantCount = data["participant_count"] as? Int    ?? 0
        self.createdAt        = (data["created_at"] as? Timestamp)?.dateValue() ?? Date()
        self.startedAt        = (data["started_at"] as? Timestamp)?.dateValue()
        self.endedAt          = (data["ended_at"]   as? Timestamp)?.dateValue()
        self.status           = RoundStatus(rawValue: data["status"] as? String ?? "") ?? .waiting
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Submission
// ─────────────────────────────────────────────────────────────

struct Submission: Identifiable, Equatable {
    let id: String
    let userId: String
    let photoUrl: String
    let entryFee: Double
    let isFromCamera: Bool
    let aiScore: Double?
    let aiReason: String?
    let submittedAt: Date

    static func == (lhs: Submission, rhs: Submission) -> Bool {
        lhs.id == rhs.id && lhs.aiScore == rhs.aiScore
    }

    init?(userId: String, data: [String: Any]) {
        guard let photoUrl = data["photo_url"] as? String else { return nil }
        self.id           = userId
        self.userId       = userId
        self.photoUrl     = photoUrl
        self.entryFee     = data["entry_fee"]      as? Double ?? 0
        self.isFromCamera = data["is_from_camera"] as? Bool   ?? false
        self.aiScore      = data["ai_score"]       as? Double
        self.aiReason     = data["ai_reason"]      as? String
        self.submittedAt  = (data["submitted_at"]  as? Timestamp)?.dateValue() ?? Date()
    }

    // Memberwise init for synthesising from Cloud Function results
    init(userId: String, photoUrl: String, entryFee: Double, isFromCamera: Bool, aiScore: Double?, aiReason: String?) {
        self.id           = userId
        self.userId       = userId
        self.photoUrl     = photoUrl
        self.entryFee     = entryFee
        self.isFromCamera = isFromCamera
        self.aiScore      = aiScore
        self.aiReason     = aiReason
        self.submittedAt  = Date()
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Friend
// ─────────────────────────────────────────────────────────────

struct Friend: Identifiable {
    let id: String
    let name: String
    let username: String
    let profilePictureUrl: String?
}

// ─────────────────────────────────────────────────────────────
// MARK: - UserProfile
// ─────────────────────────────────────────────────────────────

struct UserProfile: Identifiable {
    let id: String
    let name: String
    let username: String
    let profilePictureUrl: String?

    init(id: String, data: [String: Any]) {
        self.id                = id
        self.name              = data["name"]              as? String ?? "Unknown"
        self.username          = data["username"]          as? String ?? ""
        self.profilePictureUrl = data["profilePictureUrl"] as? String
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - IdentifiableImage
// ─────────────────────────────────────────────────────────────

struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
    let isFromCamera: Bool
}
