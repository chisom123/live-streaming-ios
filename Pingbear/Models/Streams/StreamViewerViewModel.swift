import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import LiveKit

// MARK: - StreamViewerViewModel
@MainActor
class StreamViewerViewModel: ObservableObject {

    @Published var messages:                [ChatMessage] = []
    @Published var chatText:                String        = ""
    @Published var isConnecting             = true
    @Published var isEnded                  = false
    @Published var errorMessage:            String?       = nil
    @Published var streamerTrack:           VideoTrack?   = nil

    // Real-time viewer count — updated by the stream document listener
    @Published var viewerCount:             Int           = 0

    // Active accepted request description — shown as "Now performing" banner.
    // Derived from a dedicated stream_requests listener so it updates instantly
    // when the streamer accepts or completes a request.
    @Published var activeRequestDescription: String?      = nil

    let stream: StreamModel
    private let db            = Firestore.firestore()
    private let functions     = Functions.functions()
    private let currentUserId = Auth.auth().currentUser?.uid ?? ""
    private var chatListener:     ListenerRegistration?
    private var streamListener:   ListenerRegistration?
    private var requestListener:  ListenerRegistration?
    private var joinedAt:         Date = Date()

    private var currentUserName:   String  = "Someone"
    private var currentUserAvatar: String? = nil

    let room = Room()

    init(stream: StreamModel) {
        self.stream      = stream
        self.viewerCount = stream.viewerIds.count
    }

    // MARK: - Fetch current user info
    private func fetchCurrentUserInfo() async {
        guard !currentUserId.isEmpty else { return }
        do {
            let doc  = try await db.collection("users").document(currentUserId).getDocument()
            let data = doc.data()
            currentUserName   = data?["name"]              as? String ?? "Someone"
            currentUserAvatar = data?["profilePictureUrl"] as? String
        } catch {}
    }

    // MARK: - Join
    func join() async {
        joinedAt = Date()
        await fetchCurrentUserInfo()

        // Register delegate BEFORE connecting so we never miss a track event.
        // If the delegate is added after room.connect(), a track that is already
        // published (e.g. streamer started before the viewer joined) will never
        // fire didSubscribeTrack, leaving the view with a permanent black screen.
        room.add(delegate: self)

        do {
            let result = try await functions.httpsCallable("joinStream").call(["streamId": stream.id])
            guard let data  = result.data as? [String: Any],
                  let token = data["token"]      as? String,
                  let url   = data["livekitUrl"] as? String
            else { throw NSError(domain: "Stream", code: -1) }

            try await room.connect(url: url, token: token)

            // After connecting, walk already-subscribed remote tracks.
            // This handles the case where the room was already running and
            // LiveKit delivered the track subscription before (or without)
            // firing the delegate callback — a known edge case on re-joins
            // and when joining a stream that has been live for a while.
            for participant in room.remoteParticipants.values {
                for publication in participant.trackPublications.values {
                    if let track = publication.track as? VideoTrack {
                        streamerTrack = track
                    }
                }
            }

            let latencyMs = Int(Date().timeIntervalSince(joinedAt) * 1000)
            Analytics.shared.trackStreamJoined(
                streamId:      stream.id,
                streamerId:    stream.streamerId,
                joinLatencyMs: latencyMs
            )

            isConnecting = false
            startListeners()
        } catch {
            errorMessage = error.localizedDescription
            isConnecting = false
        }
    }

    // MARK: - Leave
    func leave() {
        let watchSecs = Int(Date().timeIntervalSince(joinedAt))
        Analytics.shared.trackStreamLeft(streamId: stream.id, watchDurationSecs: watchSecs)
        chatListener?.remove()
        streamListener?.remove()
        requestListener?.remove()
        Task { await room.disconnect() }
    }

    // MARK: - Chat
    func sendChatMessage() {
        let text = chatText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, text.count <= 200 else { return }
        chatText = ""
        guard !currentUserId.isEmpty else { return }

        db.collection("stream_chat")
            .document(stream.id)
            .collection("messages")
            .document()
            .setData([
                "user_id":    currentUserId,
                "name":       currentUserName,
                "avatar_url": currentUserAvatar ?? NSNull(),
                "text":       text,
                "type":       ChatMessageType.chat.rawValue,
                "request_id": NSNull(),
                "created_at": FieldValue.serverTimestamp()
            ])

        Analytics.shared.track(
            event:      AnalyticsEvent.streamChatMessageSent,
            properties: [AnalyticsProperty.streamId: stream.id]
        )
    }

    // MARK: - Listeners
    private func startListeners() {
        // Chat
        chatListener = db.collection("stream_chat")
            .document(stream.id)
            .collection("messages")
            .order(by: "created_at", descending: false)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                self.messages = snap?.documents.compactMap { ChatMessage.from($0) } ?? []
            }

        // Stream document — real-time viewer count + ended status
        streamListener = db.collection("streams")
            .document(stream.id)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let data = snap?.data() else { return }
                if data["status"] as? String == "ended" {
                    self.isEnded = true
                }
                // viewer_ids array drives the live count
                let ids = data["viewer_ids"] as? [String] ?? []
                self.viewerCount = max(0, ids.count - 1)
            }

        // Active request — watch for a single accepted request on this stream.
        // When the streamer accepts one, this fires and shows the "Now performing" banner.
        // When they complete it (status → completed), the banner clears.
        requestListener = db.collection("stream_requests")
            .whereField("stream_id", isEqualTo: stream.id)
            .whereField("status", isEqualTo: "accepted")
            .limit(to: 1)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                self.activeRequestDescription = snap?.documents.first
                    .flatMap { StreamRequest.from($0) }?
                    .description
            }
    }
}

// MARK: - RoomDelegate
extension StreamViewerViewModel: RoomDelegate {
    nonisolated func room(_ room: Room, participant: RemoteParticipant,
                          didSubscribeTrack publication: RemoteTrackPublication) {
        guard let track = publication.track as? VideoTrack else { return }
        Task { @MainActor in self.streamerTrack = track }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant,
                          didUnsubscribeTrack publication: RemoteTrackPublication) {
        Task { @MainActor in self.streamerTrack = nil }
    }
}
