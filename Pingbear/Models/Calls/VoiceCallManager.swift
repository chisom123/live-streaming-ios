import Foundation
import LiveKit
import FirebaseFunctions
import FirebaseAuth
import SwiftUI
import CallKit

enum CallState: Equatable {
    case idle
    case connecting
    case answering
    case connected
    case disconnecting
}

struct CallParticipant: Identifiable {
    let id: String
    let username: String
    let profilePictureUrl: String?
    var isSpeaking: Bool
    var isMuted: Bool
    var isCurrentUser: Bool
}

private actor CallLifecycle {
    private var busy = false
    func tryBegin() -> Bool {
        guard !busy else { return false }
        busy = true
        return true
    }
    func end() { busy = false }
}

class VoiceCallManager: NSObject, ObservableObject {
    static let shared = VoiceCallManager()

    @Published var callState: CallState = .idle
    @Published var isMuted: Bool = false
    @Published var participants: [CallParticipant] = []
    @Published var errorMessage: String? = nil

    var isConnected:  Bool { callState == .connected }
    var isConnecting: Bool { callState == .connecting || callState == .answering }

    private(set) var currentSessionId: String? = nil

    private let room      = Room()
    private let functions = Functions.functions()
    private let lifecycle = CallLifecycle()
    private var isReconnecting = false

