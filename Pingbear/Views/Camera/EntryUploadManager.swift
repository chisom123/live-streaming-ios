import SwiftUI
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

// Create a dedicated manager for competition entry uploads
class EntryUploadManager: ObservableObject {
    static let shared = EntryUploadManager()
    
    private let storage = Storage.storage(url: "gs://pingbear-96b4c-us")
    private let db = Firestore.firestore()
    
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    
    private var isInitialized = false
    
    // Method to ensure Firebase Storage is initialized
    func initialize() {
        if !isInitialized {
            // Force Firebase Storage to initialize by creating a reference
            _ = Storage.storage(url: "gs://pingbear-96b4c-us").reference()
            isInitialized = true
            print("EntryUploadManager: Firebase Storage initialized")
        }
    }
    
    // Upload a parlay entry with predictions
    func uploadParlayEntry(
        image: UIImage,
        competitionId: String,
        userId: String,
        overlayText: String,
        overlayVerticalPosition: CGFloat,
        isFromCamera: Bool,
        themeId: String?,
        themeName: String?,
        competition: Competition,
        entryCost: Int,
        predictions: [String: Int],
        potentialPayout: Int,
        onProgress: @escaping (Double) -> Void,
        onSuccess: @escaping (String) -> Void,
        onFailure: @escaping (Error) -> Void
    ) {
        // Initialize Firebase Storage if needed
        initialize()
        
        // Set initial state
        isUploading = true
        uploadProgress = 0.0
        onProgress(0.0)
        
        print("EntryUploadManager: Starting parlay entry upload process")
        
        // Process the image optimization on a background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Initial progress update
            DispatchQueue.main.async {
                self.uploadProgress = 0.05
                onProgress(0.05)
            }
            
            // Optimize the image
            guard let imageData = image.optimizedForUpload() else {
                DispatchQueue.main.async {
                    self.isUploading = false
                    onFailure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to optimize image"]))
                }
                return
            }
            
            print("EntryUploadManager: Image optimized for upload. Size: \(Double(imageData.count) / 1024.0) KB")
            
            DispatchQueue.main.async {
                self.uploadProgress = 0.2
                onProgress(0.2)
                
                // Continue with upload on main thread
                self.performParlayUpload(
                    imageData: imageData,
                    competitionId: competitionId,
                    userId: userId,
                    overlayText: overlayText,
                    overlayVerticalPosition: overlayVerticalPosition,
                    isFromCamera: isFromCamera,
                    themeId: themeId,
                    themeName: themeName,
                    competition: competition,
                    entryCost: entryCost,
                    predictions: predictions,
                    potentialPayout: potentialPayout,
                    onProgress: onProgress,
                    onSuccess: onSuccess,
                    onFailure: onFailure
                )
            }
        }
    }
    
    // Perform the actual parlay upload on the main thread
    private func performParlayUpload(
        imageData: Data,
        competitionId: String,
        userId: String,
        overlayText: String,
        overlayVerticalPosition: CGFloat,
        isFromCamera: Bool,
        themeId: String?,
        themeName: String?,
        competition: Competition,
        entryCost: Int,
        predictions: [String: Int],
        potentialPayout: Int,
        onProgress: @escaping (Double) -> Void,
        onSuccess: @escaping (String) -> Void,
        onFailure: @escaping (Error) -> Void
    ) {
        print("EntryUploadManager: Starting Firebase Storage upload for parlay entry")
        
        let storageRef = storage.reference().child("images/\(UUID().uuidString).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "competitionId": competitionId,
            "userId": userId
        ]
        
        let uploadTask = storageRef.putData(imageData, metadata: metadata)
        
        // Set a timeout in case Firebase hangs
        let uploadTimeout = DispatchWorkItem { [weak self] in
            print("EntryUploadManager: Upload timeout triggered")
            uploadTask.cancel()
            DispatchQueue.main.async {
                self?.isUploading = false
                onFailure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Upload timeout"]))
            }
        }
        
        // Cancel upload after 45 seconds if not completed
        DispatchQueue.main.asyncAfter(deadline: .now() + 45, execute: uploadTimeout)
        
        // Monitor upload progress
        uploadTask.observe(.progress) { [weak self] snapshot in
            guard let percentComplete = snapshot.progress?.fractionCompleted else { return }
            // Scale the progress from 20-80% range during upload
            let scaledProgress = 0.2 + (percentComplete * 0.6) // 20% to 80%
            
            DispatchQueue.main.async {
                self?.uploadProgress = scaledProgress
                onProgress(scaledProgress)
            }
        }
        
        // Handle upload success
        uploadTask.observe(.success) { [weak self] _ in
            // Cancel the timeout
            uploadTimeout.cancel()
            
            DispatchQueue.main.async {
                self?.uploadProgress = 0.9
                onProgress(0.9)
            }
            
            print("EntryUploadManager: Upload successful, getting download URL")
            
            // Get the download URL
            storageRef.downloadURL { [weak self] url, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.isUploading = false
                        onFailure(error)
                    }
                    return
                }
                
                guard let downloadURL = url?.absoluteString else {
                    DispatchQueue.main.async {
                        self?.isUploading = false
                        onFailure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"]))
                    }
                    return
                }
                
                print("EntryUploadManager: Got download URL, saving parlay entry to Firestore")
                
                // Save the parlay entry to Firestore
                self?.saveParlayEntryToFirestore(
                    userId: userId,
                    imageURL: downloadURL,
                    competitionId: competitionId,
                    overlayText: overlayText,
                    overlayVerticalPosition: overlayVerticalPosition,
                    isFromCamera: isFromCamera,
                    themeId: themeId,
                    themeName: themeName,
                    competition: competition,
                    entryCost: entryCost,
                    predictions: predictions,
                    potentialPayout: potentialPayout,
                    onProgress: onProgress,
                    onSuccess: onSuccess,
                    onFailure: onFailure
                )
            }
        }
        
        // Handle upload failure
        uploadTask.observe(.failure) { [weak self] snapshot in
            // Cancel the timeout
            uploadTimeout.cancel()
            
            DispatchQueue.main.async {
                self?.isUploading = false
                if let error = snapshot.error {
                    print("EntryUploadManager: Upload failed: \(error.localizedDescription)")
                    onFailure(error)
                } else {
                    print("EntryUploadManager: Upload failed with unknown error")
                    onFailure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown upload error"]))
                }
            }
        }
    }
    
    // Save parlay entry data to Firestore
    private func saveParlayEntryToFirestore(
        userId: String,
        imageURL: String,
        competitionId: String,
        overlayText: String,
        overlayVerticalPosition: CGFloat,
        isFromCamera: Bool,
        themeId: String?,
        themeName: String?,
        competition: Competition,
        entryCost: Int,
        predictions: [String: Int],
        potentialPayout: Int,
        onProgress: @escaping (Double) -> Void,
        onSuccess: @escaping (String) -> Void,
        onFailure: @escaping (Error) -> Void
    ) {
        DispatchQueue.main.async {
            self.uploadProgress = 0.95
            onProgress(0.95)
        }
        
        // Get the current group size
        self.db.collection("competitions").document(competitionId).collection("members")
            .getDocuments { snapshot, error in
                    let groupSize = snapshot?.documents.count ?? 0
                    
                    // Convert predictions to new structure for Firestore
                    let predictionsForFirestore = predictions.reduce(into: [String: [String: Any]]()) { result, prediction in
                        result[prediction.key] = [
                            "predictedRating": prediction.value
                        ]
                    }
                    
                    // Create parlay entry data with new structure
                    var entryData: [String: Any] = [
                        "userId": userId,
                        "imageUrl": imageURL,
                        "timestamp": FieldValue.serverTimestamp(),
                        "overlayText": overlayText,
                        "overlayVerticalPosition": overlayVerticalPosition,
                        "isFromCamera": isFromCamera,
                        "stars": 0, // Initialize with 0 stars
                        // Parlay-specific data
                        "entryCost": entryCost,
                        "predictions": predictionsForFirestore,
                        "potentialPayout": potentialPayout,
                        "groupSizeAtEntry": groupSize,
                        "parlayStatus": "pending"
                    ]
                    
                    // Add theme information if available
                    if let themeId = themeId, let themeName = themeName {
                        entryData["themeId"] = themeId
                        entryData["themeName"] = themeName
                    }
                    
                    print("EntryUploadManager: Adding parlay entry document to Firestore with new structure")
                    
                    // Add the document to Firestore
                    let entriesRef = self.db.collection("competitions").document(competitionId).collection("entries")
                    
                    var newEntryRef: DocumentReference? = nil
                    newEntryRef = entriesRef.addDocument(data: entryData) { error in
                        DispatchQueue.main.async {
                            self.uploadProgress = 1.0
                            self.isUploading = false
                            onProgress(1.0)
                            
                            if let error = error {
                                print("EntryUploadManager: Error saving parlay entry: \(error)")
                                onFailure(error)
                            } else if let entryId = newEntryRef?.documentID {
                                print("EntryUploadManager: Parlay entry saved successfully with ID: \(entryId)")
                                
                                // Queue the notification
                                NotificationQueueManager.shared.queueNotification(
                                    competitionId: competitionId,
                                    competitionDescription: competition.description,
                                    userId: userId,
                                    type: .photo
                                )
                                
                                // Track analytics for parlay entry
                                Analytics.shared.trackEntry(
                                    action: "create_parlay",
                                    competitionId: competitionId,
                                    properties: [
                                        "has_text": !overlayText.isEmpty,
                                        "from_camera": isFromCamera,
                                        "has_theme": themeId != nil && themeName != nil,
                                        "entry_cost": entryCost,
                                        "predictions_count": predictions.count,
                                        "potential_payout": potentialPayout
                                    ]
                                )
                                
                                onSuccess(entryId)
                            } else {
                                onFailure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get entry ID"]))
                            }
                        }
                    }
                }
        }
}
