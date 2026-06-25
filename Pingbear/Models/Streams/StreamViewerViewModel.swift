import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import LiveKit

// MARK: - StreamViewerViewModel
@MainActor
class StreamViewerViewModel: ObservableObject {

    @Published var messages:      [ChatMessage] = []
    @Published var chatText:      String        = ""
    @Published var isConnecting   = true
    @Published var isEnded        = false
    @Published var errorMessage:  String?       = nil
    @Published var streamerTrack: VideoTrack?   = nil

    let stream: StreamModel
    private let db            = Firestore.firestore()
    private let functions     = Functions.functions()
    private let currentUserId = Auth.auth().currentUser?.uid ?? ""
    private var chatListener:   ListenerRegistration?
    private var streamListener: ListenerRegistration?
    private var joinedAt:       Date = Date()

    private var currentUserName:   String  = "Someone"
    private var currentUserAvatar: String? = nil

    let room = Room()

    init(stream: StreamModel) {
        self.stream = stream
    }

    // MARK: - Fetch current user info
    private func fetchCurrentUserInfo() async {
        guard !currentUserId.isEmpty else { return }
        do {
            let userDoc  = try await db.collection("users").document(currentUserId).getDocument()
            let userData = userDoc.data()
            currentUserName   = userData?["name"]               as? String ?? "Someone"
            currentUserAvatar = userData?["profilePictureUrl"]  as? String
        } catch {}
    }

    // MARK: - Join
    func join() async {
        joinedAt = Date()
        await fetchCurrentUserInfo()

        do {
            let result = try await functions.httpsCallable("joinStream").call(["streamId": stream.id])
            guard let data  = result.data as? [String: Any],
                  let token = data["token"]      as? String,
                  let url   = data["livekitUrl"] as? String
            else { throw NSError(domain: "Stream", code: -1) }

            try await room.connect(url: url, token: token)

            let latencyMs = Int(Date().timeIntervalSince(joinedAt) * 1000)
            Analytics.shared.trackStreamJoined(
                streamId:      stream.id,
                streamerId:    stream.streamerId,
                joinLatencyMs: latencyMs
            )

            isConnecting = false
            observeRemoteTracks()
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

        Analytics.shared.track(event: AnalyticsEvent.streamChatMessageSent,
                                properties: [AnalyticsProperty.streamId: stream.id])
    }

    // MARK: - Listeners
    private func startListeners() {
        chatListener = db.collection("stream_chat")
            .document(stream.id)
            .collection("messages")
            .order(by: "created_at", descending: false)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                self.messages = snap?.documents.compactMap { ChatMessage.from($0) } ?? []
            }

        streamListener = db.collection("streams")
            .document(stream.id)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let data = snap?.data() else { return }
                if data["status"] as? String == "ended" {
                    self.isEnded = true
                }
            }
    }

    private func observeRemoteTracks() {
        room.add(delegate: self)
    }
}

// MARK: - RoomDelegate
extension StreamViewerViewModel: RoomDelegate {
    nonisolated func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        guard let track = publication.track as? VideoTrack else { return }
        Task { @MainActor in self.streamerTrack = track }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didUnsubscribeTrack publication: RemoteTrackPublication) {
        Task { @MainActor in self.streamerTrack = nil }
    }
}
