import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import LiveKit
import AVFoundation

// MARK: - StreamerViewModel
@MainActor
class StreamerViewModel: ObservableObject {

    @Published var pendingRequests:  [StreamRequest]   = []
    @Published var acceptedRequests: [StreamRequest]   = []
    @Published var messages:         [ChatMessage]     = []
    @Published var isLive            = false
    @Published var isConnecting      = true
    @Published var totalEarned:      Double            = 0
    @Published var viewerCount:      Int               = 0
    @Published var errorMessage:     String?           = nil
    @Published var showEndConfirm    = false
    @Published var isEnding          = false
    @Published var localVideoTrack:  LocalVideoTrack?  = nil

    // Tracks whether the streamer is on front camera.
    // Defaults true (front camera is the default on stream start).
    // Written to Firestore whenever the streamer flips cameras so
    // viewers can mirror the video correctly.
    @Published var isFrontCamera: Bool = true

    // True from stream start until the first viewer joins.
    @Published var isCallingFriends: Bool = true

    let streamId:     String
    var initialToken: String?
    var initialUrl:   String?

    private let db        = Firestore.firestore()
    private let functions = Functions.functions()
    private var requestsListener: ListenerRegistration?
    private var chatListener:     ListenerRegistration?
    private var streamListener:   ListenerRegistration?
    private var startedAt:        Date = Date()

    let room = Room()

    init(streamId: String, initialToken: String? = nil, initialUrl: String? = nil) {
        self.streamId     = streamId
        self.initialToken = initialToken
        self.initialUrl   = initialUrl
    }

    // MARK: - Start
    func startBroadcast() async {
        startedAt = Date()
        if let token = initialToken, let url = initialUrl {
            await connectWithToken(token: token, url: url)
            return
        }
        errorMessage = "Stream token missing. Please start a new stream."
        isConnecting = false
    }

    private func connectWithToken(token: String, url: String) async {
        do {
            try await room.connect(url: url, token: token)
            let camera = LocalVideoTrack.createCameraTrack()
            let mic    = LocalAudioTrack.createTrack()
            try await room.localParticipant.publish(videoTrack: camera)
            localVideoTrack = camera
            do { try await room.localParticipant.publish(audioTrack: mic) } catch {}
            isConnecting = false
            isLive       = true

            // Write initial camera position to Firestore so viewers
            // receive the correct mirror state from the moment they join.
            updateCameraPositionInFirestore(isFront: true)

            startListeners()
            Task {
                do { try await functions.httpsCallable("startStreamRecording").call(["streamId": streamId]) }
                catch { print("[StreamerViewModel] startStreamRecording failed: \(error.localizedDescription)") }
            }
        } catch {
            errorMessage = error.localizedDescription
            isConnecting = false
        }
    }

    // MARK: - Camera position
    /// Writes the current camera facing direction to the stream document.
    /// Called on connect (front camera default) and whenever the streamer flips.
    /// The Firestore rule allows only this field to be updated while status == 'live'.
    func updateCameraPositionInFirestore(isFront: Bool) {
        db.collection("streams").document(streamId).updateData([
            "is_front_camera": isFront
        ])
    }

    // MARK: - End stream
    func endStream() async {
        isEnding = true
        let durationSecs = Int(Date().timeIntervalSince(startedAt))
        do {
            try await functions.httpsCallable("endStream").call(["streamId": streamId])
            Analytics.shared.trackStreamEnded(
                streamId:     streamId,
                durationSecs: durationSecs,
                totalEarned:  totalEarned,
                requestCount: pendingRequests.count + acceptedRequests.count,
                viewerCount:  viewerCount
            )
            await room.disconnect()
        } catch {
            errorMessage = error.localizedDescription
            isEnding     = false
        }
    }

    // MARK: - Requests
    func acceptRequest(_ request: StreamRequest) {
        Task {
            do {
                try await functions.httpsCallable("respondToStreamRequest").call([
                    "requestId": request.id, "accept": true
                ])
                Analytics.shared.trackStreamRequest(
                    action: "accepted", streamId: streamId,
                    requestId: request.id, amount: request.price
                )
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func declineRequest(_ request: StreamRequest) {
        Task {
            do {
                try await functions.httpsCallable("respondToStreamRequest").call([
                    "requestId": request.id, "accept": false
                ])
                Analytics.shared.trackStreamRequest(
                    action: "declined", streamId: streamId,
                    requestId: request.id, amount: request.price
                )
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func completeRequest(_ request: StreamRequest) {
        Task {
            do {
                try await functions.httpsCallable("completeStreamRequest").call(["requestId": request.id])
                Analytics.shared.trackStreamRequest(
                    action: "completed", streamId: streamId,
                    requestId: request.id, amount: request.price,
                    payout: request.creatorPayout
                )
            } catch { errorMessage = error.localizedDescription }
        }
    }

    // MARK: - Listeners
    private func startListeners() {
        requestsListener = db.collection("stream_requests")
            .whereField("stream_id", isEqualTo: streamId)
            .whereField("status", in: ["pending", "accepted"])
            .addSnapshotListener { [weak self] snap, error in
                guard let self else { return }
                if let error { self.errorMessage = error.localizedDescription; return }
                let all = snap?.documents.compactMap { StreamRequest.from($0) } ?? []
                self.pendingRequests  = all.filter { $0.status == .pending }
                    .sorted { $0.createdAt < $1.createdAt }
                self.acceptedRequests = all.filter { $0.status == .accepted }
                    .sorted { ($0.acceptedAt ?? $0.createdAt) < ($1.acceptedAt ?? $1.createdAt) }
            }

        chatListener = db.collection("stream_chat")
            .document(streamId).collection("messages")
            .order(by: "created_at", descending: false)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                self.messages = snap?.documents.compactMap { ChatMessage.from($0) } ?? []
            }

        streamListener = db.collection("streams").document(streamId)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let data = snap?.data() else { return }
                self.totalEarned = data["total_earned"] as? Double ?? 0
                let viewerIds    = data["viewer_ids"] as? [String] ?? []
                self.viewerCount = viewerIds.count

                if !viewerIds.isEmpty {
                    self.isCallingFriends = false
                }
            }
    }

    func stopListening() {
        requestsListener?.remove()
        chatListener?.remove()
        streamListener?.remove()
    }
}
