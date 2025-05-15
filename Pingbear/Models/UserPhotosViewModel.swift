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
}

class UserPhotosViewModel: ObservableObject {
    @Published var userPhotos: [UserPhoto] = []
    @Published var isLoading = true
    
    private let db = Firestore.firestore()
    
    func fetchUserPhotos(userId: String, competitionId: String) {
        isLoading = true
        
        guard let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) else {
            print("Error calculating date 24 hours ago")
            isLoading = false
            return
        }
        
        db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .whereField("userId", isEqualTo: userId)
            .whereField("timestamp", isGreaterThan: Timestamp(date: twentyFourHoursAgo))
            .order(by: "timestamp", descending: true)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching user photos: \(error)")
                    DispatchQueue.main.async {
                        self?.isLoading = false
                    }
                    return
                }
                
                let photos = snapshot?.documents.compactMap { document -> UserPhoto? in
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
                        isFromCamera: isFromCamera
                    )
                } ?? []
                
                DispatchQueue.main.async {
                    self?.userPhotos = photos
                    self?.isLoading = false
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
