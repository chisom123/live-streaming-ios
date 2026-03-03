import Foundation
import FirebaseFirestore
import FirebaseAuth

class RaceManager {
    static let shared = RaceManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Constants
    private let raceDurationHours: Double = 24
    private let pointsPerParticipant: Int = 200
    
    // MARK: - Main Entry Point
    
    /// Called when a photo receives a rating
    /// This handles creating/joining a race and updating star counts
    func handleRatingReceived(
        competitionId: String,
        photoOwnerId: String,
        stars: Int,
        completion: @escaping (Bool) -> Void
    ) {
        guard stars > 0 else {
            completion(true)
            return
        }
        
        print("RaceManager: Handling \(stars) stars for user \(photoOwnerId) in competition \(competitionId)")
        
        // Check if there's an active race for this competition
        checkActiveRace(competitionId: competitionId) { [weak self] raceId in
            guard let self = self else {
                completion(false)
                return
            }
            
            if let raceId = raceId {
                // Active race exists - add stars
                self.addStarsToRace(
                    raceId: raceId,
                    competitionId: competitionId,
                    userId: photoOwnerId,
                    stars: stars,
                    completion: completion
                )
            } else {
                // No active race - create one and add stars
                self.createRaceAndAddStars(
                    competitionId: competitionId,
                    userId: photoOwnerId,
                    stars: stars,
                    completion: completion
                )
            }
        }
    }
    
    // MARK: - Check Active Race
    
    private func checkActiveRace(
        competitionId: String,
        completion: @escaping (String?) -> Void
    ) {
        let now = Date()
        
        db.collection("competition_races")
            .whereField("competition_id", isEqualTo: competitionId)
            .whereField("status", isEqualTo: "active")
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("RaceManager: Error checking active race: \(error)")
                    completion(nil)
                    return
                }
                
                guard let doc = snapshot?.documents.first else {
                    completion(nil)
                    return
                }
                
                // Verify race hasn't expired
                guard let endDate = (doc.data()["end_date"] as? Timestamp)?.dateValue(),
                      now < endDate else {
                    print("RaceManager: Race expired but not yet closed by Cloud Function")
                    completion(nil)
                    return
                }
                
