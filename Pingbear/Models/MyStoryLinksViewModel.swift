import Foundation
import Firebase
import Combine
import FirebaseAuth
import FirebaseStorage
import UIKit

class MyStoryLinksViewModel: ObservableObject {
    @Published var assignedLinks: [RatingLink] = []
    @Published var isLoading = false
    @Published var isInitialDataLoad = true
    @Published var isUploadingPhoto = false
    @Published var errorMessage = ""
    
    private var linkListener: ListenerRegistration?
    private var hasReceivedInitialLinkData = false
    private let storage = Storage.storage(url: "gs://pingbear-96b4c-us")
    private var recruiterNames: [String: String] = [:] // Cache for recruiter names
    
    var totalRatings: Int {
        assignedLinks.reduce(0) { $0 + $1.totalRatings }
    }
    
    deinit {
        linkListener?.remove()
    }
    
    func loadData() {
        guard let user = Auth.auth().currentUser else { return }
        
        isInitialDataLoad = true
        hasReceivedInitialLinkData = false
        
        Analytics.shared.track(
            event: "my_story_links_data_load_started",
            properties: [
                "user_id": user.uid
            ]
        )
        
        setupAssignedLinksListener(userId: user.uid)
    }
    
    private func checkInitialLoadComplete() {
        if hasReceivedInitialLinkData {
            isInitialDataLoad = false
        }
    }
    
    private func setupAssignedLinksListener(userId: String) {
        let db = Firestore.firestore()
        
        linkListener = db.collection("rating_links")
            .whereField("assignedUserId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        Analytics.shared.trackError(
                            message: "Assigned links listener error: \(error.localizedDescription)"
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
                    self?.fetchRecruiterNames(for: links)
                    
                    self?.assignedLinks = links
                    
                    Analytics.shared.track(
                        event: "assigned_links_loaded",
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
                            if let index = self.assignedLinks.firstIndex(where: { $0.id == link.id }) {
                                self.assignedLinks[index].averageRating = 0.0
                                self.assignedLinks[index].ratingCount = 0
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
                        if let index = self.assignedLinks.firstIndex(where: { $0.id == link.id }) {
                            self.assignedLinks[index].averageRating = average
                            self.assignedLinks[index].ratingCount = ratings.count
                        }
                    }
                }
        }
    }
    
