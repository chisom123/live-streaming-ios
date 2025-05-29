import SwiftUI
import FirebaseFirestore

struct ThemePhoto: Identifiable {
    let id: String
    let photoUrl: String
    let userName: String
    let userId: String
    var stars: Int
    let isSuperstar: Bool
    let creationDate: Date
    let themeName: String
    let themeId: String
    let overlayText: String?
    let overlayVerticalPosition: CGFloat
    let isFromCamera: Bool
    let profilePictureUrl: String?
}

class ThemePhotosViewModel: ObservableObject {
    @Published var themePhotos: [ThemePhoto] = []
    @Published var isLoading = true
    @Published var isLoadingMore = false
    @Published var hasMorePhotos = true
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var lastDocument: DocumentSnapshot?
    private let pageSize = 20
    private var currentThemeId: String?
    private var currentCompetitionId: String?
    
    // Cache for user data to improve performance
    private var userCache: [String: (username: String, profilePic: String?)] = [:]
    
    func fetchThemePhotos(themeId: String, competitionId: String) {
        // Store current fetch parameters
        currentThemeId = themeId
        currentCompetitionId = competitionId
        
        // Reset state for new fetch
        themePhotos = []
        lastDocument = nil
        hasMorePhotos = true
        isLoading = true
        errorMessage = nil
        userCache.removeAll()
        
        fetchPhotosPage(themeId: themeId, competitionId: competitionId, isInitialLoad: true)
    }
    
    func loadMorePhotos() {
        guard !isLoadingMore,
              hasMorePhotos,
              let themeId = currentThemeId,
              let competitionId = currentCompetitionId else { return }
        
        isLoadingMore = true
        fetchPhotosPage(themeId: themeId, competitionId: competitionId, isInitialLoad: false)
    }
    
    private func fetchPhotosPage(themeId: String, competitionId: String, isInitialLoad: Bool) {
        var query = db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .whereField("themeId", isEqualTo: themeId)
            .order(by: "timestamp", descending: true)
            .limit(to: pageSize)
        
        // If loading more, start after the last document
        if let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }
        
        query.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching theme photos: \(error)")
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
            
            // Get unique userIds that aren't already cached
            let userIds = Set(documents.compactMap { doc -> String? in
                guard let userId = doc.data()["userId"] as? String,
                      self.userCache[userId] == nil else { return nil }
                return userId
            })
            
            if userIds.isEmpty {
                // All users are cached, process photos immediately
                self.processPhotos(from: documents, isInitialLoad: isInitialLoad)
            } else {
                // Fetch user data for uncached users
                self.fetchUserData(userIds: Array(userIds)) { [weak self] in
                    self?.processPhotos(from: documents, isInitialLoad: isInitialLoad)
                }
            }
        }
    }
    
    private func fetchUserData(userIds: [String], completion: @escaping () -> Void) {
        db.collection("users")
            .whereField(FieldPath.documentID(), in: userIds)
            .getDocuments { [weak self] userSnapshot, userError in
                if let userError = userError {
                    print("Error fetching users: \(userError)")
                    completion()
                    return
                }
                
                // Update user cache
                userSnapshot?.documents.forEach { userDoc in
                    let data = userDoc.data()
                    let username = data["username"] as? String ?? "Unknown"
                    let profilePic = data["profilePictureUrl"] as? String
                    self?.userCache[userDoc.documentID] = (username, profilePic)
                }
                
                completion()
            }
    }
    
    private func processPhotos(from documents: [QueryDocumentSnapshot], isInitialLoad: Bool) {
        let newPhotos = documents.compactMap { document -> ThemePhoto? in
            let data = document.data()
            
            guard let photoUrl = data["imageUrl"] as? String,
                  let userId = data["userId"] as? String else {
                return nil
            }
            
            let stars = data["stars"] as? Int ?? 0
            let isSuperstar = data["superstar"] as? Bool ?? false
            let timestamp = data["timestamp"] as? Timestamp
            let creationDate = timestamp?.dateValue() ?? Date()
            let themeName = data["themeName"] as? String ?? ""
            let themeId = data["themeId"] as? String ?? ""
            let overlayText = data["overlayText"] as? String
            let overlayVerticalPosition = data["overlayVerticalPosition"] as? CGFloat ?? 0.5
            let isFromCamera = data["isFromCamera"] as? Bool ?? true
            
            // Get user data from cache
            let userData = userCache[userId] ?? ("Unknown", nil)
            let userName = userData.username
            let profilePictureUrl = userData.profilePic
            
            return ThemePhoto(
                id: document.documentID,
                photoUrl: photoUrl,
                userName: userName,
                userId: userId,
                stars: stars,
                isSuperstar: isSuperstar,
                creationDate: creationDate,
                themeName: themeName,
                themeId: themeId,
                overlayText: overlayText,
                overlayVerticalPosition: overlayVerticalPosition,
                isFromCamera: isFromCamera,
                profilePictureUrl: profilePictureUrl
            )
        }
        
        DispatchQueue.main.async {
            if isInitialLoad {
                self.themePhotos = newPhotos
            } else {
                self.themePhotos.append(contentsOf: newPhotos)
            }
            self.isLoading = false
            self.isLoadingMore = false
        }
    }
}

extension ThemePhotosViewModel {
    func updatePhotoStars(photoId: String, newStarCount: Int) {
        if let index = themePhotos.firstIndex(where: { $0.id == photoId }) {
            var updatedPhoto = themePhotos[index]
            updatedPhoto.stars = newStarCount
            themePhotos[index] = updatedPhoto
        }
    }
}
