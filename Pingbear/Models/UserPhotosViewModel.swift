import SwiftUI
import FirebaseFirestore

struct UserPhoto: Identifiable {
    let id: String
    let photoUrl: String
    var stars: Int
    let isSuperstar: Bool
    let creationDate: Date
    let themeName: String?
    let themeId: String?
    let overlayText: String?
    let overlayVerticalPosition: CGFloat
    let isFromCamera: Bool
    let userId: String
}

class UserPhotosViewModel: ObservableObject {
    @Published var userPhotos: [UserPhoto] = []
    @Published var isLoading = true
    @Published var isLoadingMore = false
    @Published var hasMorePhotos = true
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var lastDocument: DocumentSnapshot?
    private let pageSize = 20 // Adjust based on your needs
    private var currentUserId: String?
    private var currentCompetitionId: String?
    
    func fetchUserPhotos(userId: String, competitionId: String) {
        // Store current fetch parameters
        currentUserId = userId
        currentCompetitionId = competitionId
        
        // Reset state for new fetch
        userPhotos = []
        lastDocument = nil
        hasMorePhotos = true
        isLoading = true
        errorMessage = nil
        
        fetchPhotosPage(userId: userId, competitionId: competitionId, isInitialLoad: true)
    }
    
    func loadMorePhotos() {
        guard !isLoadingMore,
              hasMorePhotos,
              let userId = currentUserId,
              let competitionId = currentCompetitionId else { return }
        
        isLoadingMore = true
        fetchPhotosPage(userId: userId, competitionId: competitionId, isInitialLoad: false)
    }
    
    private func fetchPhotosPage(userId: String, competitionId: String, isInitialLoad: Bool) {
        var query = db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: pageSize)
        
        // If loading more, start after the last document
        if let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }
        
        query.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching user photos: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load photos"
                    self.isLoading = false
                    self.isLoadingMore = false
                }
                return
            }
            
            guard let documents = snapshot?.documents else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.isLoadingMore = false
                    self.hasMorePhotos = false
                }
                return
            }
            
            // Update pagination state
            self.lastDocument = documents.last
            self.hasMorePhotos = documents.count == self.pageSize
            
            let newPhotos = documents.compactMap { document -> UserPhoto? in
                let data = document.data()
                
                guard let photoUrl = data["imageUrl"] as? String else {
                    return nil
                }
                
                let stars = data["stars"] as? Int ?? 0
                let isSuperstar = data["superstar"] as? Bool ?? false
                let timestamp = data["timestamp"] as? Timestamp
                let creationDate = timestamp?.dateValue() ?? Date()
                let themeName = data["themeName"] as? String
                let themeId = data["themeId"] as? String
                let overlayText = data["overlayText"] as? String
                let overlayVerticalPosition = data["overlayVerticalPosition"] as? CGFloat ?? 0.5
                let isFromCamera = data["isFromCamera"] as? Bool ?? true
                let photoUserId = data["userId"] as? String ?? userId
                
                return UserPhoto(
                    id: document.documentID,
                    photoUrl: photoUrl,
                    stars: stars,
                    isSuperstar: isSuperstar,
                    creationDate: creationDate,
                    themeName: themeName,
                    themeId: themeId,
                    overlayText: overlayText,
                    overlayVerticalPosition: overlayVerticalPosition,
                    isFromCamera: isFromCamera,
                    userId: photoUserId
                )
            }
            
            DispatchQueue.main.async {
                if isInitialLoad {
                    self.userPhotos = newPhotos
                } else {
                    self.userPhotos.append(contentsOf: newPhotos)
                }
                self.isLoading = false
                self.isLoadingMore = false
            }
        }
    }
}

extension UserPhotosViewModel {
    func updatePhotoStars(photoId: String, newStarCount: Int) {
        if let index = userPhotos.firstIndex(where: { $0.id == photoId }) {
            var updatedPhoto = userPhotos[index]
            updatedPhoto.stars = newStarCount
            userPhotos[index] = updatedPhoto
        }
    }
}
