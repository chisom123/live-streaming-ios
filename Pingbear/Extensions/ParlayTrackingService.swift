import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Parlay Progress Data Structures
struct ParlayProgress {
    let entryId: String
    let userId: String
    let competitionId: String
    let entryCost: Int
    let potentialPayout: Int
    let predictions: [String: Int]
    var actualRatings: [String: Int]
    var isResolved: Bool
    var didWin: Bool
    var actualPayout: Int
    
    // Computed properties for tracking
    var totalPredictions: Int { predictions.count }
    var completedRatings: Int { actualRatings.count }
    var remainingPredictions: [String] {
        predictions.keys.filter { !actualRatings.keys.contains($0) }
    }
    var progressPercentage: Double {
        totalPredictions > 0 ? Double(completedRatings) / Double(totalPredictions) : 0
    }
}

struct ParlayPayout {
    let entryId: String
    let userId: String
    let amount: Int
    let wasWinning: Bool
    let completedAt: Date
}

// MARK: - Parlay Tracking Service
class ParlayTrackingService: ObservableObject {
    static let shared = ParlayTrackingService()
    
    private let db = Firestore.firestore()
    private let calculator = CompetitionPricingCalculator.shared
    
    @Published var userParlays: [ParlayProgress] = []
    @Published var isLoading = false
    
    private init() {}
    
    // MARK: - Monitor User's Parlays
    func startMonitoringUserParlays(competitionId: String, userId: String) {
        isLoading = true
        
        // Listen for entries by this user that are parlay type
        db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .whereField("userId", isEqualTo: userId)
            .whereField("entryType", isEqualTo: "parlay")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                
                if let error = error {
                    print("Error monitoring parlays: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let parlays = documents.compactMap { doc -> ParlayProgress? in
                    self.parseParlayFromDocument(doc, competitionId: competitionId)
                }
                
                DispatchQueue.main.async {
                    self.userParlays = parlays
                    
                    // Check each parlay for completion
                    for parlay in parlays {
                        if !parlay.isResolved {
                            self.checkParlayCompletion(parlay)
                        }
                    }
                }
            }
    }
    
    // MARK: - Track New Rating for Parlay System
    func trackNewRating(competitionId: String, entryId: String, raterId: String, rating: Int) {
        // First check if this entry is a parlay entry
        db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .document(entryId)
            .getDocument { [weak self] document, error in
                guard let self = self,
                      let document = document,
                      let data = document.data(),
                      data["entryType"] as? String == "parlay" else {
                    return
                }
                
                // Update the actual ratings for this parlay
                self.updateParlayRating(
                    competitionId: competitionId,
                    entryId: entryId,
                    raterId: raterId,
                    rating: rating,
                    entryData: data
                )
            }
    }
    
    // MARK: - Update Parlay Rating
    private func updateParlayRating(competitionId: String, entryId: String, raterId: String, rating: Int, entryData: [String: Any]) {
        // Update the actualRatings map in the entry document
        let entryRef = db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .document(entryId)
        
        let actualRatingsPath = "actualRatings.\(raterId)"
        
        entryRef.updateData([
            actualRatingsPath: rating
        ]) { [weak self] error in
            if let error = error {
                print("Error updating parlay rating: \(error)")
                return
            }
            
            // Check if this completes the parlay
            self?.checkParlayCompletionAfterRating(
                competitionId: competitionId,
                entryId: entryId,
                entryData: entryData
            )
        }
    }
    
    // MARK: - Check Parlay Completion
    private func checkParlayCompletion(_ parlay: ParlayProgress) {
        checkParlayCompletionById(
            competitionId: parlay.competitionId,
            entryId: parlay.entryId
        )
    }
    
    private func checkParlayCompletionAfterRating(competitionId: String, entryId: String, entryData: [String: Any]) {
        checkParlayCompletionById(competitionId: competitionId, entryId: entryId)
    }
    
    private func checkParlayCompletionById(competitionId: String, entryId: String) {
        db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .document(entryId)
            .getDocument { [weak self] document, error in
                guard let self = self,
                      let document = document,
                      let data = document.data(),
                      data["entryType"] as? String == "parlay",
                      let predictions = data["predictions"] as? [String: Int] else {
                    return
                }
                
                let actualRatings = data["actualRatings"] as? [String: Int] ?? [:]
                let isResolved = data["parlayResolved"] as? Bool ?? false
                
                // Check if all predictions have been rated
                if !isResolved && actualRatings.count == predictions.count {
                    self.resolveParlayBet(
                        competitionId: competitionId,
                        entryId: entryId,
                        entryData: data,
                        predictions: predictions,
                        actualRatings: actualRatings
                    )
                }
            }
    }
    
