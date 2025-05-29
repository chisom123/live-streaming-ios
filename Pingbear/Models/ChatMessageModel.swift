import Foundation
import FirebaseFirestore

// MARK: - Simplified Message Model
struct ChatMessage: Identifiable, Equatable {
    let id: String
    let senderId: String
    let senderName: String
    let senderProfilePicture: String?
    let text: String
    let timestamp: Date
    let isRead: Bool
    let isCurrentUser: Bool
    let messageStatus: MessageStatus
    
    // Simplified photo message properties - ONLY store essentials
    let photoId: String? // Just the photo ID
    let photoCompetitionId: String? // Competition ID to fetch from
    let isPhotoMessage: Bool
    
    enum MessageStatus: String {
        case sending = "sending"
        case sent = "sent"
        case failed = "failed"
    }
    
    init(id: String = UUID().uuidString,
         senderId: String,
         senderName: String,
         senderProfilePicture: String? = nil,
         text: String,
         timestamp: Date = Date(),
         isRead: Bool = false,
         isCurrentUser: Bool = false,
         messageStatus: MessageStatus = .sending,
         photoId: String? = nil,
         photoCompetitionId: String? = nil) {
        self.id = id
        self.senderId = senderId
        self.senderName = senderName
        self.senderProfilePicture = senderProfilePicture
        self.text = text
        self.timestamp = timestamp
        self.isRead = isRead
        self.isCurrentUser = isCurrentUser
        self.messageStatus = messageStatus
        self.photoId = photoId
        self.photoCompetitionId = photoCompetitionId
        self.isPhotoMessage = photoId != nil
    }
    
    // Firestore data conversion
    init?(document: DocumentSnapshot, currentUserId: String) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.senderId = data["senderId"] as? String ?? ""
        self.senderName = data["senderName"] as? String ?? "Unknown"
        self.senderProfilePicture = data["senderProfilePicture"] as? String
        self.text = data["text"] as? String ?? ""
        self.timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        self.isRead = data["isRead"] as? Bool ?? false
        self.isCurrentUser = senderId == currentUserId
        self.messageStatus = .sent
        
        // Simplified photo message properties
        self.photoId = data["photoId"] as? String
        self.photoCompetitionId = data["photoCompetitionId"] as? String
        self.isPhotoMessage = photoId != nil
    }
    
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "senderId": senderId,
            "senderName": senderName,
            "text": text,
            "timestamp": Timestamp(date: timestamp),
            "isRead": isRead
        ]
        
        if let senderProfilePicture = senderProfilePicture {
            data["senderProfilePicture"] = senderProfilePicture
        }
        
        // Add photo properties if this is a photo message
        if let photoId = photoId {
            data["photoId"] = photoId
        }
        if let photoCompetitionId = photoCompetitionId {
            data["photoCompetitionId"] = photoCompetitionId
        }
        
        return data
    }
}
