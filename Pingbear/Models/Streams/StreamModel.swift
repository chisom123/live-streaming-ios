import Foundation
import FirebaseFirestore

// ─────────────────────────────────────────────────────────────
// MARK: - StreamStatus
// ─────────────────────────────────────────────────────────────

enum StreamStatus: String {
    case live  = "live"
    case ended = "ended"
}

// ─────────────────────────────────────────────────────────────
// MARK: - StreamModel
// ─────────────────────────────────────────────────────────────

struct StreamModel: Identifiable {
    let id:               String
    let streamerId:       String
    let streamerName:     String
    let streamerImageUrl: String?
    let status:           StreamStatus
    let startedAt:        Date?
    let endedAt:          Date?
    let livekitRoomName:  String
    let viewerIds:        [String]
    let invitedUserIds:   [String]
    let totalEarned:      Double
    let requestCount:     Int
    let createdAt:        Date

    var isLive: Bool { status == .live }

    var elapsedSeconds: Int {
        guard let start = startedAt else { return 0 }
        return Int(Date().timeIntervalSince(start))
    }

    static func from(_ doc: DocumentSnapshot) -> StreamModel? {
        guard let data = doc.data() else { return nil }
        guard
            let streamerId = data["streamer_id"]      as? String,
            let statusRaw  = data["status"]            as? String,
            let status     = StreamStatus(rawValue: statusRaw),
            let roomName   = data["livekit_room_name"] as? String,
            let createdAt  = (data["created_at"] as? Timestamp)?.dateValue()
        else { return nil }

        return StreamModel(
            id:               doc.documentID,
            streamerId:       streamerId,
            streamerName:     data["streamer_name"]      as? String ?? "",
            streamerImageUrl: data["streamer_image_url"] as? String,
            status:           status,
            startedAt:        (data["started_at"] as? Timestamp)?.dateValue(),
            endedAt:          (data["ended_at"]   as? Timestamp)?.dateValue(),
            livekitRoomName:  roomName,
            viewerIds:        data["viewer_ids"]       as? [String] ?? [],
            invitedUserIds:   data["invited_user_ids"] as? [String] ?? [],
            totalEarned:      data["total_earned"]     as? Double   ?? 0,
            requestCount:     data["request_count"]    as? Int      ?? 0,
            createdAt:        createdAt
        )
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - StreamRequestStatus
// ─────────────────────────────────────────────────────────────

enum StreamRequestStatus: String {
    case pending   = "pending"
    case accepted  = "accepted"
    case completed = "completed"
    case declined  = "declined"
    case refunded  = "refunded"
}

// ─────────────────────────────────────────────────────────────
// MARK: - StreamRequest
// ─────────────────────────────────────────────────────────────

struct StreamRequest: Identifiable {
    let id:               String
    let streamId:         String
    let fromUserId:       String
    let fromUserName:     String
    let fromUserImageUrl: String?
    let streamerId:       String
    let description:      String
    let price:            Double
    let platformFee:      Double
    let creatorPayout:    Double
    let status:           StreamRequestStatus
    let fundedBonusAmount: Double
    let fundedRealAmount:  Double
    let createdAt:        Date
    let acceptedAt:       Date?
    let completedAt:      Date?

    static func from(_ doc: DocumentSnapshot) -> StreamRequest? {
        guard let data = doc.data() else { return nil }
        guard
            let streamId    = data["stream_id"]    as? String,
            let fromUserId  = data["from_user_id"] as? String,
            let streamerId  = data["streamer_id"]  as? String,
            let description = data["description"]  as? String,
            let price       = data["price"]        as? Double,
            let statusRaw   = data["status"]       as? String,
            let status      = StreamRequestStatus(rawValue: statusRaw),
            let createdAt   = (data["created_at"] as? Timestamp)?.dateValue()
        else { return nil }

        return StreamRequest(
            id:               doc.documentID,
            streamId:         streamId,
            fromUserId:       fromUserId,
            fromUserName:     data["from_user_name"]      as? String ?? "",
            fromUserImageUrl: data["from_user_image_url"] as? String,
            streamerId:       streamerId,
            description:      description,
            price:            price,
            platformFee:      data["platform_fee"]    as? Double ?? price * 0.20,
            creatorPayout:    data["creator_payout"]  as? Double ?? price * 0.80,
            status:           status,
            fundedBonusAmount: data["funded_bonus_amount"] as? Double ?? 0,
            fundedRealAmount:  data["funded_real_amount"]  as? Double ?? price,
            createdAt:        createdAt,
            acceptedAt:       (data["accepted_at"]  as? Timestamp)?.dateValue(),
            completedAt:      (data["completed_at"] as? Timestamp)?.dateValue()
        )
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - ChatMessage
// ─────────────────────────────────────────────────────────────

enum ChatMessageType: String, Codable {
    case chat = "chat"
    case joinEvent = "join_event"
    case requestEvent = "request_event"
    case requestAccepted = "request_accepted"
    case requestDeclined = "request_declined"
    case requestCompleted = "request_completed"
}

struct ChatMessage: Identifiable, Codable {
    let id: String
    let userId: String
    let name: String
    let avatarUrl: String?
    let text: String
    let type: ChatMessageType
    let requestId: String?
    let createdAt: Date
    
    init(id: String, userId: String, name: String, avatarUrl: String?, text: String, type: ChatMessageType, requestId: String?, createdAt: Date) {
        self.id = id
        self.userId = userId
        self.name = name
        self.avatarUrl = avatarUrl
        self.text = text
        self.type = type
        self.requestId = requestId
        self.createdAt = createdAt
    }
    
    static func from(_ document: DocumentSnapshot) -> ChatMessage? {
        guard let data = document.data() else { return nil }
        
        guard let userId = data["user_id"] as? String,
              let name = data["name"] as? String,
              let text = data["text"] as? String,
              let typeRaw = data["type"] as? String,
              let type = ChatMessageType(rawValue: typeRaw),
              let createdAt = (data["created_at"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        let avatarUrl = data["avatar_url"] as? String
        let requestId = data["request_id"] as? String
        
        return ChatMessage(
            id: document.documentID,
            userId: userId,
            name: name,
            avatarUrl: avatarUrl,
            text: text,
            type: type,
            requestId: requestId,
            createdAt: createdAt
        )
    }
}
