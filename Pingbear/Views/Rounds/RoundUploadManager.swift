import Foundation
import FirebaseStorage
import FirebaseAuth
import UIKit

extension UIImage {
    func optimizedForUpload(maxDimension: CGFloat = 1200.0, compressionQuality: CGFloat = 0.4) -> Data? {
        let resizedImage = self.resizeIfNeeded(maxDimension: maxDimension)
        return resizedImage.compressedData(compressionQuality: compressionQuality)
    }
    
    private func resizeIfNeeded(maxDimension: CGFloat) -> UIImage {
        let originalWidth = self.size.width
        let originalHeight = self.size.height
        
        // If the image is already smaller than our target, return the original
        if originalWidth <= maxDimension && originalHeight <= maxDimension {
            return self
        }
        
        // Figure out which dimension to scale based on
        let scaleFactor: CGFloat
        if originalWidth > originalHeight {
            scaleFactor = maxDimension / originalWidth
        } else {
            scaleFactor = maxDimension / originalHeight
        }
        
        let newWidth = originalWidth * scaleFactor
        let newHeight = originalHeight * scaleFactor
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        // Render the resized image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    private func compressedData(compressionQuality: CGFloat) -> Data? {
        var quality = compressionQuality
        var data = self.jpegData(compressionQuality: quality)
        let targetSize: Int = 500 * 1024
        while let imageData = data, imageData.count > targetSize && quality > 0.1 {
            quality -= 0.1
            data = self.jpegData(compressionQuality: quality)
        }
        return data
    }
}

class RoundUploadManager: ObservableObject {
    static let shared = RoundUploadManager()

    private let storage = Storage.storage(url: "gs://pingbear-96b4c-us")

    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0

    private init() {}

    // ─────────────────────────────────────────────────────────────
    // MARK: - Upload Round Photo
    //
    // 1. Optimizes image
    // 2. Uploads to Firebase Storage
    // 3. Returns download URL for use in joinRound
    //
    // No longer writes to entries collection — rounds are the
    // source of truth, not the old entries feed.
    // ─────────────────────────────────────────────────────────────

    func uploadRoundPhoto(
        image: UIImage,
        competitionId: String,
        themeId: String?,
        themeName: String?,
        isFromCamera: Bool,
        onProgress: @escaping (Double) -> Void,
        onSuccess: @escaping (String) -> Void,
        onFailure: @escaping (Error) -> Void
    ) {
        guard let userId = Auth.auth().currentUser?.uid else {
            onFailure(RoundUploadError.notAuthenticated)
            return
        }

        isUploading = true
        uploadProgress = 0.0
        onProgress(0.0)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            guard let imageData = image.optimizedForUpload() else {
                DispatchQueue.main.async {
                    self.isUploading = false
                    onFailure(RoundUploadError.imageOptimizationFailed)
                }
                return
            }

            print("RoundUploadManager: Image optimized. Size: \(Double(imageData.count) / 1024.0)KB")

            DispatchQueue.main.async {
                self.uploadProgress = 0.1
                onProgress(0.1)
                self.performUpload(
                    imageData: imageData,
                    userId: userId,
                    competitionId: competitionId,
                    onProgress: onProgress,
                    onSuccess: onSuccess,
                    onFailure: onFailure
                )
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Perform Upload
    // ─────────────────────────────────────────────────────────────

    private func performUpload(
        imageData: Data,
        userId: String,
        competitionId: String,
        onProgress: @escaping (Double) -> Void,
        onSuccess: @escaping (String) -> Void,
        onFailure: @escaping (Error) -> Void
    ) {
        // Organised path: competition/user/uuid for easier cleanup later
        let storageRef = storage.reference()
            .child("rounds/\(competitionId)/\(userId)/\(UUID().uuidString).jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "competitionId": competitionId,
            "userId":        userId,
            "source":        "round"
        ]

        let uploadTask = storageRef.putData(imageData, metadata: metadata)

        // Timeout after 45 seconds
        let timeout = DispatchWorkItem { [weak self] in
            uploadTask.cancel()
            DispatchQueue.main.async {
                self?.isUploading = false
                onFailure(RoundUploadError.timeout)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 45, execute: timeout)

        // Progress
        uploadTask.observe(.progress) { [weak self] snapshot in
            guard let percent = snapshot.progress?.fractionCompleted else { return }
            let scaled = 0.1 + (percent * 0.85) // 10% → 95%
            DispatchQueue.main.async {
                self?.uploadProgress = scaled
                onProgress(scaled)
            }
        }

        // Success
        uploadTask.observe(.success) { [weak self] _ in
            timeout.cancel()
            storageRef.downloadURL { [weak self] url, error in
                guard let self else { return }

                DispatchQueue.main.async {
                    self.uploadProgress = 1.0
                    self.isUploading = false
                    onProgress(1.0)

                    if let error {
                        onFailure(error)
                        return
                    }

                    guard let downloadURL = url?.absoluteString else {
                        onFailure(RoundUploadError.noDownloadURL)
                        return
                    }

                    print("RoundUploadManager: ✅ Upload complete. URL: \(downloadURL)")
                    onSuccess(downloadURL)
                }
            }
        }

        // Failure
        uploadTask.observe(.failure) { [weak self] snapshot in
            timeout.cancel()
            DispatchQueue.main.async {
                self?.isUploading = false
                onFailure(snapshot.error ?? RoundUploadError.uploadFailed)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Errors
// ─────────────────────────────────────────────────────────────

enum RoundUploadError: LocalizedError {
    case notAuthenticated
    case imageOptimizationFailed
    case timeout
    case uploadFailed
    case noDownloadURL

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:        return "You must be logged in to upload a photo."
        case .imageOptimizationFailed: return "Failed to process your photo."
        case .timeout:                 return "Upload timed out. Please try again."
        case .uploadFailed:            return "Upload failed. Please try again."
        case .noDownloadURL:           return "Failed to get photo URL."
        }
    }
}