                completion(doc.documentID)
            }
    }
    
    // MARK: - Add Stars To Existing Race
    
    private func addStarsToRace(
        raceId: String,
        competitionId: String,
        userId: String,
        stars: Int,
        completion: @escaping (Bool) -> Void
    ) {
        let participantRef = db.collection("competition_races")
            .document(raceId)
            .collection("race_participants")
            .document(userId)
        
        participantRef.getDocument { [weak self] document, error in
            guard let self = self else {
                completion(false)
                return
            }
            
            if document?.exists == true {
                // User already in race - just increment stars
                let batch = self.db.batch()
                
                batch.updateData([
                    "total_stars": FieldValue.increment(Int64(stars))
                ], forDocument: participantRef)
                
                // Update race total stars and points pool
                let raceRef = self.db.collection("competition_races").document(raceId)
                batch.updateData([
                    "total_stars": FieldValue.increment(Int64(stars))
                ], forDocument: raceRef)
                
                batch.commit { error in
                    if let error = error {
                        print("RaceManager: Error updating stars: \(error)")
                        completion(false)
                    } else {
                        print("RaceManager: ✅ Updated \(stars) stars for user \(userId) in race \(raceId)")
                        completion(true)
                    }
                }
            } else {
                // User not yet in race - add them
                self.addUserToRace(
                    raceId: raceId,
                    competitionId: competitionId,
                    userId: userId,
                    stars: stars,
                    completion: completion
                )
            }
        }
    }
    
    // MARK: - Add User To Race
    
    private func addUserToRace(
        raceId: String,
        competitionId: String,
        userId: String,
        stars: Int,
        completion: @escaping (Bool) -> Void
    ) {
        db.runTransaction({ [weak self] transaction, errorPointer -> Any? in
            guard let self = self else { return nil }
            
            do {
                let raceRef = self.db.collection("competition_races").document(raceId)
                let raceDoc = try transaction.getDocument(raceRef)
                
                guard let raceData = raceDoc.data() else {
                    throw NSError(domain: "RaceManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Race not found"])
                }
                
                let currentParticipantCount = raceData["participant_count"] as? Int ?? 0
                let newParticipantCount = currentParticipantCount + 1
                let newPointsPool = newParticipantCount * self.pointsPerParticipant
                
                // Add participant
                let participantRef = self.db.collection("competition_races")
                    .document(raceId)
                    .collection("race_participants")
                    .document(userId)
                
                transaction.setData([
                    "user_id": userId,
                    "total_stars": stars,
                    "joined_at": FieldValue.serverTimestamp()
                ], forDocument: participantRef)
                
                // Update race
                transaction.updateData([
                    "participant_count": newParticipantCount,
                    "points_pool": newPointsPool,
                    "total_stars": FieldValue.increment(Int64(stars))
                ], forDocument: raceRef)
                
                return nil
                
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }) { _, error in
            if let error = error {
                print("RaceManager: ❌ Error adding user to race: \(error)")
                completion(false)
            } else {
                print("RaceManager: ✅ Added user \(userId) to race \(raceId)")
                completion(true)
            }
        }
    }
    
    // MARK: - Create Race And Add Stars
    
    private func createRaceAndAddStars(
        competitionId: String,
        userId: String,
        stars: Int,
        completion: @escaping (Bool) -> Void
    ) {
        db.runTransaction({ [weak self] transaction, errorPointer -> Any? in
            guard let self = self else { return nil }
            
            do {
                // Double check no race was created in the meantime
                // (transaction handles this atomically)
                let now = Date()
                let endDate = Calendar.current.date(
                    byAdding: .hour,
                    value: Int(self.raceDurationHours),
                    to: now
                ) ?? now
                
                let raceRef = self.db.collection("competition_races").document()
                let participantRef = raceRef.collection("race_participants").document(userId)
                
                // Create race
                transaction.setData([
                    "competition_id": competitionId,
                    "status": "active",
                    "start_date": Timestamp(date: now),
                    "end_date": Timestamp(date: endDate),
                    "participant_count": 1,
                    "points_pool": self.pointsPerParticipant,
                    "total_stars": stars,
                    "created_at": FieldValue.serverTimestamp()
                ], forDocument: raceRef)
                
                // Add first participant
                transaction.setData([
                    "user_id": userId,
                    "total_stars": stars,
                    "joined_at": FieldValue.serverTimestamp()
                ], forDocument: participantRef)
                
                return raceRef.documentID
                
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }) { raceId, error in
            if let error = error {
                print("RaceManager: ❌ Error creating race: \(error)")
                completion(false)
            } else {
                print("RaceManager: 🎉 Created new race \(raceId ?? "") for competition \(competitionId)")
                completion(true)
            }
        }
    }
    
    // MARK: - Fetch Current Race
    
    /// Fetch the current active race for a competition (used by UI)
    func fetchCurrentRace(
        competitionId: String,
        completion: @escaping (RaceInfo?) -> Void
    ) {
        db.collection("competition_races")
            .whereField("competition_id", isEqualTo: competitionId)
            .whereField("status", isEqualTo: "active")
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("RaceManager: Error fetching race: \(error)")
                    completion(nil)
                    return
                }
                
                guard let doc = snapshot?.documents.first,
                      let endDate = (doc.data()["end_date"] as? Timestamp)?.dateValue(),
                      Date() < endDate else {
                    completion(nil)
                    return
                }
                
                let data = doc.data()
                let race = RaceInfo(
                    raceId: doc.documentID,
                    competitionId: competitionId,
                    endDate: endDate,
                    participantCount: data["participant_count"] as? Int ?? 0,
                    pointsPool: data["points_pool"] as? Int ?? 0,
                    totalStars: data["total_stars"] as? Int ?? 0
                )
                
                completion(race)
            }
    }
    
    // MARK: - Fetch Race Participants
    
    /// Fetch participants for the current race (used by UI)
    func fetchRaceParticipants(
        raceId: String,
        completion: @escaping ([RaceParticipant]) -> Void
    ) {
        db.collection("competition_races")
            .document(raceId)
            .collection("race_participants")
            .order(by: "total_stars", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("RaceManager: Error fetching participants: \(error)")
                    completion([])
                    return
                }
                
                let participants = snapshot?.documents.compactMap { doc -> RaceParticipant? in
                    let data = doc.data()
                    return RaceParticipant(
                        userId: doc.documentID,
                        totalStars: data["total_stars"] as? Int ?? 0
                    )
                } ?? []
                
                completion(participants)
            }
    }
}

// MARK: - Models

struct RaceInfo {
    let raceId: String
    let competitionId: String
    let endDate: Date
    let participantCount: Int
    let pointsPool: Int
    let totalStars: Int
}

struct RaceParticipant {
    let userId: String
    let totalStars: Int
}
