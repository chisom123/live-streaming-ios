import Foundation
import FirebaseFirestore
import FirebaseAuth

class GlobalLeaderboardManager: ObservableObject {
    static let shared = GlobalLeaderboardManager()
    
    // MARK: - Published Properties
    @Published var isLoading: Bool = false
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private var configListener: ListenerRegistration?
    
    // Cached config values
    private var cachedConfig: GlobalLeaderboardConfig?
    
    // MARK: - Config Structure
    struct GlobalLeaderboardConfig {
        let potMaxParticipants: Int
        let firstPlacePrize: Double
        let decayRate: Double
        let minPayout: Double
        
        static var `default`: GlobalLeaderboardConfig {
            return GlobalLeaderboardConfig(
                potMaxParticipants: 1000,
                firstPlacePrize: 100.0,
                decayRate: 0.0,
                minPayout: 0.01
            )
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupRealtimeListener()
    }
    
    deinit {
        configListener?.remove()
    }
    
    // MARK: - Real-time Configuration Listener
    private func setupRealtimeListener() {
        configListener?.remove()
        
        configListener = db.collection("app_config").document("global_leaderboard")
            .addSnapshotListener { [weak self] documentSnapshot, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("GlobalLeaderboard: Error listening to config: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let document = documentSnapshot, document.exists else {
                        print("GlobalLeaderboard: Config document does not exist, using defaults")
                        self.cachedConfig = .default
                        return
                    }
                    
                    self.updateConfigFromDocument(document)
                }
            }
    }
    
    private func updateConfigFromDocument(_ document: DocumentSnapshot) {
        let data = document.data() ?? [:]
        
        let config = GlobalLeaderboardConfig(
            potMaxParticipants: data["pot_max_participants"] as? Int ?? 1000,
            firstPlacePrize: data["first_place_prize"] as? Double ?? 100.0,
            decayRate: data["decay_rate"] as? Double ?? 0.0,
            minPayout: data["min_payout"] as? Double ?? 0.01
        )
        
        self.cachedConfig = config
        
        print("✅ GlobalLeaderboard: Config updated - Pot Size: \(config.potMaxParticipants), Prize: $\(config.firstPlacePrize)")
    }
    
    private func getConfig() -> GlobalLeaderboardConfig {
        return cachedConfig ?? .default
    }
    
    // MARK: - Main Entry Point
    
