import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct PhotoInteraction: Identifiable {
    let id = UUID()
    let userId: String
    let userName: String
    let profilePictureUrl: String?
    let ratedAt: Date
    let rating: Int
}

class PhotoInteractionService: ObservableObject {
    @Published var ratingCount: Int = 0
    @Published var interactions: [PhotoInteraction] = []
    @Published var isLoadingInteractions: Bool = false
    
    private let db = Firestore.firestore()
    
    // MARK: - Rating Count Management
    
    /// Fetches the rating count for a specific photo entry
    func fetchRatingCount(competitionId: String, entryId: String) {
        let interactionsRef = db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .document(entryId)
            .collection("interactions")
            .whereField("rating", isGreaterThan: 0) // Only count interactions with ratings
        
        interactionsRef.getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("Error fetching rating count: \(error)")
                return
            }
            
            DispatchQueue.main.async {
                self?.ratingCount = snapshot?.documents.count ?? 0
            }
        }
    }
    
    /// Updates rating count locally (for immediate UI feedback)
    func incrementRatingCount() {
        DispatchQueue.main.async {
            self.ratingCount += 1
        }
    }
    
    /// Decrements rating count locally (when rating is removed)
    func decrementRatingCount() {
        DispatchQueue.main.async {
            self.ratingCount = max(0, self.ratingCount - 1)
        }
    }
    
    /// Resets rating count (useful when switching between entries)
    func resetRatingCount() {
        DispatchQueue.main.async {
            self.ratingCount = 0
        }
    }
    
    // MARK: - Rating Tracking
    
    /// Tracks when a user rates a photo entry
    func submitRating(competitionId: String, entryId: String, rating: Int, completion: ((Bool) -> Void)? = nil) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion?(false)
            return
        }
        
        guard rating > 0 else {
            print("Invalid rating value")
            completion?(false)
            return
        }
        
        // First check if the user is the owner of this photo
        let entryRef = db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .document(entryId)
        
        entryRef.getDocument { [weak self] document, error in
            if let error = error {
                print("Error checking entry ownership: \(error)")
                completion?(false)
                return
            }
            
            guard let document = document,
                  let data = document.data(),
                  let photoOwnerId = data["userId"] as? String else {
                print("Entry data not found")
                completion?(false)
                return
            }
            
            // Don't allow users to rate their own photos
            if photoOwnerId == currentUserId {
                print("Users cannot rate their own photos")
                completion?(false)
                return
            }
            
            // Submit or update the rating
            let interactionRef = self?.db.collection("competitions")
                .document(competitionId)
                .collection("entries")
                .document(entryId)
                .collection("interactions")
                .document(currentUserId)
            
            // Check if user has already rated this photo
            interactionRef?.getDocument { [weak self] document, error in
                if let error = error {
                    print("Error checking existing rating: \(error)")
                    completion?(false)
                    return
                }
                
                let isNewRating = document?.exists == false || document?.data()?["rating"] == nil
                
                interactionRef?.setData([
                    "rating": rating,
                    "ratedAt": FieldValue.serverTimestamp(),
                    "userId": currentUserId
                ], merge: true) { error in
                    let success = error == nil
                    if success && isNewRating {
                        // Only increment count for new ratings
                        self?.incrementRatingCount()
                    }
                    completion?(success)
                }
            }
        }
    }
    
    /// Removes a user's rating from a photo entry
    func removeRating(competitionId: String, entryId: String, completion: ((Bool) -> Void)? = nil) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion?(false)
            return
        }
        
        let interactionRef = db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .document(entryId)
            .collection("interactions")
            .document(currentUserId)
        
        interactionRef.delete { [weak self] error in
            let success = error == nil
            if success {
                self?.decrementRatingCount()
            }
            completion?(success)
        }
    }
    
    // MARK: - Detailed Interactions
    
    /// Fetches detailed interaction data for a photo entry (only users who have rated)
    func fetchInteractions(competitionId: String, entryId: String) {
        isLoadingInteractions = true
        
        let interactionsRef = db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .document(entryId)
            .collection("interactions")
            .whereField("rating", isGreaterThan: 0) // Only fetch interactions with ratings
        
        interactionsRef.getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("Error fetching interactions: \(error)")
                DispatchQueue.main.async {
                    self?.isLoadingInteractions = false
                }
                return
            }
            
            let userIds = snapshot?.documents.compactMap { $0.documentID } ?? []
            guard !userIds.isEmpty else {
                DispatchQueue.main.async {
                    self?.interactions = []
                    self?.isLoadingInteractions = false
                    self?.ratingCount = 0
                }
                return
            }
            
            // Update rating count when fetching interactions
            DispatchQueue.main.async {
                self?.ratingCount = userIds.count
            }
            
            // Fetch user details
            self?.db.collection("users")
                .whereField(FieldPath.documentID(), in: userIds)
                .getDocuments { [weak self] usersSnapshot, error in
                    if let error = error {
                        print("Error fetching users: \(error)")
                        DispatchQueue.main.async {
                            self?.isLoadingInteractions = false
                        }
                        return
                    }
                    
                    var userMap: [String: (String, String?)] = [:]
                    usersSnapshot?.documents.forEach { doc in
                        let data = doc.data()
                        userMap[doc.documentID] = (
                            data["username"] as? String ?? "Unknown",
                            data["profilePictureUrl"] as? String
                        )
                    }
                    
                    let interactions: [PhotoInteraction] = snapshot?.documents.compactMap { doc in
                        let data = doc.data()
                        let userId = doc.documentID
                        let (userName, profileUrl) = userMap[userId] ?? ("Unknown", nil)
                        
                        guard let rating = data["rating"] as? Int, rating > 0 else {
                            return nil // Skip interactions without valid ratings
                        }
                        
                        return PhotoInteraction(
                            userId: userId,
                            userName: userName,
                            profilePictureUrl: profileUrl,
                            ratedAt: (data["ratedAt"] as? Timestamp)?.dateValue() ?? Date(),
                            rating: rating
                        )
                    } ?? []
                    
                    DispatchQueue.main.async {
                        self?.interactions = interactions.sorted { interaction1, interaction2 in
                            return interaction1.ratedAt > interaction2.ratedAt
                        }
                        self?.isLoadingInteractions = false
                    }
                }
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Fetches the current rating count for display
    func loadRatingData(competitionId: String, entryId: String) {
        fetchRatingCount(competitionId: competitionId, entryId: entryId)
    }
    
    /// Prepares for a new entry by resetting state
    func prepareForNewEntry() {
        DispatchQueue.main.async {
            self.ratingCount = 0
            self.interactions = []
            self.isLoadingInteractions = false
        }
    }
}

// MARK: - SwiftUI Environment Extension

struct PhotoInteractionServiceKey: EnvironmentKey {
    static let defaultValue = PhotoInteractionService()
}

extension EnvironmentValues {
    var photoInteractionService: PhotoInteractionService {
        get { self[PhotoInteractionServiceKey.self] }
        set { self[PhotoInteractionServiceKey.self] = newValue }
    }
}
