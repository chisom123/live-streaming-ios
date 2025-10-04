import FirebaseFirestore

// Enum to define notification targets
enum NotificationTarget {
    case individual(userId: String)
    case group(competitionId: String, excludeUsers: [String] = [])
    case specificUsers(userIds: [String])
    
    var description: String {
        switch self {
        case .individual(let userId):
            return "Individual: \(userId)"
        case .group(let competitionId, let excludeUsers):
            return "Group: \(competitionId), excluding \(excludeUsers.count) users"
        case .specificUsers(let userIds):
            return "Specific users: \(userIds.count) recipients"
        }
    }
}

// Struct to encapsulate notification data
struct QueuedNotification {
    let id: String
    let target: NotificationTarget
    let title: String
    let body: String
    let senderId: String
    let competitionId: String?
    let timestamp: TimeInterval
    let metadata: [String: Any]?
    
    // Convert to dictionary for UserDefaults storage
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "title": title,
            "body": body,
            "senderId": senderId,
            "timestamp": timestamp
        ]
        
        if let competitionId = competitionId {
            dict["competitionId"] = competitionId
        }
        
        if let metadata = metadata {
            dict["metadata"] = metadata
        }
        
        // Encode target
        switch target {
        case .individual(let userId):
            dict["targetType"] = "individual"
            dict["targetUserId"] = userId
        case .group(let competitionId, let excludeUsers):
            dict["targetType"] = "group"
            dict["targetCompetitionId"] = competitionId
            dict["excludeUsers"] = excludeUsers
        case .specificUsers(let userIds):
            dict["targetType"] = "specificUsers"
            dict["targetUserIds"] = userIds
        }
        
        return dict
    }
    
    // Create from dictionary
    static func fromDictionary(_ dict: [String: Any]) -> QueuedNotification? {
        guard let id = dict["id"] as? String,
              let title = dict["title"] as? String,
              let body = dict["body"] as? String,
              let senderId = dict["senderId"] as? String,
              let timestamp = dict["timestamp"] as? TimeInterval,
              let targetType = dict["targetType"] as? String else {
            return nil
        }
        
        let target: NotificationTarget
        
        switch targetType {
        case "individual":
            guard let userId = dict["targetUserId"] as? String else { return nil }
            target = .individual(userId: userId)
        case "group":
            guard let competitionId = dict["targetCompetitionId"] as? String else { return nil }
            let excludeUsers = dict["excludeUsers"] as? [String] ?? []
            target = .group(competitionId: competitionId, excludeUsers: excludeUsers)
        case "specificUsers":
            guard let userIds = dict["targetUserIds"] as? [String] else { return nil }
            target = .specificUsers(userIds: userIds)
        default:
            return nil
        }
        
        return QueuedNotification(
            id: id,
            target: target,
            title: title,
            body: body,
            senderId: senderId,
            competitionId: dict["competitionId"] as? String,
            timestamp: timestamp,
            metadata: dict["metadata"] as? [String: Any]
        )
    }
}

// Enhanced singleton manager to handle queued notifications
class NotificationQueueManager {
    static let shared = NotificationQueueManager()
    
    private let db = Firestore.firestore()
    private let pushNotificationSender = PushNotificationSender()
    private var isProcessing = false
    
    private init() {}
    
    // MARK: - Public Queue Methods
    
    /// Queue a notification to an individual user
    func queueIndividualNotification(
        to userId: String,
        title: String,
        body: String,
        senderId: String,
        competitionId: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        let notification = QueuedNotification(
            id: UUID().uuidString,
            target: .individual(userId: userId),
            title: title,
            body: body,
            senderId: senderId,
            competitionId: competitionId,
            timestamp: Date().timeIntervalSince1970,
            metadata: metadata
        )
        
        saveNotificationToQueue(notification)
    }
    
    /// Queue a notification to all members of a competition group
    func queueGroupNotification(
        competitionId: String,
        title: String,
        body: String,
        senderId: String,
        excludeUsers: [String] = [],
        metadata: [String: Any]? = nil
    ) {
        let notification = QueuedNotification(
            id: UUID().uuidString,
            target: .group(competitionId: competitionId, excludeUsers: excludeUsers),
            title: title,
            body: body,
            senderId: senderId,
            competitionId: competitionId,
            timestamp: Date().timeIntervalSince1970,
            metadata: metadata
        )
        
        saveNotificationToQueue(notification)
    }
    
    /// Queue a notification to specific users
    func queueNotificationToUsers(
        userIds: [String],
        title: String,
        body: String,
        senderId: String,
        competitionId: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        let notification = QueuedNotification(
            id: UUID().uuidString,
            target: .specificUsers(userIds: userIds),
            title: title,
            body: body,
            senderId: senderId,
            competitionId: competitionId,
            timestamp: Date().timeIntervalSince1970,
            metadata: metadata
        )
        
        saveNotificationToQueue(notification)
    }
    
