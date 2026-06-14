import Foundation
import FirebaseStorage
import FirebaseAuth
import UIKit

// ─────────────────────────────────────────────────────────────
// MARK: - UIImage + Optimization
// ─────────────────────────────────────────────────────────────

extension UIImage {
    func optimizedForUpload(maxDimension: CGFloat = 1200, compressionQuality: CGFloat = 0.4) -> Data? {
        let resized = resizeIfNeeded(maxDimension: maxDimension)
        return resized.compressedJPEG(quality: compressionQuality)
    }

    private func resizeIfNeeded(maxDimension: CGFloat) -> UIImage {
        guard size.width > maxDimension || size.height > maxDimension else { return self }
        let scale    = maxDimension / max(size.width, size.height)
        let newSize  = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    private func compressedJPEG(quality: CGFloat) -> Data? {
        let targetBytes = 500 * 1024
        var q    = quality
        var data = jpegData(compressionQuality: q)
        while let d = data, d.count > targetBytes, q > 0.1 {
            q   -= 0.1
            data = jpegData(compressionQuality: q)
        }
        return data
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Upload Error
// ─────────────────────────────────────────────────────────────

enum UploadError: LocalizedError {
    case notAuthenticated
    case optimizationFailed
    case timeout
    case noDownloadURL
    case storageFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:     return "You must be logged in to upload."
        case .optimizationFailed:   return "Failed to process your photo."
        case .timeout:              return "Upload timed out. Please try again."
        case .noDownloadURL:        return "Failed to get photo URL."
        case .storageFailed(let e): return e.localizedDescription
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - UploadManager
//
// Generic upload manager. The caller constructs the folder path
// and passes it in — this manager is not coupled to any
// particular collection or data model.
//
// Example usage:
//   let url = try await UploadManager.shared.upload(
//     image: image,
//     folderPath: "competitions/\(competitionId)/\(userId)",
//     onProgress: { progress in ... }
//   )
// ─────────────────────────────────────────────────────────────

final class UploadManager {
    static let shared = UploadManager()
    private let storage = Storage.storage(url: "gs://pingbear-96b4c-us")
    private init() {}

    /// Upload an image to the given folder path and return its download URL.
    /// `onProgress` is always called on the main queue.
    func upload(
        image: UIImage,
        folderPath: String,
        onProgress: @escaping (Double) -> Void
    ) async throws -> String {
        guard Auth.auth().currentUser != nil else {
            throw UploadError.notAuthenticated
        }

        // Optimize on a background thread
        let imageData: Data = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                if let data = image.optimizedForUpload() {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: UploadError.optimizationFailed)
                }
            }
        }

        AppLogger.upload("[Upload] optimized — \(String(format: "%.1f", Double(imageData.count) / 1024))KB")
        DispatchQueue.main.async { onProgress(0.05) }

        let path     = "\(folderPath)/\(UUID().uuidString).jpg"
        let ref      = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        return try await withCheckedThrowingContinuation { continuation in
            let task = ref.putData(imageData, metadata: metadata)

            var timedOut  = false
            var didResume = false

            func resume(with result: Result<String, Error>) {
                guard !didResume else { return }
                didResume = true
                switch result {
                case .success(let url): continuation.resume(returning: url)
                case .failure(let err): continuation.resume(throwing: err)
                }
            }

            let timeoutWork = DispatchWorkItem {
                timedOut = true
                task.cancel()
                resume(with: .failure(UploadError.timeout))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 45, execute: timeoutWork)

            task.observe(.progress) { snap in
                let fraction = snap.progress?.fractionCompleted ?? 0
                let scaled   = 0.05 + fraction * 0.90
                DispatchQueue.main.async { onProgress(scaled) }
            }

            task.observe(.success) { _ in
                guard !timedOut else { return }
                timeoutWork.cancel()
                ref.downloadURL { url, error in
                    if let error {
                        resume(with: .failure(UploadError.storageFailed(error)))
                        return
                    }
                    guard let urlString = url?.absoluteString else {
                        resume(with: .failure(UploadError.noDownloadURL))
                        return
                    }
                    DispatchQueue.main.async { onProgress(1.0) }
                    AppLogger.upload("[Upload] ✅ done — \(path)")
                    resume(with: .success(urlString))
                }
            }

            task.observe(.failure) { snap in
                guard !timedOut else { return }
                timeoutWork.cancel()
                let err = snap.error ?? UploadError.storageFailed(
                    NSError(domain: "UploadManager", code: -1, userInfo: nil)
                )
                resume(with: .failure(err))
            }
        }
    }
}
