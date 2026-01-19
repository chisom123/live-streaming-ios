import Foundation
import Firebase
import Combine
import FirebaseAuth
import FirebaseStorage
import UIKit

class RecruitsViewModel: ObservableObject {
    @Published var ratingLinks: [RatingLink] = []
    @Published var isLoading = false
    @Published var isInitialDataLoad = true
    @Published var isUploadingPhoto = false
    @Published var errorMessage = ""
    
    private var linkListener: ListenerRegistration?
    private var hasReceivedInitialLinkData = false
    private let storage = Storage.storage(url: "gs://pingbear-96b4c-us")
    private var assignedUserNames: [String: String] = [:] // Cache for user names
    
    var totalRatings: Int {
        ratingLinks.reduce(0) { $0 + $1.totalRatings }
    }
    
    deinit {
        linkListener?.remove()
    }
    
    func loadData() {
        guard let user = Auth.auth().currentUser else { return }
        
        isInitialDataLoad = true
        hasReceivedInitialLinkData = false
        
        Analytics.shared.track(
            event: "recruits_data_load_started",
            properties: [
                "user_id": user.uid
            ]
        )
        
        setupRatingLinksListener(userId: user.uid)
    }
    
    private func checkInitialLoadComplete() {
        if hasReceivedInitialLinkData {
            isInitialDataLoad = false
        }
    }
    
    private func setupRatingLinksListener(userId: String) {
        let db = Firestore.firestore()
        
        linkListener = db.collection("rating_links")
            .whereField("recruiterId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        Analytics.shared.trackError(
                            message: "Rating links listener error: \(error.localizedDescription)"
                        )
                        
                        self?.hasReceivedInitialLinkData = true
                        self?.checkInitialLoadComplete()
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self?.hasReceivedInitialLinkData = true
                        self?.checkInitialLoadComplete()
                        return
                    }
                    
                    var links = documents.compactMap { doc in
                        RatingLink(documentID: doc.documentID, data: doc.data())
                    }
                    
                    self?.calculateAverageRatings(for: &links)
                    self?.fetchAssignedUserNames(for: links)
                    
                    self?.ratingLinks = links
                    
                    Analytics.shared.track(
                        event: "rating_links_loaded",
                        properties: [
                            "link_count": links.count,
                            "links_with_photos": links.filter { $0.photoUrl != nil }.count
                        ]
                    )
                    