    // MARK: - Queue Processing
    
    /// Process all queued notifications
    func processQueuedNotifications() {
        guard !isProcessing else {
            print("Already processing notifications")
            return
        }
        
        isProcessing = true
        
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.starts(with: "pendingNotification_") }
        
        guard !keys.isEmpty else {
            isProcessing = false
            return
        }
        
        print("Processing \(keys.count) queued notifications")
        
        for key in keys {
            if let notificationData = defaults.dictionary(forKey: key),
               let notification = QueuedNotification.fromDictionary(notificationData) {
                
                DispatchQueue.global(qos: .background).async {
                    self.processNotification(notification) {
                        // Remove from queue after processing
                        DispatchQueue.main.async {
                            defaults.removeObject(forKey: key)
                        }
                    }
                }
            } else {
                // Remove invalid notification data
                defaults.removeObject(forKey: key)
            }
        }
        
        // Reset processing flag after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isProcessing = false
        }
    }
    
    // MARK: - Private Methods
    
    private func saveNotificationToQueue(_ notification: QueuedNotification) {
        let key = "pendingNotification_\(notification.id)"
        UserDefaults.standard.setValue(notification.toDictionary(), forKey: key)
        print("Queued notification: \(notification.target.description)")
    }
    
    private func processNotification(_ notification: QueuedNotification, completion: @escaping () -> Void) {
        switch notification.target {
        case .individual(let userId):
            sendToIndividual(userId: userId, notification: notification, completion: completion)
            
        case .group(let competitionId, let excludeUsers):
            sendToGroup(competitionId: competitionId, excludeUsers: excludeUsers, notification: notification, completion: completion)
            
        case .specificUsers(let userIds):
            sendToSpecificUsers(userIds: userIds, notification: notification, completion: completion)
        }
    }
    
    private func sendToIndividual(userId: String, notification: QueuedNotification, completion: @escaping () -> Void) {
        fetchFCMToken(for: userId) { token in
            guard let token = token else {
                print("No FCM token for user \(userId)")
                completion()
                return
            }
            
            self.sendNotification(to: token, title: notification.title, body: notification.body) { success in
                if success {
                    print("Successfully sent notification to \(userId)")
                } else {
                    print("Failed to send notification to \(userId)")
                }
                completion()
            }
        }
    }
    
    private func sendToGroup(competitionId: String, excludeUsers: [String], notification: QueuedNotification, completion: @escaping () -> Void) {
        db.collection("competitions")
            .document(competitionId)
            .collection("members")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching competition members: \(error)")
                    completion()
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No members found")
                    completion()
                    return
                }
                
                let memberIds = documents.map { $0.documentID }.filter { !excludeUsers.contains($0) }
                self.sendToSpecificUsers(userIds: memberIds, notification: notification, completion: completion)
            }
    }
    
    private func sendToSpecificUsers(userIds: [String], notification: QueuedNotification, completion: @escaping () -> Void) {
        let batchSize = 3
        var currentBatch = 0
        var pendingBatches: [[String]] = []
        
        // Split into batches
        for i in stride(from: 0, to: userIds.count, by: batchSize) {
            let end = min(i + batchSize, userIds.count)
            let batch = Array(userIds[i..<end])
            pendingBatches.append(batch)
        }
        
        func processNextBatch() {
            guard currentBatch < pendingBatches.count else {
                print("All notification batches processed")
                completion()
                return
            }
            
            let batch = pendingBatches[currentBatch]
            currentBatch += 1
            
            for userId in batch {
                self.fetchFCMToken(for: userId) { token in
                    guard let token = token else { return }
                    
                    self.sendNotification(to: token, title: notification.title, body: notification.body) { success in
                        if success {
                            print("Successfully sent notification to \(userId)")
                        } else {
                            print("Failed to send notification to \(userId)")
                        }
                    }
                }
            }
            
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
                processNextBatch()
            }
        }
        
        processNextBatch()
    }
    
    private func fetchFCMToken(for userId: String, completion: @escaping (String?) -> Void) {
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching user \(userId): \(error)")
                completion(nil)
                return
            }
            
            guard let userData = snapshot?.data(),
                  let fcmToken = userData["fcmToken"] as? String,
                  !fcmToken.isEmpty else {
                completion(nil)
                return
            }
            
            completion(fcmToken)
        }
    }
    
    private func sendNotification(to token: String, title: String, body: String, completion: @escaping (Bool) -> Void) {
        pushNotificationSender.sendPushNotification(to: token, title: title, body: body) { result in
            switch result {
            case .success:
                completion(true)
            case .failure(let error):
                print("Notification error: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
}