    private override init() {
        super.init()
        AppLogger.audio("VoiceCallManager init — disabling automatic audio config")
        AudioManager.shared.audioSession.isAutomaticConfigurationEnabled = false
        try? AudioManager.shared.setEngineAvailability(.none)
        room.add(delegate: self)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Outgoing Call
    // ─────────────────────────────────────────────────────────

    func joinCall(
        sessionId: String,
        displayName: String = "Call",
        completion: @escaping (Bool) -> Void
    ) {
        Task {
            AppLogger.call("joinCall START — sessionId=\(sessionId) state=\(callState) isReconnecting=\(isReconnecting)")

            if currentSessionId == sessionId, callState == .connected {
                AppLogger.call("joinCall — already connected to this session")
                completion(true)
                return
            }

            if callState != .idle {
                AppLogger.call("joinCall — leaving existing call first")
                isReconnecting = true
                await leaveCallAsync()
                isReconnecting = false
                AppLogger.call("joinCall — leave complete, state=\(callState)")
            }

            let accepted = await lifecycle.tryBegin()
            guard accepted else {
                AppLogger.call("joinCall BLOCKED — lifecycle busy")
                completion(false)
                return
            }
            AppLogger.call("joinCall — lifecycle accepted")

            await MainActor.run {
                self.callState        = .connecting
                self.currentSessionId = sessionId
            }

            AppLogger.call("joinCall — reporting outgoing call to CallKit")
            CallKitManager.shared.reportOutgoingCall(sessionId: sessionId, displayName: displayName)

            AppLogger.livekit("joinCall — starting room connection")
            let success = await connectToRoom(sessionId: sessionId)
            AppLogger.call("joinCall END — success=\(success) state=\(callState)")
            completion(success)
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Incoming Call
    // ─────────────────────────────────────────────────────────

    func answerCall(sessionId: String) {
        Task {
            AppLogger.ring("answerCall START — sessionId=\(sessionId) state=\(callState)")

            let accepted = await lifecycle.tryBegin()
            guard accepted else {
                AppLogger.ring("answerCall BLOCKED — lifecycle busy")
                return
            }

            await MainActor.run {
                self.callState        = .answering
                self.currentSessionId = sessionId
            }

            AppLogger.livekit("answerCall — starting room connection")
            let success = await connectToRoom(sessionId: sessionId)
            AppLogger.ring("answerCall END — success=\(success) state=\(callState)")
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Core Connect
    // ─────────────────────────────────────────────────────────

    @discardableResult
    private func connectToRoom(sessionId: String) async -> Bool {
        AppLogger.livekit("connectToRoom — fetching token for sessionId=\(sessionId)")

        let tokenResult = await fetchToken(sessionId: sessionId)
        guard case .success(let (token, url)) = tokenResult else {
            if case .failure(let error) = tokenResult {
                AppLogger.livekit("connectToRoom — token fetch FAILED: \(error.localizedDescription)")
                await handleConnectFailure(error: error.localizedDescription)
            }
            return false
        }
        AppLogger.livekit("connectToRoom — token OK, url=\(url)")

        do {
            let connectOptions = ConnectOptions(autoSubscribe: true)
            let roomOptions = RoomOptions(
                defaultAudioCaptureOptions: AudioCaptureOptions(
                    echoCancellation:  true,
                    autoGainControl:   true,
                    noiseSuppression:  true,
                    highpassFilter:    true
                ),
                defaultAudioPublishOptions: AudioPublishOptions(dtx: true)
            )

            AppLogger.livekit("connectToRoom — calling room.connect()")
            try await room.connect(url: url, token: token, connectOptions: connectOptions, roomOptions: roomOptions)
            AppLogger.livekit("connectToRoom — room.connect() succeeded")
        } catch {
            AppLogger.livekit("connectToRoom — room.connect() FAILED: \(error.localizedDescription)")
            await handleConnectFailure(error: error.localizedDescription)
            return false
        }

        AppLogger.audio("connectToRoom — activating audio engine")
        CallKitManager.shared.activateAudioEngineIfNeeded()

        AppLogger.livekit("connectToRoom — enabling microphone")
        do {
            try await room.localParticipant.setMicrophone(enabled: true)
            AppLogger.livekit("connectToRoom — microphone enabled ✅")
        } catch {
            AppLogger.livekit("connectToRoom — mic enable FAILED: \(error.localizedDescription)")
        }

        await MainActor.run {
            self.callState = .connected
            self.isMuted   = false
            self.rebuildParticipants()
        }

        AppLogger.livekit("connectToRoom ✅ — fully connected to session=\(sessionId) participants=\(participants.count)")
        return true
    }

    private func handleConnectFailure(error: String) async {
        AppLogger.livekit("handleConnectFailure — \(error)")
        await lifecycle.end()
        await MainActor.run {
            self.callState        = .idle
            self.currentSessionId = nil
            self.errorMessage     = error
            CallKitManager.shared.endActiveCall(reason: .failed)
        }
    }

    private func fetchToken(sessionId: String) async -> Result<(String, String), Error> {
        await withCheckedContinuation { continuation in
            functions.httpsCallable("getLiveKitToken").call(["sessionId": sessionId]) { result, error in
                if let error {
                    continuation.resume(returning: .failure(error))
                    return
                }
                guard
                    let data  = result?.data as? [String: Any],
                    let token = data["token"] as? String,
                    let url   = data["url"]   as? String
                else {
                    continuation.resume(returning: .failure(
                        NSError(domain: "VoiceCallManager", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Invalid token response"])
                    ))
                    return
                }
                continuation.resume(returning: .success((token, url)))
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Leave Call
    // ─────────────────────────────────────────────────────────

    func leaveCall(completion: (() -> Void)? = nil) {
        Task {
            await leaveCallAsync()
            completion?()
        }
    }

    func leaveCallAsync() async {
        AppLogger.call("leaveCallAsync — state=\(callState) isReconnecting=\(isReconnecting)")
        guard callState != .idle && callState != .disconnecting else {
            AppLogger.call("leaveCallAsync — skipped (already \(callState))")
            return
        }

        await MainActor.run { self.callState = .disconnecting }
        AppLogger.livekit("leaveCallAsync — disconnecting room")

        await room.disconnect()
        await lifecycle.end()
        AppLogger.livekit("leaveCallAsync — room disconnected")

        await MainActor.run {
            if !self.isReconnecting {
                self.callState = .idle
                AppLogger.call("leaveCallAsync — state → idle")
            } else {
                AppLogger.call("leaveCallAsync — suppressed .idle (reconnecting)")
            }
            self.isMuted          = false
            self.participants     = []
            self.currentSessionId = nil
            self.errorMessage     = nil
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Mute
    // ─────────────────────────────────────────────────────────

    func toggleMute() {
        let newMuted = !isMuted
        AppLogger.audio("toggleMute — muted=\(newMuted)")
        Task {
            try? await room.localParticipant.setMicrophone(enabled: !newMuted)
            await MainActor.run {
                self.isMuted = newMuted
                self.rebuildParticipants()
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Participants
    // ─────────────────────────────────────────────────────────

    private func rebuildParticipants() {
        guard callState == .connected || callState == .answering else { return }

        var result: [CallParticipant] = []
        let local     = room.localParticipant
        let localMeta = parseMetadata(local.metadata)

        result.append(CallParticipant(
            id:                local.identity?.stringValue ?? "me",
            username:          "Me",
            profilePictureUrl: localMeta?.profilePictureUrl,
            isSpeaking:        local.isSpeaking,
            isMuted:           isMuted,
            isCurrentUser:     true
        ))

        for (_, participant) in room.remoteParticipants {
            let meta          = parseMetadata(participant.metadata)
            let isRemoteMuted = participant.trackPublications.values
                .first(where: { $0.kind == .audio })?.isMuted ?? true

            result.append(CallParticipant(
                id:                participant.identity?.stringValue ?? UUID().uuidString,
                username:          meta?.username ?? "Unknown",
                profilePictureUrl: meta?.profilePictureUrl,
                isSpeaking:        participant.isSpeaking,
                isMuted:           isRemoteMuted,
                isCurrentUser:     false
            ))
        }
        participants = result
    }

    private struct ParticipantMetadata: Decodable {
        let username: String?
        let profilePictureUrl: String?
    }

    private func parseMetadata(_ metadata: String?) -> ParticipantMetadata? {
        guard let metadata, let data = metadata.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ParticipantMetadata.self, from: data)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - RoomDelegate
// ─────────────────────────────────────────────────────────────

extension VoiceCallManager: RoomDelegate {

    func room(_ room: Room, didUpdateConnectionState state: ConnectionState, from old: ConnectionState) {
        AppLogger.livekit("room state \(old) → \(state)")
        Task { @MainActor in
            switch state {
            case .disconnected:
                if self.callState == .disconnecting && !self.isReconnecting {
                    self.callState    = .idle
                    self.participants = []
                    AppLogger.livekit("room disconnected → callState=idle")
                }
            case .connected:
                self.callState = .connected
                self.rebuildParticipants()
                AppLogger.livekit("room connected — participants=\(self.participants.count)")
            case .reconnecting:
                AppLogger.livekit("room reconnecting...")
            default:
                break
            }
        }
    }

    func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        AppLogger.livekit("participant joined — id=\(participant.identity?.stringValue ?? "?") total=\(room.remoteParticipants.count + 1)")
        Task { @MainActor in self.rebuildParticipants() }
    }

    func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        AppLogger.livekit("participant left — id=\(participant.identity?.stringValue ?? "?") remaining=\(room.remoteParticipants.count)")
        Task { @MainActor in self.rebuildParticipants() }
    }

    func room(_ room: Room, participant: Participant, didUpdateIsSpeaking isSpeaking: Bool) {
        Task { @MainActor in self.rebuildParticipants() }
    }

    func room(_ room: Room, participant: Participant, didUpdateMetadata metadata: String?) {
        Task { @MainActor in self.rebuildParticipants() }
    }

    func room(_ room: Room, participant: RemoteParticipant,
              didUpdatePublication publication: RemoteTrackPublication, muted: Bool) {
        AppLogger.audio("participant \(participant.identity?.stringValue ?? "?") audio muted=\(muted)")
        Task { @MainActor in self.rebuildParticipants() }
    }
}