                    self?.hasReceivedInitialLinkData = true
                    self?.checkInitialLoadComplete()
                }
            }
    }
    
    private func calculateAverageRatings(for links: inout [RatingLink]) {
        let db = Firestore.firestore()
        
        for i in 0..<links.count {
            let link = links[i]
            
            db.collection("ratings")
                .whereField("linkIdString", isEqualTo: link.linkId)
                .getDocuments { snapshot, error in
                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        DispatchQueue.main.async {
                            if let index = self.ratingLinks.firstIndex(where: { $0.id == link.id }) {
                                self.ratingLinks[index].averageRating = 0.0
                                self.ratingLinks[index].ratingCount = 0
                            }
                        }
                        return
                    }
                    
                    let ratings = documents.compactMap { doc in
                        doc.data()["rating"] as? Double
                    }
                    
                    let total = ratings.reduce(0, +)
                    let average = total / Double(ratings.count)
                    
                    DispatchQueue.main.async {
                        if let index = self.ratingLinks.firstIndex(where: { $0.id == link.id }) {
                            self.ratingLinks[index].averageRating = average
                            self.ratingLinks[index].ratingCount = ratings.count
                        }
                    }
                }
        }
    }
    
    private func fetchAssignedUserNames(for links: [RatingLink]) {
        let db = Firestore.firestore()
        
        // Get unique assigned user IDs
        let assignedUserIds = Set(links.compactMap { $0.assignedUserId })
        
        guard !assignedUserIds.isEmpty else { return }
        
        // Batch fetch user names
        db.collection("users")
            .whereField(FieldPath.documentID(), in: Array(assignedUserIds))
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    for doc in documents {
                        if let name = doc.data()["name"] as? String {
                            self?.assignedUserNames[doc.documentID] = name
                        }
                    }
                }
            }
    }
    
    func getAssignedUserName(for link: RatingLink) -> String? {
        guard let userId = link.assignedUserId else { return nil }
        return assignedUserNames[userId]
    }
    
    func uploadLinkPhoto(_ image: UIImage, for link: RatingLink) {
        guard let userId = Auth.auth().currentUser?.uid,
              let imageData = image.optimizedForUpload() else { return }
        
        isUploadingPhoto = true
        errorMessage = ""
        
        Analytics.shared.track(
            event: "link_photo_upload_started",
            properties: [
                "link_id": link.linkId,
                "image_size_kb": imageData.count / 1024
            ]
        )
        
        let storageRef = storage.reference()
        let photoRef = storageRef.child("link_photos/\(userId)/\(link.linkId)_\(UUID().uuidString).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        photoRef.putData(imageData, metadata: metadata) { [weak self] metadata, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.isUploadingPhoto = false
                    self?.errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                    
                    Analytics.shared.trackError(
                        message: "Link photo upload failed: \(error.localizedDescription)",
                        properties: [
                            "link_id": link.linkId
                        ]
                    )
                }
                return
            }
            
            // Get download URL
            photoRef.downloadURL { [weak self] url, error in
                DispatchQueue.main.async {
                    self?.isUploadingPhoto = false
                    
                    if let error = error {
                        self?.errorMessage = "Failed to get photo URL: \(error.localizedDescription)"
                        
                        Analytics.shared.trackError(
                            message: "Failed to get link photo URL: \(error.localizedDescription)",
                            properties: [
                                "link_id": link.linkId
                            ]
                        )
                        return
                    }
                    
                    // Update Firestore with new photo URL
                    self?.updateLinkPhotoUrl(url?.absoluteString, for: link)
                }
            }
        }
    }
    
    private func updateLinkPhotoUrl(_ url: String?, for link: RatingLink) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        
        var updateData: [String: Any] = [:]
        if let url = url {
            updateData["photoUrl"] = url
        } else {
            updateData["photoUrl"] = NSNull()
        }
        
        // Find the document by linkId and recruiterId
        db.collection("rating_links")
            .whereField("linkId", isEqualTo: link.linkId)
            .whereField("recruiterId", isEqualTo: userId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Failed to update photo: \(error.localizedDescription)"
                        
                        Analytics.shared.trackError(
                            message: "Failed to update link photo URL: \(error.localizedDescription)",
                            properties: [
                                "link_id": link.linkId
                            ]
                        )
                    }
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Link document not found"
                    }
                    return
                }
                
                document.reference.updateData(updateData) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self?.errorMessage = "Failed to update photo: \(error.localizedDescription)"
                            
                            Analytics.shared.trackError(
                                message: "Firestore photo update failed: \(error.localizedDescription)",
                                properties: [
                                    "link_id": link.linkId
                                ]
                            )
                        } else {
                            // Success - the listener will update the UI automatically
                            Analytics.shared.track(
                                event: "link_photo_updated_successfully",
                                properties: [
                                    "link_id": link.linkId,
                                    "has_photo": url != nil
                                ]
                            )
                        }
                    }
                }
            }
    }
    
    func updateLinkTitle(link: RatingLink, newTitle: String) {
        guard let user = Auth.auth().currentUser else { return }
        
        Analytics.shared.track(
            event: "link_title_update_started",
            properties: [
                "link_id": link.linkId,
                "old_title": link.title,
                "new_title": newTitle
            ]
        )
        
        let db = Firestore.firestore()
        
        db.collection("rating_links")
            .whereField("linkId", isEqualTo: link.linkId)
            .whereField("recruiterId", isEqualTo: user.uid)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Error updating title: \(error.localizedDescription)"
                        
                        Analytics.shared.trackError(
                            message: "Link title update failed: \(error.localizedDescription)",
                            properties: [
                                "link_id": link.linkId
                            ]
                        )
                    }
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Link document not found"
                        
                        Analytics.shared.trackError(
                            message: "Link document not found for title update",
                            properties: [
                                "link_id": link.linkId
                            ]
                        )
                    }
                    return
                }
                
                document.reference.updateData([
                    "title": newTitle
                ]) { error in
                    if let error = error {
                        DispatchQueue.main.async {
                            self?.errorMessage = "Error updating title: \(error.localizedDescription)"
                            
                            Analytics.shared.trackError(
                                message: "Firestore title update failed: \(error.localizedDescription)",
                                properties: [
                                    "link_id": link.linkId
                                ]
                            )
                        }
                    } else {
                        Analytics.shared.track(
                            event: "link_title_updated_successfully",
                            properties: [
                                "link_id": link.linkId,
                                "new_title": newTitle
                            ]
                        )
                    }
                }
            }
    }
    
    func createNewLink(for assignedUser: AppUser, completion: @escaping (RatingLink?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(nil)
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Analytics.shared.track(
            event: "link_creation_started",
            properties: [
                "current_link_count": ratingLinks.count,
                "assigned_user_id": assignedUser.id,
                "assigned_user_name": assignedUser.name
            ]
        )
        
        let db = Firestore.firestore()
        let linkId = "\(user.uid)_\(Int(Date().timeIntervalSince1970 * 1000))"
        let linkNumber = ratingLinks.count + 1
        let title = "Rating Link #\(linkNumber)"
        
        let linkData: [String: Any] = [
            "recruiterId": user.uid,
            "assignedUserId": assignedUser.id,
            "linkId": linkId,
            "title": title,
            "description": "",
            "url": "rate.socialstarapp.com/rate/\(user.uid)/\(linkId)",
            "createdAt": Timestamp(),
            "totalRatings": 0
            // photoUrl will be added later when user uploads a photo
        ]
        
        let linkRef = db.collection("rating_links").document()
        
        linkRef.setData(linkData) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Error creating link: \(error.localizedDescription)"
                    
                    Analytics.shared.track(
                        event: "link_creation_failed",
                        properties: [
                            AnalyticsProperty.errorMessage: error.localizedDescription,
                            "current_link_count": self?.ratingLinks.count ?? 0,
                            "assigned_user_id": assignedUser.id
                        ]
                    )
                    
                    completion(nil)
                } else {
                    let newLink = RatingLink(
                        documentID: linkRef.documentID,
                        data: linkData
                    )
                    
                    // Cache the assigned user's name
                    self?.assignedUserNames[assignedUser.id] = assignedUser.name
                    
                    Analytics.shared.track(
                        event: "link_created_successfully",
                        properties: [
                            "link_id": linkId,
                            "link_title": title,
                            "new_link_count": (self?.ratingLinks.count ?? 0) + 1,
                            "assigned_user_id": assignedUser.id,
                            "assigned_user_name": assignedUser.name
                        ]
                    )
                    
                    completion(newLink)
                }
            }
        }
    }
}
