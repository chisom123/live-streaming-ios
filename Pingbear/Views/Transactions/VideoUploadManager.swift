import Foundation
import AVFoundation
import FirebaseStorage
import FirebaseAuth

// MARK: - VideoUploadManager (for request fulfillment)
/// Mirrors the UploadManager.shared.upload(image:) API but for video files.
/// Compresses to 720p before upload, calls back with a download URL string.

final class VideoUploadManager {
    static let shared = VideoUploadManager()
    private let storage = Storage.storage(url: "gs://pingbear-96b4c-us")
    private init() {}

    /// Compress → upload → return download URL string.
    /// `onProgress` called on main queue, 0.0 → 1.0.
    func upload(
        videoURL: URL,
        folderPath: String,
        onProgress: @escaping (Double) -> Void
    ) async throws -> String {
        guard Auth.auth().currentUser != nil else { throw VideoUploadError.notAuthenticated }

        onProgress(0.02)

        // 1. Compress on a background thread
        let compressed = try await compress(videoURL: videoURL)
        onProgress(0.10)

        // 2. Upload
        let remotePath = "\(folderPath)/\(UUID().uuidString).mp4"
        let ref        = storage.reference().child(remotePath)
        let meta       = StorageMetadata()
        meta.contentType = "video/mp4"

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            var timedOut  = false

            func resume(_ result: Result<String, Error>) {
                guard !didResume else { return }
                didResume = true
                switch result {
                case .success(let s): continuation.resume(returning: s)
                case .failure(let e): continuation.resume(throwing: e)
                }
            }

            let task = ref.putFile(from: compressed, metadata: meta)

            let timeout = DispatchWorkItem {
                timedOut = true
                task.cancel()
                resume(.failure(VideoUploadError.timeout))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 120, execute: timeout)

            task.observe(.progress) { snap in
                let frac = snap.progress?.fractionCompleted ?? 0
                DispatchQueue.main.async { onProgress(0.10 + frac * 0.85) }
            }

            task.observe(.success) { _ in
                guard !timedOut else { return }
                timeout.cancel()
                ref.downloadURL { url, error in
                    if let url {
                        DispatchQueue.main.async { onProgress(1.0) }
                        // Clean up compressed file
                        try? FileManager.default.removeItem(at: compressed)
                        resume(.success(url.absoluteString))
                    } else {
                        resume(.failure(error ?? VideoUploadError.noDownloadURL))
                    }
                }
            }

            task.observe(.failure) { snap in
                guard !timedOut else { return }
                timeout.cancel()
                try? FileManager.default.removeItem(at: compressed)
                resume(.failure(snap.error ?? VideoUploadError.unknown))
            }
        }
    }

    // MARK: - Compress

    private func compress(videoURL: URL) async throws -> URL {
        // Skip compression if already small (< 30 MB)
        if let size = try? videoURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size < 30 * 1_024 * 1_024 {
            return videoURL
        }

        return try await withCheckedThrowingContinuation { continuation in
            let asset   = AVAsset(url: videoURL)
            let outURL  = VideoRecordingViewModel.newTempURL()
            guard let session = AVAssetExportSession(
                asset: asset, presetName: AVAssetExportPreset1280x720
            ) else {
                continuation.resume(throwing: VideoUploadError.compressionFailed)
                return
            }
            session.outputURL             = outURL
            session.outputFileType        = .mp4
            session.shouldOptimizeForNetworkUse = true
            session.exportAsynchronously {
                switch session.status {
                case .completed: continuation.resume(returning: outURL)
                case .cancelled: continuation.resume(throwing: VideoUploadError.cancelled)
                default:         continuation.resume(throwing: session.error ?? VideoUploadError.compressionFailed)
                }
            }
        }
    }
}

// MARK: - Errors

enum VideoUploadError: LocalizedError {
    case notAuthenticated, compressionFailed, cancelled, timeout, noDownloadURL, unknown
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:  return "You must be logged in to upload."
        case .compressionFailed: return "Video compression failed."
        case .cancelled:         return "Upload was cancelled."
        case .timeout:           return "Upload timed out. Please try again."
        case .noDownloadURL:     return "Couldn't get the video URL."
        case .unknown:           return "An unexpected error occurred."
        }
    }
}
