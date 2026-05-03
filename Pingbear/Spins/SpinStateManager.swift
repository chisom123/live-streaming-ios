import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Manages spin state persistence for the slot machine rating system
class SpinStateManager {
    static let shared = SpinStateManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Load Spin State
    
    /// Load saved spin state for a user and entry
    /// - Parameters:
    ///   - competitionId: The competition ID
    ///   - entryId: The entry ID
    ///   - userId: The user ID (defaults to current user)
    ///   - completion: Returns array of SpinResults if found, empty array if none
    func loadSpinState(
        competitionId: String,
        entryId: String,
        userId: String? = nil,
        completion: @escaping ([SlotMachineUtils.SpinResult]) -> Void
    ) {
        guard let currentUserId = userId ?? Auth.auth().currentUser?.uid else {
            completion([])
            return
        }
        
        let spinStateRef = db.collection("spin_states")
            .document("\(competitionId)_\(entryId)_\(currentUserId)")
        
        spinStateRef.getDocument { document, error in
            if let error = error {
                print("❌ SpinStateManager: Error loading spin state: \(error)")
                completion([])
                return
            }
            
            guard let data = document?.data(),
                  let savedSpins = data["spins"] as? [[String: Any]] else {
                // No saved state found
                completion([])
                return
            }
            
            // Restore spin results
            let spinResults = savedSpins.compactMap { spinData -> SlotMachineUtils.SpinResult? in
                guard let stars = spinData["stars"] as? Int,
                      let multiplier = spinData["multiplier"] as? Int,
                      let points = spinData["points"] as? Int else {
                    return nil
                }
                return SlotMachineUtils.SpinResult(
                    stars: stars,
                    multiplier: multiplier,
                    points: points
                )
            }
            
            if !spinResults.isEmpty {
                let totalPoints = SlotMachineUtils.calculateTotalPoints(from: spinResults)
                print("✅ SpinStateManager: Loaded saved spins - \(spinResults.count) spins, \(totalPoints) points")
            }
            
            completion(spinResults)
        }
    }
    
    // MARK: - Save Spin State
    
    /// Save spin state for a user and entry
    /// - Parameters:
    ///   - competitionId: The competition ID
    ///   - entryId: The entry ID
    ///   - userId: The user ID (defaults to current user)
    ///   - spinResults: The array of spin results to save
    ///   - completion: Returns success/failure
    func saveSpinState(
        competitionId: String,
        entryId: String,
        userId: String? = nil,
        spinResults: [SlotMachineUtils.SpinResult],
        completion: @escaping (Bool) -> Void
    ) {
        guard let currentUserId = userId ?? Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        guard !spinResults.isEmpty else {
            print("⚠️ SpinStateManager: No spin results to save")
            completion(false)
            return
        }
        
        let spinStateRef = db.collection("spin_states")
            .document("\(competitionId)_\(entryId)_\(currentUserId)")
        
        let spinsData = spinResults.map { spin in
            return [
                "stars": spin.stars,
                "multiplier": spin.multiplier,
                "points": spin.points
            ] as [String : Any]
        }
        
        let totalPoints = SlotMachineUtils.calculateTotalPoints(from: spinResults)
        
        spinStateRef.setData([
            "competitionId": competitionId,
            "entryId": entryId,
            "userId": currentUserId,
            "spins": spinsData,
            "totalPoints": totalPoints,
            "createdAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("❌ SpinStateManager: Error saving spin state: \(error)")
                completion(false)
            } else {
                print("✅ SpinStateManager: Saved spin state - \(spinResults.count) spins, \(totalPoints) points")
                completion(true)
            }
        }
    }
    
    // MARK: - Delete Spin State
    
    /// Delete spin state for a user and entry (useful for testing or cleanup)
    /// - Parameters:
    ///   - competitionId: The competition ID
    ///   - entryId: The entry ID
    ///   - userId: The user ID (defaults to current user)
    ///   - completion: Returns success/failure
    func deleteSpinState(
        competitionId: String,
        entryId: String,
        userId: String? = nil,
        completion: @escaping (Bool) -> Void
    ) {
        guard let currentUserId = userId ?? Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let spinStateRef = db.collection("spin_states")
            .document("\(competitionId)_\(entryId)_\(currentUserId)")
        
        spinStateRef.delete { error in
            if let error = error {
                print("❌ SpinStateManager: Error deleting spin state: \(error)")
                completion(false)
            } else {
                print("✅ SpinStateManager: Deleted spin state")
                completion(true)
            }
        }
    }
    
    // MARK: - Check If Spins Exist
    
    /// Check if user has already spun for an entry
    /// - Parameters:
    ///   - competitionId: The competition ID
    ///   - entryId: The entry ID
    ///   - userId: The user ID (defaults to current user)
    ///   - completion: Returns true if spins exist, false otherwise
    func hasSpunForEntry(
        competitionId: String,
        entryId: String,
        userId: String? = nil,
        completion: @escaping (Bool) -> Void
    ) {
        guard let currentUserId = userId ?? Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let spinStateRef = db.collection("spin_states")
            .document("\(competitionId)_\(entryId)_\(currentUserId)")
        
        spinStateRef.getDocument { document, error in
            if let error = error {
                print("❌ SpinStateManager: Error checking spin state: \(error)")
                completion(false)
                return
            }
            
            completion(document?.exists ?? false)
        }
    }
}

// MARK: - Convenience Extensions

extension SpinStateManager {
    
    /// Load spin state and return as a tuple with total points
    func loadSpinStateWithTotal(
        competitionId: String,
        entryId: String,
        userId: String? = nil,
        completion: @escaping ([SlotMachineUtils.SpinResult], Int) -> Void
    ) {
        loadSpinState(competitionId: competitionId, entryId: entryId, userId: userId) { spinResults in
            let totalPoints = SlotMachineUtils.calculateTotalPoints(from: spinResults)
            completion(spinResults, totalPoints)
        }
    }
}
