import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct PhotoInteraction: Identifiable {
    let id = UUID()
    let userId: String
    let userName: String
    let profilePictureUrl: String?
    let viewedAt: Date
    let rating: Int?
}

class PhotoInteractionService: ObservableObject {
    @Published var viewCount: Int = 0
    @Published var interactions: [PhotoInteraction] = []
    @Published var isLoadingInteractions: Bool = false
    
    private let db = Firestore.firestore()
    
    // MARK: - View Count Management
    
    /// Fetches the view count for a specific photo entry
    func fetchViewCount(competitionId: String, entryId: String) {
        let interactionsRef = db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .document(entryId)
            .collection("interactions")
        
        interactionsRef.getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("Error fetching view count: \(error)")
                return
            }
            
            DispatchQueue.main.async {
                self?.viewCount = snapshot?.documents.count ?? 0
            }
        }
    }
    
    /// Updates view count locally (for immediate UI feedback)
    func incrementViewCount() {
        DispatchQueue.main.async {
            self.viewCount += 1
        }
    }
    
    /// Resets view count (useful when switching between entries)
    func resetViewCount() {
        DispatchQueue.main.async {
            self.viewCount = 0
        }
    }
    
    // MARK: - View Tracking
    
    /// Tracks when a user views a photo entry
    func trackView(competitionId: String, entryId: String, source: String, completion: ((Bool) -> Void)? = nil) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
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
            
            // Don't track views for the photo owner
            if photoOwnerId == currentUserId {
                completion?(true) // Return success but don't track
                return
            }
            
            // Proceed with tracking for non-owners
            let interactionRef = self?.db.collection("competitions")
                .document(competitionId)
                .collection("entries")
                .document(entryId)
                .collection("interactions")
                .document(currentUserId)
            
            // Check if document exists
            interactionRef?.getDocument { [weak self] document, error in
                if let error = error {
                    print("Error checking interaction document: \(error)")
                    completion?(false)
                    return
                }
                
                // If document doesn't exist or doesn't have viewedAt, set it
                if document?.exists == false || document?.data()?["viewedAt"] == nil {
                    interactionRef?.setData([
                        "viewedAt": FieldValue.serverTimestamp(),
                        "userId": currentUserId,
                        "source": source
                    ], merge: true) { error in
                        let success = error == nil
                        if success {
                            // Update view count after successfully tracking the view
                            self?.incrementViewCount()
                        }
                        completion?(success)
                    }
                } else {
                    completion?(true) // Already tracked
                }
            }
        }
    }
    
    // MARK: - Detailed Interactions
    
    /// Fetches detailed interaction data for a photo entry
    func fetchInteractions(competitionId: String, entryId: String) {
        isLoadingInteractions = true
        
        let interactionsRef = db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .document(entryId)
            .collection("interactions")
        
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
                    self?.viewCount = 0
                }
                return
            }
            
            // Update view count when fetching interactions
            DispatchQueue.main.async {
                self?.viewCount = userIds.count
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
                        
                        return PhotoInteraction(
                            userId: userId,
                            userName: userName,
                            profilePictureUrl: profileUrl,
                            viewedAt: (data["viewedAt"] as? Timestamp)?.dateValue() ?? Date(),
                            rating: data["rating"] as? Int
                        )
                    } ?? []
                    
                    DispatchQueue.main.async {
                        self?.interactions = interactions.sorted { interaction1, interaction2 in
                            return interaction1.viewedAt > interaction2.viewedAt
                        }
                        self?.isLoadingInteractions = false
                    }
                }
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Tracks view and fetches count in one call (useful for onAppear)
    func trackViewAndFetchCount(competitionId: String, entryId: String, source: String) {
        trackView(competitionId: competitionId, entryId: entryId, source: source) { [weak self] success in
            // Always fetch the current count regardless of tracking success
            self?.fetchViewCount(competitionId: competitionId, entryId: entryId)
        }
    }
    
    /// Prepares for a new entry by resetting state
    func prepareForNewEntry() {
        DispatchQueue.main.async {
            self.viewCount = 0
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
