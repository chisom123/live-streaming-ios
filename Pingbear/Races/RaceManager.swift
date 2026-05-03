import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

class RaceManager {
    static let shared = RaceManager()
    private let db = Firestore.firestore()

    private init() {}

    // ─────────────────────────────────────────────────────────────
    // MARK: - Main Entry Point
    // ─────────────────────────────────────────────────────────────

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

        checkActiveRace(competitionId: competitionId) { [weak self] raceId in
            guard let self else { completion(false); return }

            if let raceId {
                self.addStarsToRace(
                    raceId: raceId,
                    competitionId: competitionId,
                    userId: photoOwnerId,
                    stars: stars,
                    completion: completion
                )
            } else {
                self.createRaceAndAddStars(
                    competitionId: competitionId,
                    userId: photoOwnerId,
                    stars: stars,
                    completion: completion
                )
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Check Active Race
    // ─────────────────────────────────────────────────────────────

    private func checkActiveRace(
        competitionId: String,
        completion: @escaping (String?) -> Void
    ) {
        db.collection("competition_races")
            .whereField("competition_id", isEqualTo: competitionId)
            .whereField("status", isEqualTo: "active")
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error {
                    print("RaceManager: Error checking active race: \(error)")
                    completion(nil)
                    return
                }

                guard let doc = snapshot?.documents.first,
                      let endDate = (doc.data()["end_date"] as? Timestamp)?.dateValue(),
                      Date() < endDate else {
                    completion(nil)
                    return
                }

                completion(doc.documentID)
            }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Add Stars To Existing Race
    // ─────────────────────────────────────────────────────────────

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
            guard let self else { completion(false); return }

            if document?.exists == true {
                let batch = self.db.batch()
                let raceRef = self.db.collection("competition_races").document(raceId)

                batch.updateData([
                    "total_stars": FieldValue.increment(Int64(stars))
                ], forDocument: participantRef)

                batch.updateData([
                    "total_stars": FieldValue.increment(Int64(stars))
                ], forDocument: raceRef)

                batch.commit { error in
                    if let error {
                        print("RaceManager: Error updating stars: \(error)")
                        completion(false)
                    } else {
                        print("RaceManager: ✅ Updated \(stars) stars for user \(userId) in race \(raceId)")
                        // Record stars earned for photo owner — unlocks welcome bonus
                        // Uses Cloud Function because Firestore rules block cross-user writes
                        self.recordStarsEarned(photoOwnerId: userId)
                        completion(true)
                    }
                }
            } else {
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

    // ─────────────────────────────────────────────────────────────
    // MARK: - Add User To Existing Race
    // ─────────────────────────────────────────────────────────────

    private func addUserToRace(
        raceId: String,
        competitionId: String,
        userId: String,
        stars: Int,
        completion: @escaping (Bool) -> Void
    ) {
        db.runTransaction({ [weak self] transaction, errorPointer -> Any? in
            guard let self else { return nil }

            do {
                let raceRef = self.db.collection("competition_races").document(raceId)
                let raceDoc = try transaction.getDocument(raceRef)

                guard raceDoc.data() != nil else {
                    throw NSError(domain: "RaceManager", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Race not found"])
                }

                let participantRef = self.db.collection("competition_races")
                    .document(raceId)
                    .collection("race_participants")
                    .document(userId)

                transaction.setData([
                    "user_id":       userId,
                    "total_stars":   stars,
                    "joined_at":     FieldValue.serverTimestamp(),
                    "payout_amount": 0.0
                ], forDocument: participantRef)

                transaction.updateData([
                    "participant_count": FieldValue.increment(Int64(1)),
                    "total_stars":       FieldValue.increment(Int64(stars))
                ], forDocument: raceRef)

                return nil
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }) { [weak self] _, error in
            if let error {
                print("RaceManager: ❌ Error adding user to race: \(error)")
                completion(false)
            } else {
                print("RaceManager: ✅ Added user \(userId) to race \(raceId)")
                // Record stars earned for photo owner — unlocks welcome bonus
                self?.recordStarsEarned(photoOwnerId: userId)
                completion(true)
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Create Race And Add Stars
    // ─────────────────────────────────────────────────────────────

    private func createRaceAndAddStars(
        competitionId: String,
        userId: String,
        stars: Int,
        completion: @escaping (Bool) -> Void
    ) {
        Functions.functions()
            .httpsCallable("getOrCreateRaceForCompetition")
            .call(["competitionId": competitionId]) { [weak self] result, error in
                guard let self else { completion(false); return }

                if let error {
                    print("RaceManager: ❌ Error creating race: \(error)")
                    completion(false)
                    return
                }

                guard let data = result?.data as? [String: Any],
                      let raceId = data["race_id"] as? String else {
                    print("RaceManager: ❌ Invalid response from getOrCreateRaceForCompetition")
                    completion(false)
                    return
                }

                print("RaceManager: ✅ Race \(raceId) ready for competition \(competitionId)")

                self.addStarsToRace(
                    raceId: raceId,
                    competitionId: competitionId,
                    userId: userId,
                    stars: stars,
                    completion: completion
                )
            }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Record Stars Earned
    //
    // Called after photo owner earns stars in a race.
    // Calls the recordStarsEarned Cloud Function which sets
    // has_earned_stars: true on the photo owner's user document
    // using admin privileges — necessary because Firestore rules
    // block one user writing to another user's document.
    //
    // If both has_earned_stars and total_contributed >= $5,
    // the Cloud Function also flips welcome_bonus_unlocked: true.
    // ─────────────────────────────────────────────────────────────

    private func recordStarsEarned(photoOwnerId: String) {
        Functions.functions()
            .httpsCallable("recordStarsEarned")
            .call(["photoOwnerId": photoOwnerId]) { _, error in
                if let error {
                    print("RaceManager: ⚠️ recordStarsEarned failed: \(error.localizedDescription)")
                } else {
                    print("RaceManager: ✅ Stars recorded for photo owner \(photoOwnerId)")
                }
            }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Fetch Current Race (used by UI)
    // ─────────────────────────────────────────────────────────────

    func fetchCurrentRace(
        competitionId: String,
        completion: @escaping (RaceInfo?) -> Void
    ) {
        db.collection("competition_races")
            .whereField("competition_id", isEqualTo: competitionId)
            .whereField("status", isEqualTo: "active")
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error {
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
                completion(RaceInfo(
                    raceId:           doc.documentID,
                    competitionId:    competitionId,
                    duration:         data["duration"] as? String ?? "weekly",
                    endDate:          endDate,
                    participantCount: data["participant_count"] as? Int ?? 0,
                    totalPot:         data["total_pot"] as? Double ?? 0.0,
                    totalStars:       data["total_stars"] as? Int ?? 0
                ))
            }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Fetch Race Participants (used by UI)
    // ─────────────────────────────────────────────────────────────

    func fetchRaceParticipants(
        raceId: String,
        completion: @escaping ([RaceParticipant]) -> Void
    ) {
        db.collection("competition_races")
            .document(raceId)
            .collection("race_participants")
            .order(by: "total_stars", descending: true)
            .getDocuments { snapshot, error in
                if let error {
                    print("RaceManager: Error fetching participants: \(error)")
                    completion([])
                    return
                }

                let participants = snapshot?.documents.compactMap { doc -> RaceParticipant? in
                    let data = doc.data()
                    return RaceParticipant(
                        userId:       doc.documentID,
                        totalStars:   data["total_stars"] as? Int ?? 0,
                        payoutAmount: data["payout_amount"] as? Double ?? 0.0
                    )
                } ?? []

                completion(participants)
            }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Models
// ─────────────────────────────────────────────────────────────

struct RaceInfo {
    let raceId:           String
    let competitionId:    String
    let duration:         String
    let endDate:          Date
    let participantCount: Int
    let totalPot:         Double
    let totalStars:       Int
}

struct RaceParticipant {
    let userId:       String
    let totalStars:   Int
    let payoutAmount: Double
}