    /// Handle star being awarded to a user (photo owner)
    /// This is called after a successful rating
    func handleStarAwarded(
        userId: String,
        stars: Int,
        competitionId: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard stars > 0 else {
            print("GlobalLeaderboard: No stars awarded, skipping")
            completion(true)
            return
        }
        
        print("GlobalLeaderboard: Processing \(stars) stars for user \(userId)")
        
        // Check if user is already in an active pot
        checkUserActivePot(userId: userId) { [weak self] activePotId in
            guard let self = self else {
                completion(false)
                return
            }
            
            if let potId = activePotId {
                // User already in active pot - just add stars (fast path)
                self.addStarsToExistingPot(
                    userId: userId,
                    potId: potId,
                    stars: stars,
                    completion: completion
                )
            } else {
                // User not in active pot - need to join one (slower path)
                self.joinPotAndAddStars(
                    userId: userId,
                    stars: stars,
                    completion: completion
                )
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Check if user has an active pot and if it's still valid
    private func checkUserActivePot(userId: String, completion: @escaping (String?) -> Void) {
        db.collection("users").document(userId).getDocument { [weak self] document, error in
            guard let self = self else {
                completion(nil)
                return
            }
            
            if let error = error {
                print("GlobalLeaderboard: Error checking user pot status: \(error)")
                completion(nil)
                return
            }
            
            guard let potId = document?.data()?["active_pot_id"] as? String else {
                // User has no pot assigned
                completion(nil)
                return
            }
            
            // Verify pot is still active
            self.db.collection("global_pots").document(potId).getDocument { potDoc, error in
                if let error = error {
                    print("GlobalLeaderboard: Error checking pot validity: \(error)")
                    completion(nil)
                    return
                }
                
                guard let data = potDoc?.data(),
                      let status = data["status"] as? String,
                      status == "active",
                      let endDate = (data["end_date"] as? Timestamp)?.dateValue(),
                      Date() < endDate else {
                    // Pot expired, closed, or doesn't exist
                    print("GlobalLeaderboard: User's pot \(potId) is no longer active")
                    completion(nil)
                    return
                }
                
                // Pot is valid and active
                completion(potId)
            }
        }
    }
    
    /// Add stars to user's existing active pot (fast path - no transaction needed)
    private func addStarsToExistingPot(
        userId: String,
        potId: String,
        stars: Int,
        completion: @escaping (Bool) -> Void
    ) {
        let participantRef = db.collection("global_pots")
            .document(potId)
            .collection("participants")
            .document(userId)
        
        let updateData: [String: Any] = [
            "total_stars": FieldValue.increment(Int64(stars)),
            "last_star_at": FieldValue.serverTimestamp()
        ]
        
        participantRef.updateData(updateData) { error in
            if let error = error {
                print("GlobalLeaderboard: Error adding stars to pot: \(error)")
                completion(false)
            } else {
                print("GlobalLeaderboard: ✅ Added \(stars) stars to user \(userId) in pot \(potId)")
                completion(true)
            }
        }
    }
    
    /// Join a pot and add stars (slower path - uses transaction)
    private func joinPotAndAddStars(
        userId: String,
        stars: Int,
        completion: @escaping (Bool) -> Void
    ) {
        // Run transaction to atomically join pot
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                // 1. Get current pot reference
                let currentPotRef = self.db.collection("app_config").document("current_pot")
                let currentPotDoc = try transaction.getDocument(currentPotRef)
                
                // 2. Determine which pot to use
                let potId = try self.getOrCreatePot(
                    transaction: transaction,
                    currentPotDoc: currentPotDoc
                )
                
                // 3. Add user to pot
                let participantRef = self.db.collection("global_pots")
                    .document(potId)
                    .collection("participants")
                    .document(userId)
                
                let participantData: [String: Any] = [
                    "user_id": userId,
                    "total_stars": stars,
                    "last_star_at": FieldValue.serverTimestamp(),
                    "joined_at": FieldValue.serverTimestamp()
                ]
                
                transaction.setData(participantData, forDocument: participantRef)
                
                // 4. Increment pot participant count
                let potRef = self.db.collection("global_pots").document(potId)
                transaction.updateData([
                    "participant_count": FieldValue.increment(Int64(1))
                ], forDocument: potRef)
                
                // 5. Update current pot reference count
                transaction.updateData([
                    "participant_count": FieldValue.increment(Int64(1))
                ], forDocument: currentPotRef)
                
                // 6. Update user's active pot
                let userRef = self.db.collection("users").document(userId)
                transaction.updateData([
                    "active_pot_id": potId
                ], forDocument: userRef)
                
                return potId
                
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }) { (potId, error) in
            if let error = error {
                print("GlobalLeaderboard: ❌ Error joining pot: \(error)")
                completion(false)
            } else if let potId = potId as? String {
                print("GlobalLeaderboard: ✅ User \(userId) joined pot \(potId) with \(stars) stars")
                completion(true)
            } else {
                completion(false)
            }
        }
    }
    
    /// Get current pot or create new one if needed (called within transaction)
    private func getOrCreatePot(
        transaction: Transaction,
        currentPotDoc: DocumentSnapshot
    ) throws -> String {
        let config = getConfig()
        
        // Check if current pot exists and is valid
        if let data = currentPotDoc.data(),
           let potId = data["pot_id"] as? String,
           let endDate = (data["end_date"] as? Timestamp)?.dateValue(),
           Date() < endDate {
            
            // Read the actual pot document to get real-time count and max
            let potRef = db.collection("global_pots").document(potId)
            let potDoc = try transaction.getDocument(potRef)
            
            if let potData = potDoc.data(),
               let status = potData["status"] as? String,
               status == "active",
               let currentCount = potData["participant_count"] as? Int,
               let maxParticipants = potData["max_participants"] as? Int,
               currentCount < maxParticipants {
                
                print("GlobalLeaderboard: Using existing pot \(potId) (count: \(currentCount)/\(maxParticipants))")
                return potId
            }
            
            print("GlobalLeaderboard: Current pot full, expired, or closed - creating new pot")
        }
        
        // Calculate end date ONCE for both pot and reference
        let now = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        
        // Create new pot with this end date
        let newPotId = try createNewPotInTransaction(
            transaction: transaction,
            endDate: endDate
        )
        
        // Update current pot reference with SAME end date
        let currentPotRef = db.collection("app_config").document("current_pot")
        transaction.setData([
            "pot_id": newPotId,
            "participant_count": 0,
            "end_date": Timestamp(date: endDate),
            "updated_at": FieldValue.serverTimestamp()
        ], forDocument: currentPotRef)
        
        return newPotId
    }
    
    /// Create a new pot (called within transaction)
    private func createNewPotInTransaction(
        transaction: Transaction,
        endDate: Date
    ) throws -> String {
        let config = getConfig()
        let potRef = db.collection("global_pots").document()
        let potId = potRef.documentID
        
        let now = Date()
        
        let potData: [String: Any] = [
            "pot_id": potId,
            "start_date": Timestamp(date: now),
            "end_date": Timestamp(date: endDate),
            "status": "active",
            "max_participants": config.potMaxParticipants,
            "first_place_prize": config.firstPlacePrize,
            "decay_rate": config.decayRate,
            "min_payout": config.minPayout,
            "participant_count": 0,
            "created_at": FieldValue.serverTimestamp()
        ]
        
        transaction.setData(potData, forDocument: potRef)
        
        print("GlobalLeaderboard: 🎉 Created new pot \(potId), ends: \(endDate)")
        
        return potId
    }
}
