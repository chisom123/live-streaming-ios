import FirebaseFirestore

// Enum to define notification types
enum NotificationType: String, CaseIterable {
    case message = "message"
    case photo = "photo"
}

// A singleton manager to handle queued notifications
class NotificationQueueManager {
    static let shared = NotificationQueueManager()
    
    private init() {}
    
    // Add notification to queue with type
    func queueNotification(competitionId: String, competitionDescription: String, userId: String, type: NotificationType) {
        let notificationData: [String: Any] = [
            "competitionId": competitionId,
            "competitionDescription": competitionDescription,
            "userId": userId,
            "type": type.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        let entryId = UUID().uuidString
        UserDefaults.standard.setValue(notificationData, forKey: "pendingNotification_\(entryId)")
    }
    
    // Process queued notifications
    func processQueuedNotifications() {
        // Look for any pending notifications
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.starts(with: "pendingNotification_") }
        
        for key in keys {
            if let notificationData = defaults.dictionary(forKey: key) {
                // Extract data
                let competitionId = notificationData["competitionId"] as? String ?? ""
                let competitionDescription = notificationData["competitionDescription"] as? String ?? ""
                let userId = notificationData["userId"] as? String ?? ""
                let typeString = notificationData["type"] as? String ?? "message"
                let notificationType = NotificationType(rawValue: typeString) ?? .message
                
                // Now we can safely send notifications without affecting UI
                DispatchQueue.global(qos: .background).async {
                    self.sendNotificationsToMembers(
                        userId: userId,
                        competitionId: competitionId,
                        competitionDescription: competitionDescription,
                        type: notificationType
                    )
                    
                    // Remove the pending notification once processed
                    DispatchQueue.main.async {
                        defaults.removeObject(forKey: key)
                    }
                }
            }
        }
    }
    
    // Send notifications to members
    private func sendNotificationsToMembers(userId: String, competitionId: String, competitionDescription: String, type: NotificationType) {
        let db = Firestore.firestore()
        let pushNotificationSender = PushNotificationSender()
        
        // First get the current user's username
        db.collection("users")
            .document(userId)
            .getDocument { snapshot, error in
                if let error = error {
                    print("Error fetching current user data: \(error)")
                    return
                }
                
                var username = "Someone"
                
                if let userData = snapshot?.data(),
                   let usernameData = userData["username"] as? String {
                    username = usernameData
                }
                
                // Now get all competition members
                db.collection("competitions")
                    .document(competitionId)
                    .collection("members")
                    .getDocuments { snapshot, error in
                        if let error = error {
                            print("Error fetching competition members: \(error)")
                            return
                        }
                        
                        guard let documents = snapshot?.documents else {
                            print("No members found")
                            return
                        }
                        
                        // Process members in a batch to reduce load
                        let batchSize = 3
                        var currentBatch = 0
                        var pendingBatches: [[DocumentSnapshot]] = []
                        
                        // Split members into batches
                        for i in stride(from: 0, to: documents.count, by: batchSize) {
                            let end = min(i + batchSize, documents.count)
                            let batch = Array(documents[i..<end])
                            pendingBatches.append(batch)
                        }
                        
                        // Process each batch with a delay between batches
                        func processNextBatch() {
                            guard currentBatch < pendingBatches.count else {
                                print("All notification batches processed")
                                return
                            }
                            
                            let batch = pendingBatches[currentBatch]
                            currentBatch += 1
                            
                            for document in batch {
                                let memberId = document.documentID
                                
                                // Skip the current user - don't notify themselves
                                if memberId == userId {
                                    continue
                                }
                                
                                // Get the member's FCM token
                                db.collection("users")
                                    .document(memberId)
                                    .getDocument { snapshot, error in
                                        if let error = error {
                                            print("Error fetching user \(memberId): \(error)")
                                            return
                                        }
                                        
                                        guard let userData = snapshot?.data(),
                                              let fcmToken = userData["fcmToken"] as? String,
                                              !fcmToken.isEmpty else {
                                            print("No valid FCM token for user \(memberId)")
                                            return
                                        }
                                        
                                        // Send the notification
                                        let title = "\(competitionDescription)"
                                        let body: String
                                        
                                        switch type {
                                        case .message:
                                            body = "\(username) sent a message"
                                        case .photo:
                                            body = "\(username) shared a photo"
                                        }
                                        
                                        pushNotificationSender.sendPushNotification(
                                            to: fcmToken,
                                            title: title,
                                            body: body
                                        ) { result in
                                            switch result {
                                            case .success:
                                                print("Successfully sent notification to \(memberId)")
                                            case .failure(let error):
                                                print("Failed to send notification to \(memberId): \(error.localizedDescription)")
                                            }
                                        }
                                    }
                            }
                            
                            // Schedule the next batch with a delay
                            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
                                processNextBatch()
                            }
                        }
                        
                        // Start processing batches
                        processNextBatch()
                    }
            }
    }
}
