import Foundation
import FirebaseFirestore
import FirebaseAuth

class ParlayManager {
    static let shared = ParlayManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // Main entry point for handling ratings
    func handleRating(
        competitionId: String,
        entryId: String,
        userId: String,
        rating: Int,
        completion: @escaping (Bool) -> Void
    ) {
        let entryRef = db.collection("competitions").document(competitionId).collection("entries").document(entryId)
        let voteRef = db.collection("groupMemberships").document(userId)
                         .collection("competitions").document(competitionId)
                         .collection("votes").document(entryId)
        
        let interactionRef = db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .document(entryId)
            .collection("interactions")
            .document(userId)
        
        // Fetch the entry to check if it has parlay predictions
        entryRef.getDocument { (document, error) in
            if let error = error {
                print("ParlayManager: Error fetching entry: \(error)")
                completion(false)
                return
            }
            
            guard let document = document, let data = document.data() else {
                print("ParlayManager: Entry data not found")
                completion(false)
                return
            }
            
            let starIncrement = rating
            
            // All entries have predictions field, but check if current user is predicted
            let predictions = data["predictions"] as? [String: Any] ?? [:]
            
            if let userPrediction = predictions[userId] as? [String: Any],
               let predictedRating = userPrediction["predictedRating"] as? Int {
                
                // Current user has a prediction - handle parlay logic
                self.handleParlayRating(
                    entryRef: entryRef,
                    voteRef: voteRef,
                    interactionRef: interactionRef,
                    competitionId: competitionId,
                    entryId: entryId,
                    userId: userId,
                    rating: rating,
                    starIncrement: starIncrement,
                    predictedRating: predictedRating,
                    entryData: data,
                    completion: completion
                )
            } else {
                // User not in predictions - regular rating, no parlay logic
                self.updateRegularRating(
                    entryRef: entryRef,
                    voteRef: voteRef,
                    interactionRef: interactionRef,
                    entryId: entryId,
                    userId: userId,
                    starIncrement: starIncrement,
                    rating: rating,
                    completion: completion
                )
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    // Handle parlay-specific rating logic
    private func handleParlayRating(
        entryRef: DocumentReference,
        voteRef: DocumentReference,
        interactionRef: DocumentReference,
        competitionId: String,
        entryId: String,
        userId: String,
        rating: Int,
        starIncrement: Int,
        predictedRating: Int,
        entryData: [String: Any],
        completion: @escaping (Bool) -> Void
    ) {
        // Check if prediction is correct
        let isCorrect = (rating == predictedRating)
        
        // Update the prediction result
        var updatedPredictions = entryData["predictions"] as? [String: Any] ?? [:]
        updatedPredictions[userId] = [
            "predictedRating": predictedRating,
            "actualRating": rating,
            "correct": isCorrect,
            "ratedAt": FieldValue.serverTimestamp()
        ]
        
        // Write to predictions collection for analytics
        self.writePredictionRecord(
            competitionId: competitionId,
            entryId: entryId,
            predictorUserId: userId,
            entryOwnerId: entryData["userId"] as? String ?? "",
            predictedRating: predictedRating,
            actualRating: rating,
            correct: isCorrect
        )
        
        // Check parlay status with new early failure detection
        let (allComplete, allCorrect, hasFailure) = checkParlayStatus(predictions: updatedPredictions)
        
        if hasFailure {
            // Parlay lost - mark as lost immediately even if not all ratings are in
            updateParlayEntry(
                entryRef: entryRef,
                voteRef: voteRef,
                interactionRef: interactionRef,
                entryId: entryId,
                userId: userId,
                starIncrement: starIncrement,
                rating: rating,
                updatedPredictions: updatedPredictions,
                parlayStatus: "lost",
                completion: completion
            )
        } else if allComplete && allCorrect {
            // All predictions complete and all correct - parlay won
            handleParlayWin(
                entryRef: entryRef,
                voteRef: voteRef,
                interactionRef: interactionRef,
                competitionId: competitionId,
                entryId: entryId,
                userId: userId,
                starIncrement: starIncrement,
                rating: rating,
                updatedPredictions: updatedPredictions,
                entryData: entryData,
                completion: completion
            )
        } else {
            // Parlay still pending (no failures yet, but not all complete)
            updateParlayEntry(
                entryRef: entryRef,
                voteRef: voteRef,
                interactionRef: interactionRef,
                entryId: entryId,
                userId: userId,
                starIncrement: starIncrement,
                rating: rating,
                updatedPredictions: updatedPredictions,
                parlayStatus: "pending",
                completion: completion
            )
        }
    }
    
    // Write prediction record to dedicated collection for analytics
    private func writePredictionRecord(
        competitionId: String,
        entryId: String,
        predictorUserId: String,
        entryOwnerId: String,
        predictedRating: Int,
        actualRating: Int,
        correct: Bool
    ) {
        let predictionData: [String: Any] = [
            "competitionId": competitionId,
            "entryId": entryId,
            "predictorUserId": predictorUserId,
            "entryOwnerId": entryOwnerId,
            "predictedRating": predictedRating,
            "actualRating": actualRating,
            "correct": correct,
            "createdAt": FieldValue.serverTimestamp(),
            "ratedAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("predictions").addDocument(data: predictionData) { error in
            if let error = error {
                print("ParlayManager: Error writing prediction record: \(error)")
            } else {
                print("ParlayManager: Prediction record written successfully")
            }
        }
    }
    
    // Check if all predictions are complete and all are correct
    private func checkParlayStatus(predictions: [String: Any]) -> (allComplete: Bool, allCorrect: Bool, hasFailure: Bool) {
        var allComplete = true
        var allCorrect = true
        var hasFailure = false
        
        for (_, predictionData) in predictions {
            if let prediction = predictionData as? [String: Any] {
                // Check if this prediction has been rated
                if prediction["actualRating"] == nil {
                    allComplete = false
                } else {
                    // Check if this prediction is correct
                    if let correct = prediction["correct"] as? Bool, !correct {
                        allCorrect = false
                        hasFailure = true // Mark that we have at least one failure
                    }
                }
            }
        }
        
        return (allComplete, allCorrect, hasFailure)
    }
    
    // Handle parlay win with atomic transaction for coin payout
    private func handleParlayWin(
        entryRef: DocumentReference,
        voteRef: DocumentReference,
        interactionRef: DocumentReference,
        competitionId: String,
        entryId: String,
        userId: String,
        starIncrement: Int,
        rating: Int,
        updatedPredictions: [String: Any],
        entryData: [String: Any],
        completion: @escaping (Bool) -> Void
    ) {
        guard let potentialPayout = entryData["potentialPayout"] as? Int,
              let entryOwnerId = entryData["userId"] as? String else {
            print("ParlayManager: Error - Missing potentialPayout or userId in entry data")
            completion(false)
            return
        }
        
        let memberRef = db.collection("competitions")
            .document(competitionId)
            .collection("members")
            .document(entryOwnerId)
        
        // Use transaction to ensure atomic coin payout and entry update
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            // Read current coins
            let memberDoc: DocumentSnapshot
            do {
                memberDoc = try transaction.getDocument(memberRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            let currentCoins = memberDoc.data()?["coins"] as? Int ?? 0
            let newCoins = currentCoins + potentialPayout
            
            // Update all documents in transaction
            transaction.setData(["entryId": entryId], forDocument: voteRef, merge: true)
            transaction.updateData(["stars": FieldValue.increment(Int64(starIncrement))], forDocument: entryRef)
            transaction.setData(["rating": rating, "userId": userId], forDocument: interactionRef, merge: true)
            
            // Update parlay entry status
            transaction.updateData([
                "predictions": updatedPredictions,
                "parlayStatus": "won",
                "parlayResolvedAt": FieldValue.serverTimestamp()
            ], forDocument: entryRef)
            
            // Add coins to member
            transaction.updateData(["coins": newCoins], forDocument: memberRef)
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("ParlayManager: Parlay win transaction failed: \(error)")
                completion(false)
            } else {
                print("ParlayManager: Parlay won! Paid out \(potentialPayout) coins to user \(entryOwnerId)")
                
                // Fetch competition name and winner's username for notifications
                self.db.collection("competitions").document(competitionId).getDocument { compDoc, _ in
                    let competitionName = compDoc?.data()?["description"] as? String ?? "Game"
                    let predictionText = updatedPredictions.count == 1 ? "prediction" : "predictions"
                    let systemUserId = "zxBo4ecEp1hzXhpVIfQ1vFpclkz1"
                    
                    // Fetch winner's username
                    self.db.collection("users").document(entryOwnerId).getDocument { userDoc, _ in
                        let winnerUsername = userDoc?.data()?["username"] as? String ?? "Someone"
                        
                        // Send individual notification to winner
                        NotificationQueueManager.shared.queueIndividualNotification(
                            to: entryOwnerId,
                            title: competitionName,
                            body: "Congratulations! You won \(potentialPayout) coins on \(updatedPredictions.count) \(predictionText)",
                            senderId: systemUserId
                        )
                        
                        // Send group notification
                        NotificationQueueManager.shared.queueGroupNotification(
                            competitionId: competitionId,
                            title: competitionName,
                            body: "\(winnerUsername) just won \(potentialPayout) coins on \(updatedPredictions.count) \(predictionText)!",
                            senderId: systemUserId,
                            excludeUsers: [entryOwnerId]
                        )
                        
                        NotificationQueueManager.shared.processQueuedNotifications()
                    }
                }
                
                self.sendParlayWinMessage(
                    competitionId: competitionId,
                    entryId: entryId,
                    winnerUserId: entryOwnerId,
                    payout: potentialPayout,
                    predictionCount: updatedPredictions.count
                )
                
                // Track analytics for parlay win
                Analytics.shared.track(
                    event: "parlay_won",
                    properties: [
                        "entry_id": entryId,
                        "competition_id": competitionId,
                        "payout": potentialPayout,
                        "predictions_count": updatedPredictions.count
                    ]
                )
                completion(true)
            }
        }
    }
    
    // Update parlay entry without coin payout
    private func updateParlayEntry(
        entryRef: DocumentReference,
        voteRef: DocumentReference,
        interactionRef: DocumentReference,
        entryId: String,
        userId: String,
        starIncrement: Int,
        rating: Int,
        updatedPredictions: [String: Any],
        parlayStatus: String,
        completion: @escaping (Bool) -> Void
    ) {
        let batch = db.batch()
        
        batch.setData(["entryId": entryId], forDocument: voteRef, merge: true)
        batch.updateData(["stars": FieldValue.increment(Int64(starIncrement))], forDocument: entryRef)
        batch.setData(["rating": rating, "userId": userId], forDocument: interactionRef, merge: true)
        
        var updateData: [String: Any] = [
            "predictions": updatedPredictions,
            "parlayStatus": parlayStatus
        ]
        
        // Add resolved timestamp if parlay is complete
        if parlayStatus != "pending" {
            updateData["parlayResolvedAt"] = FieldValue.serverTimestamp()
        }
        
        batch.updateData(updateData, forDocument: entryRef)
        
        batch.commit { err in
            if let err = err {
                print("ParlayManager: Parlay update batch commit failed: \(err)")
                completion(false)
            } else {
                print("ParlayManager: Parlay entry updated successfully - Status: \(parlayStatus)")
                
                // Send notification to photo owner about the rating
                entryRef.getDocument { entryDoc, _ in
                    guard let entryData = entryDoc?.data(),
                          let entryOwnerId = entryData["userId"] as? String else {
                        completion(true)
                        return
                    }
                    
                    // Don't notify if user rated their own entry
                    guard entryOwnerId != userId else {
                        completion(true)
                        return
                    }
                    
                    // Get competition ID from path
                    let pathComponents = entryRef.path.components(separatedBy: "/")
                    let competitionId = pathComponents.count > 1 ? pathComponents[1] : ""
                    
                    // Fetch rater username and competition name
                    let group = DispatchGroup()
                    var raterUsername = "Someone"
                    var competitionName = "Game"
                    
                    group.enter()
                    self.db.collection("users").document(userId).getDocument { userDoc, _ in
                        raterUsername = userDoc?.data()?["username"] as? String ?? "Someone"
                        group.leave()
                    }
                    
                    group.enter()
                    self.db.collection("competitions").document(competitionId).getDocument { compDoc, _ in
                        competitionName = compDoc?.data()?["description"] as? String ?? "Game"
                        group.leave()
                    }
                    
                    group.notify(queue: .main) {
                        let starText = rating == 1 ? "star" : "stars"
                        
                        NotificationQueueManager.shared.queueIndividualNotification(
                            to: entryOwnerId,
                            title: competitionName,
                            body: "\(raterUsername) rated your photo \(rating) \(starText)",
                            senderId: userId,
                            competitionId: competitionId
                        )
                        
                        NotificationQueueManager.shared.processQueuedNotifications()
                    }
                }
                
                if parlayStatus == "lost" {
                    Analytics.shared.track(
                        event: "parlay_lost",
                        properties: [
                            "entry_id": entryId,
                            "predictions_count": updatedPredictions.count
                        ]
                    )
                }
                completion(true)
            }
        }
    }
    
    // Handle ratings from users not in predictions (just updates stars, no parlay logic)
    private func updateRegularRating(
        entryRef: DocumentReference,
        voteRef: DocumentReference,
        interactionRef: DocumentReference,
        entryId: String,
        userId: String,
        starIncrement: Int,
        rating: Int,
        completion: @escaping (Bool) -> Void
    ) {
        let batch = db.batch()
        
        batch.setData(["entryId": entryId], forDocument: voteRef, merge: true)
        batch.updateData(["stars": FieldValue.increment(Int64(starIncrement))], forDocument: entryRef)
        batch.setData(["rating": rating, "userId": userId], forDocument: interactionRef, merge: true)
        
        batch.commit { err in
            if let err = err {
                print("ParlayManager: Regular entry batch commit failed: \(err)")
                completion(false)
            } else {
                print("ParlayManager: Regular entry rating updated successfully!")
                
                // Fetch entry owner ID and competition ID
                entryRef.getDocument { entryDoc, _ in
                    guard let entryData = entryDoc?.data(),
                          let entryOwnerId = entryData["userId"] as? String else {
                        completion(true)
                        return
                    }
                    
                    // Don't notify if user rated their own entry
                    guard entryOwnerId != userId else {
                        completion(true)
                        return
                    }
                    
                    // Fetch rater's username and competition name in parallel
                    let raterRef = self.db.collection("users").document(userId)
                    
                    let group = DispatchGroup()
                    var raterUsername = "Someone"
                    var competitionId = ""
                    var competitionName = "Game"
                    
                    // Get competition ID from entry data
                    if let compId = entryData["competitionId"] as? String {
                        competitionId = compId
                    } else {
                        // If not stored in entry, we need to extract from entryRef path
                        let pathComponents = entryRef.path.components(separatedBy: "/")
                        if pathComponents.count > 1 {
                            competitionId = pathComponents[1]
                        }
                    }
                    
                    group.enter()
                    raterRef.getDocument { userDoc, _ in
                        raterUsername = userDoc?.data()?["username"] as? String ?? "Someone"
                        group.leave()
                    }
                    
                    group.enter()
                    self.db.collection("competitions").document(competitionId).getDocument { compDoc, _ in
                        competitionName = compDoc?.data()?["description"] as? String ?? "Game"
                        group.leave()
                    }
                    
                    group.notify(queue: .main) {
                        let starText = rating == 1 ? "star" : "stars"
                        
                        NotificationQueueManager.shared.queueIndividualNotification(
                            to: entryOwnerId,
                            title: competitionName,
                            body: "\(raterUsername) rated your photo \(rating) \(starText)",
                            senderId: userId,
                            competitionId: competitionId
                        )
                        
                        NotificationQueueManager.shared.processQueuedNotifications()
                    }
                }
                
                completion(true)
            }
        }
    }
    
    private func sendParlayWinMessage(
        competitionId: String,
        entryId: String,
        winnerUserId: String,
        payout: Int,
        predictionCount: Int
    ) {
        let systemUserId = "zxBo4ecEp1hzXhpVIfQ1vFpclkz1"
        let staticProfilePicUrl = "https://firebasestorage.googleapis.com/v0/b/pingbear-96b4c-us/o/success-bot-logo%2Fbb.png?alt=media&token=c8bbc569-b5b1-412a-bd8a-786105162bce"
        
        // Fetch winner's username
        db.collection("users").document(winnerUserId).getDocument { [weak self] userDoc, userError in
            guard let self = self else { return }
            
            let winnerName = userDoc?.data()?["username"] as? String ?? "Someone"
            let predictionText = predictionCount == 1 ? "prediction" : "predictions"
            let messageText = "\(winnerName) just won \(payout) coins on \(predictionCount) \(predictionText)!"
            
            let messageId = UUID().uuidString
            
            let messageData: [String: Any] = [
                "senderId": systemUserId,
                "senderName": "SocialStar",
                "senderProfilePicture": staticProfilePicUrl,
                "text": messageText,
                "timestamp": FieldValue.serverTimestamp(),
                "isRead": false
            ]
            
            let messageRef = self.db.collection("competitions")
                .document(competitionId)
                .collection("messages")
                .document(messageId)
            
            messageRef.setData(messageData) { error in
                if let error = error {
                    print("ParlayManager: Failed to send parlay win message: \(error)")
                } else {
                    print("ParlayManager: Parlay win message sent successfully for \(winnerName)")
                }
            }
        }
    }
}

// MARK: - Public Helper Methods

extension ParlayManager {
    
    // Get parlay status for a specific entry (useful for UI)
    func getParlayStatus(competitionId: String, entryId: String, completion: @escaping (String?) -> Void) {
        let entryRef = db.collection("competitions").document(competitionId).collection("entries").document(entryId)
        
        entryRef.getDocument { document, error in
            if let error = error {
                print("ParlayManager: Error fetching parlay status: \(error)")
                completion(nil)
                return
            }
            
            guard let data = document?.data() else {
                completion(nil)
                return
            }
            
            let status = data["parlayStatus"] as? String
            completion(status)
        }
    }
    
    // Get pending raters for a parlay (useful for UI)
    func getPendingRaters(competitionId: String, entryId: String, completion: @escaping ([String]) -> Void) {
        let entryRef = db.collection("competitions").document(competitionId).collection("entries").document(entryId)
        
        entryRef.getDocument { document, error in
            if let error = error {
                print("ParlayManager: Error fetching pending raters: \(error)")
                completion([])
                return
            }
            
            guard let data = document?.data(),
                  let predictions = data["predictions"] as? [String: Any] else {
                completion([])
                return
            }
            
            var pendingRaters: [String] = []
            
            for (userId, predictionData) in predictions {
                if let prediction = predictionData as? [String: Any],
                   prediction["actualRating"] == nil {
                    pendingRaters.append(userId)
                }
            }
            
            completion(pendingRaters)
        }
    }
}
