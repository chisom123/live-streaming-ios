import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class ChatIndicatorViewModel: ObservableObject {
    @Published var hasUnreadMessages: Bool = false
    @Published var unreadMessageCount: Int = 0
    
    private let competitionId: String
    private let currentUserId: String
    private let db = Firestore.firestore()
    private var lastReadTimestamp: Date?
    
    init(competitionId: String) {
        self.competitionId = competitionId
        self.currentUserId = Auth.auth().currentUser?.uid ?? ""
        loadLastReadTimestamp()
        checkForUnreadMessages()
    }
    
    private func loadLastReadTimestamp() {
        guard !currentUserId.isEmpty else { return }
        
        let userDefaults = UserDefaults.standard
        let key = "lastReadMessage_\(competitionId)_\(currentUserId)"
        
        if let savedTimestamp = userDefaults.object(forKey: key) as? Date {
            lastReadTimestamp = savedTimestamp
        }
    }
    
    func checkForUnreadMessages() {
        guard !currentUserId.isEmpty else { return }
        
        // Limit to 10 since we only need to distinguish between 1-9 and "9+"
        let query = db.collection("competitions")
            .document(competitionId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: 10)
        
        query.getDocuments { [weak self] snapshot, error in
            guard let self = self,
                  let documents = snapshot?.documents else {
                DispatchQueue.main.async {
                    self?.hasUnreadMessages = false
                    self?.unreadMessageCount = 0
                }
                return
            }
            
            self.processMessagesForUnread(documents)
        }
    }
    
    private func processMessagesForUnread(_ documents: [QueryDocumentSnapshot]) {
        guard let lastReadTimestamp = lastReadTimestamp else {
            // If no last read timestamp, count all messages from other users
            let unreadCount = documents.filter { document in
                let data = document.data()
                let messageUserId = data["senderId"] as? String ?? ""
                return messageUserId != currentUserId
            }.count
            
            DispatchQueue.main.async {
                self.hasUnreadMessages = unreadCount > 0
                self.unreadMessageCount = unreadCount
            }
            return
        }
        
        // Count messages from other users that are newer than last read
        let unreadCount = documents.filter { document in
            let data = document.data()
            let messageUserId = data["senderId"] as? String ?? ""
            let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            
            return messageUserId != currentUserId && timestamp > lastReadTimestamp
        }.count
        
        DispatchQueue.main.async {
            self.hasUnreadMessages = unreadCount > 0
            self.unreadMessageCount = unreadCount
        }
    }
    
    func markAsRead() {
        let userDefaults = UserDefaults.standard
        let key = "lastReadMessage_\(competitionId)_\(currentUserId)"
        let now = Date()
        
        userDefaults.set(now, forKey: key)
        lastReadTimestamp = now
        
        DispatchQueue.main.async {
            self.hasUnreadMessages = false
            self.unreadMessageCount = 0
        }
    }
    
    // Optional: Manual refresh method that can be called when needed
    func refresh() {
        checkForUnreadMessages()
    }
    
    // Helper computed property for display text
    var displayCount: String {
        if unreadMessageCount <= 9 {
            return "\(unreadMessageCount)"
        } else {
            return "9+"
        }
    }
}