    private func fetchRecruiterNames(for links: [RatingLink]) {
        let db = Firestore.firestore()
        
        // Get unique recruiter IDs
        let recruiterIds = Set(links.map { $0.recruiterId })
        
        guard !recruiterIds.isEmpty else { return }
        
        // Batch fetch recruiter names
        db.collection("users")
            .whereField(FieldPath.documentID(), in: Array(recruiterIds))
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    for doc in documents {
                        if let name = doc.data()["name"] as? String {
                            self?.recruiterNames[doc.documentID] = name
                        }
                    }
                }
            }
    }
    
    func getRecruiterName(for link: RatingLink) -> String? {
        return recruiterNames[link.recruiterId]
    }
    
    func uploadLinkPhoto(_ image: UIImage, for link: RatingLink) {
        print("🚀 uploadLinkPhoto called")
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user in uploadLinkPhoto")
            return
        }
        
        print("✅ User ID: \(userId)")
        
        guard let imageData = image.optimizedForUpload() else {
            print("❌ Failed to optimize image")
            return
        }
        
        print("✅ Image optimized, size: \(imageData.count / 1024)KB")
        
        isUploadingPhoto = true
        errorMessage = ""
        
        Analytics.shared.track(
            event: "story_link_photo_upload_started",
            properties: [
                "link_id": link.linkId,
                "image_size_kb": imageData.count / 1024,
                "recruiter_id": link.recruiterId
            ]
        )
        
        let storageRef = storage.reference()
        let photoRef = storageRef.child("link_photos/\(link.recruiterId)/\(link.linkId)_\(UUID().uuidString).jpg")
        
        print("📁 Storage path: link_photos/\(link.recruiterId)/\(link.linkId)_...")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        print("⬆️ Starting upload to Firebase Storage...")
        
        photoRef.putData(imageData, metadata: metadata) { [weak self] metadata, error in
            if let error = error {
                print("❌ Storage upload failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.isUploadingPhoto = false
                    self?.errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                    
                    Analytics.shared.trackError(
                        message: "Story link photo upload failed: \(error.localizedDescription)",
                        properties: [
                            "link_id": link.linkId
                        ]
                    )
                }
                return
            }
            
            print("✅ Upload successful! Getting download URL...")
            
            // Get download URL
            photoRef.downloadURL { [weak self] url, error in
                if let error = error {
                    print("❌ Failed to get download URL: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self?.isUploadingPhoto = false
                        self?.errorMessage = "Failed to get photo URL: \(error.localizedDescription)"
                        
                        Analytics.shared.trackError(
                            message: "Failed to get story link photo URL: \(error.localizedDescription)",
                            properties: [
                                "link_id": link.linkId
                            ]
                        )
                    }
                    return
                }
                
                if let url = url {
                    print("✅ Got download URL: \(url.absoluteString)")
                } else {
                    print("⚠️ Download URL is nil")
                }
                
                DispatchQueue.main.async {
                    self?.isUploadingPhoto = false
                    print("📝 Calling updateLinkPhotoUrl...")
                    // Update Firestore with new photo URL
                    self?.updateLinkPhotoUrl(url?.absoluteString, for: link)
                }
            }
        }
    }
    
    private func updateLinkPhotoUrl(_ url: String?, for link: RatingLink) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user")
            return
        }
        
        print("🔍 Attempting to update photo URL for link: \(link.linkId)")
        print("🔍 Current user ID: \(userId)")
        print("🔍 Assigned user ID: \(link.assignedUserId ?? "nil")")
        
        let db = Firestore.firestore()
        
        var updateData: [String: Any] = [:]
        if let url = url {
            updateData["photoUrl"] = url
            print("✅ Photo URL to set: \(url)")
        } else {
            updateData["photoUrl"] = NSNull()
        }
        
        // Find the document by linkId and assignedUserId (verify this user should update it)
        db.collection("rating_links")
            .whereField("linkId", isEqualTo: link.linkId)
            .whereField("assignedUserId", isEqualTo: userId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Query error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self?.errorMessage = "Failed to update photo: \(error.localizedDescription)"
                        
                        Analytics.shared.trackError(
                            message: "Failed to update story link photo URL: \(error.localizedDescription)",
                            properties: [
                                "link_id": link.linkId
                            ]
                        )
                    }
                    return
                }
                
                print("📄 Query returned \(snapshot?.documents.count ?? 0) documents")
                
                guard let document = snapshot?.documents.first else {
                    print("❌ No document found matching criteria")
                    print("🔍 Link ID we're searching for: \(link.linkId)")
                    print("🔍 User ID we're searching for: \(userId)")
                    DispatchQueue.main.async {
                        self?.errorMessage = "Link document not found"
                        
                        Analytics.shared.trackError(
                            message: "Link document not found for photo update",
                            properties: [
                                "link_id": link.linkId,
                                "assigned_user_id": userId
                            ]
                        )
                    }
                    return
                }
                
                print("✅ Found document: \(document.documentID)")
                print("📝 Updating with data: \(updateData)")
                
                document.reference.updateData(updateData) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("❌ Update failed: \(error.localizedDescription)")
                            self?.errorMessage = "Failed to update photo: \(error.localizedDescription)"
                            
                            Analytics.shared.trackError(
                                message: "Firestore story link photo update failed: \(error.localizedDescription)",
                                properties: [
                                    "link_id": link.linkId
                                ]
                            )
                        } else {
                            print("✅ Photo URL updated successfully!")
                            // Success - the listener will update the UI automatically
                            Analytics.shared.track(
                                event: "story_link_photo_updated_successfully",
                                properties: [
                                    "link_id": link.linkId,
                                    "has_photo": url != nil,
                                    "recruiter_id": link.recruiterId
                                ]
                            )
                        }
                    }
                }
            }
    }
}