    // MARK: - Resolve Parlay Bet
    private func resolveParlayBet(competitionId: String, entryId: String, entryData: [String: Any], predictions: [String: Int], actualRatings: [String: Int]) {
        
        guard let userId = entryData["userId"] as? String,
              let entryCost = entryData["entryCost"] as? Int,
              let potentialPayout = entryData["potentialPayout"] as? Int else {
            print("Error: Missing required parlay data")
            return
        }
        
        // Evaluate if the parlay won
        let parlayWon = calculator.evaluateParlayBet(
            predictions: predictions,
            actualRatings: actualRatings
        )
        
        let actualPayout = parlayWon ? potentialPayout : 0
        
        // Update the entry document
        let entryRef = db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .document(entryId)
        
        let batch = db.batch()
        
        // Mark parlay as resolved
        batch.updateData([
            "parlayResolved": true,
            "parlayWon": parlayWon,
            "actualPayout": actualPayout,
            "resolvedAt": FieldValue.serverTimestamp()
        ], forDocument: entryRef)
        
        // If parlay won, award coins to user
        if parlayWon && actualPayout > 0 {
            let memberRef = db.collection("competitions")
                .document(competitionId)
                .collection("members")
                .document(userId)
            
            batch.updateData([
                "coins": FieldValue.increment(Int64(actualPayout))
            ], forDocument: memberRef)
            
            print("🎉 Parlay won! Awarding \(actualPayout) coins to user \(userId)")
        } else {
            print("💔 Parlay lost. No payout for user \(userId)")
        }
        
        // Commit the batch
        batch.commit { [weak self] error in
            if let error = error {
                print("Error resolving parlay: \(error)")
                return
            }
            
            print("✅ Parlay resolved successfully")
            
            // Track analytics
            Analytics.shared.track(
                event: "parlay_resolved",
                properties: [
                    "entry_id": entryId,
                    "won": parlayWon,
                    "payout": actualPayout,
                    "predictions_count": predictions.count,
                    "entry_cost": entryCost
                ]
            )
            
            // Send notification to user about parlay result
            self?.sendParlayResultNotification(
                competitionId: competitionId,
                userId: userId,
                won: parlayWon,
                payout: actualPayout,
                predictions: predictions,
                actualRatings: actualRatings
            )
        }
    }
    
    // MARK: - Get Parlay Progress for Entry
    func getParlayProgress(competitionId: String, entryId: String, completion: @escaping (ParlayProgress?) -> Void) {
        db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .document(entryId)
            .getDocument { document, error in
                if let error = error {
                    print("Error fetching parlay progress: \(error)")
                    completion(nil)
                    return
                }
                
                guard let document = document, document.exists else {
                    completion(nil)
                    return
                }
                
                let progress = self.parseParlayFromDocumentSnapshot(document, competitionId: competitionId)
                completion(progress)
            }
    }
    
    // MARK: - Helper Methods
    private func parseParlayFromDocument(_ document: QueryDocumentSnapshot, competitionId: String) -> ParlayProgress? {
        let data = document.data()
        
        guard data["entryType"] as? String == "parlay",
              let userId = data["userId"] as? String,
              let entryCost = data["entryCost"] as? Int,
              let potentialPayout = data["potentialPayout"] as? Int,
              let predictions = data["predictions"] as? [String: Int] else {
            return nil
        }
        
        let actualRatings = data["actualRatings"] as? [String: Int] ?? [:]
        let isResolved = data["parlayResolved"] as? Bool ?? false
        let didWin = data["parlayWon"] as? Bool ?? false
        let actualPayout = data["actualPayout"] as? Int ?? 0
        
        return ParlayProgress(
            entryId: document.documentID,
            userId: userId,
            competitionId: competitionId,
            entryCost: entryCost,
            potentialPayout: potentialPayout,
            predictions: predictions,
            actualRatings: actualRatings,
            isResolved: isResolved,
            didWin: didWin,
            actualPayout: actualPayout
        )
    }
    
    // Separate method for DocumentSnapshot (used in getParlayProgress)
    private func parseParlayFromDocumentSnapshot(_ document: DocumentSnapshot, competitionId: String) -> ParlayProgress? {
        guard let data = document.data() else { return nil }
        
        guard data["entryType"] as? String == "parlay",
              let userId = data["userId"] as? String,
              let entryCost = data["entryCost"] as? Int,
              let potentialPayout = data["potentialPayout"] as? Int,
              let predictions = data["predictions"] as? [String: Int] else {
            return nil
        }
        
        let actualRatings = data["actualRatings"] as? [String: Int] ?? [:]
        let isResolved = data["parlayResolved"] as? Bool ?? false
        let didWin = data["parlayWon"] as? Bool ?? false
        let actualPayout = data["actualPayout"] as? Int ?? 0
        
        return ParlayProgress(
            entryId: document.documentID,
            userId: userId,
            competitionId: competitionId,
            entryCost: entryCost,
            potentialPayout: potentialPayout,
            predictions: predictions,
            actualRatings: actualRatings,
            isResolved: isResolved,
            didWin: didWin,
            actualPayout: actualPayout
        )
    }
    
    private func sendParlayResultNotification(competitionId: String, userId: String, won: Bool, payout: Int, predictions: [String: Int], actualRatings: [String: Int]) {
        // This would integrate with your existing notification system
        // For now, just print the result
        if won {
            print("🎉 PARLAY WON! User earned \(payout) coins!")
        } else {
            print("💔 Parlay lost. Better luck next time!")
            
            // Show which predictions were wrong
            for (raterId, predictedRating) in predictions {
                if let actualRating = actualRatings[raterId], actualRating != predictedRating {
                    print("❌ Predicted \(predictedRating)⭐ but got \(actualRating)⭐ from \(raterId)")
                }
            }
        }
    }
}

// MARK: - Extension for Easy Integration
extension ParlayTrackingService {
    
    // Call this when a rating is submitted in FullScreenPhotoView
    func onRatingSubmitted(competitionId: String, entryId: String, raterId: String, rating: Int) {
        trackNewRating(
            competitionId: competitionId,
            entryId: entryId,
            raterId: raterId,
            rating: rating
        )
    }
    
    // Get live parlay data for UI display
    func getParlayDisplayData(for entryId: String) -> ParlayProgress? {
        return userParlays.first { $0.entryId == entryId }
    }
}
