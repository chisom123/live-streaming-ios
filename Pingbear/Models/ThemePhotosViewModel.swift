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
}

class ThemePhotosViewModel: ObservableObject {
    @Published var themePhotos: [ThemePhoto] = []
    @Published var isLoading = true
    
    private let db = Firestore.firestore()
    
    func fetchThemePhotos(themeId: String, competitionId: String) {
        isLoading = true
        
        guard let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) else {
            print("Error calculating date 24 hours ago")
            isLoading = false
            return
        }
        
        db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .whereField("themeId", isEqualTo: themeId)
            .whereField("timestamp", isGreaterThan: Timestamp(date: twentyFourHoursAgo))
            .order(by: "timestamp", descending: true)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching theme photos: \(error)")
                    DispatchQueue.main.async {
                        self?.isLoading = false
                    }
                    return
                }
                
                // Get unique userIds
                let userIds = Set(snapshot?.documents.compactMap { $0.data()["userId"] as? String } ?? [])
                
                if userIds.isEmpty {
                    DispatchQueue.main.async {
                        self?.themePhotos = []
                        self?.isLoading = false
                    }
                    return
                }
                
                // Fetch user data in batch
                self?.db.collection("users")
                    .whereField(FieldPath.documentID(), in: Array(userIds))
                    .getDocuments { userSnapshot, userError in
                        if let userError = userError {
                            print("Error fetching users: \(userError)")
                            DispatchQueue.main.async {
                                self?.isLoading = false
                            }
                            return
                        }
                        
                        // Create user dictionary
                        var userDict: [String: String] = [:]
                        userSnapshot?.documents.forEach { userDoc in
                            if let username = userDoc.data()["username"] as? String {
                                userDict[userDoc.documentID] = username
                            }
                        }
                        
                        // Process photos
                        let photos = snapshot?.documents.compactMap { document -> ThemePhoto? in
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
                            let userName = userDict[userId] ?? "Unknown"
                            
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
                                isFromCamera: isFromCamera
                            )
                        } ?? []
                        
                        DispatchQueue.main.async {
                            self?.themePhotos = photos.sorted { $0.creationDate > $1.creationDate }
                            self?.isLoading = false
                        }
                    }
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
