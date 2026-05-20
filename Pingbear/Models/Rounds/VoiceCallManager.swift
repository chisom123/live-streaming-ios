import Foundation
import LiveKit
import FirebaseFunctions
import FirebaseAuth
import SwiftUI

// ─────────────────────────────────────────────────────────────
// MARK: - Call State
// ─────────────────────────────────────────────────────────────

enum CallState: Equatable {
    case idle
    case answering      // CallKit answered, waiting for LiveKit
    case connecting     // joinCall initiated by user tap
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

// ─────────────────────────────────────────────────────────────
// MARK: - Call Lifecycle Actor
//
// Serializes all state transitions so concurrent calls to
// joinCall / leaveCall / answerCall cannot race each other.
// ─────────────────────────────────────────────────────────────

private actor CallLifecycle {
    private var busy = false

    /// Returns true if the transition was accepted (we were idle).
    /// Returns false if already busy — caller should bail out.
    func tryBegin() -> Bool {
        guard !busy else { return false }
        busy = true
        return true
    }

    func end() { busy = false }
}

// ─────────────────────────────────────────────────────────────
// MARK: - VoiceCallManager
// ─────────────────────────────────────────────────────────────

class VoiceCallManager: NSObject, ObservableObject {
    static let shared = VoiceCallManager()

    @Published var callState: CallState = .idle
    @Published var isMuted: Bool = false
    @Published var participants: [CallParticipant] = []
    @Published var errorMessage: String? = nil

    var isConnected: Bool  { callState == .connected }
    var isConnecting: Bool { callState == .connecting || callState == .answering }

    private(set) var currentCompetitionId: String? = nil

    private let room      = Room()
    private let functions = Functions.functions()
    private let lifecycle = CallLifecycle()

    // Tracks whether we've sent an invite for the current session.
    // Prevents duplicate invites on reconnect within the same session.
    private var inviteSent = false

    private override init() {
        super.init()
        room.add(delegate: self)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Answer (called from CallKit delegate)
    //
    // Transitions to .answering immediately (sync) so CallKit
    // can fulfill() with no async delay.
    // sendInvite = false — we are the one answering, not calling.
    // ─────────────────────────────────────────────────────────

    func answerCall(competitionId: String, competitionName: String) {
        Task {
            let accepted = await lifecycle.tryBegin()
            guard accepted else {
                print("VoiceCallManager: answerCall ignored — already busy")
                return
            }

            await MainActor.run {
                self.callState = .answering
                self.currentCompetitionId = competitionId
                self.inviteSent = false
            }

            await connectToRoom(
                competitionId:   competitionId,
                competitionName: competitionName,
                sendInvite:      false
            )
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Join (called from UI button tap)
    //
    // sendInvite is only true when the room is empty — i.e. we
    // are the first person in. If others are already present
    // (detected via room.remoteParticipants after connect) we
    // joined silently and don't need to ring anyone.
    //
    // This is the core fix for the rejoin-rings-own-phone bug:
    // Phone B leaves, rejoins, connects to a room where Phone A
    // is already present → remoteParticipants.count > 0 →
    // sendInvite stays false → no VoIP push sent → no self-ring.
    // ─────────────────────────────────────────────────────────

    func joinCall(
        competitionId: String,
        competitionName: String,
        completion: @escaping (Bool) -> Void
    ) {
        Task {
            // Already in this exact room and connected — nothing to do
            if currentCompetitionId == competitionId, callState == .connected {
                completion(true)
                return
            }

            // In any other state — leave cleanly first
            if callState != .idle {
                await leaveCallAsync()
            }

            let accepted = await lifecycle.tryBegin()
            guard accepted else {
                print("VoiceCallManager: joinCall ignored — already busy")
                completion(false)
                return
            }

            await MainActor.run {
                self.callState = .connecting
                self.inviteSent = false
            }

            let success = await connectToRoom(
                competitionId:   competitionId,
                competitionName: competitionName,
                // sendInvite intent — connectToRoom will check whether
                // anyone else is already in the room before actually sending
                sendInvite:      true
            )
            completion(success)
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Core Connect
    //
    // The invite is sent AFTER:
    //   1. The mic track is confirmed published (so the caller
    //      is audible the moment others join)
    //   2. We confirm the room was empty when we joined (so
    //      rejoining a call that already has participants never
    //      sends a new VoIP push)
    // ─────────────────────────────────────────────────────────

    @discardableResult
    private func connectToRoom(
        competitionId: String,
        competitionName: String,
        sendInvite: Bool
    ) async -> Bool {

        // ── Fetch LiveKit token ───────────────────────────────
        let tokenResult = await fetchToken(competitionId: competitionId)
        guard case .success(let (token, url)) = tokenResult else {
            if case .failure(let error) = tokenResult {
                await handleConnectFailure(error: error.localizedDescription)
            }
            return false
        }

        // ── Connect to LiveKit room ───────────────────────────
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

            try await room.connect(
                url:            url,
                token:          token,
                connectOptions: connectOptions,
                roomOptions:    roomOptions
            )
        } catch {
            await handleConnectFailure(error: error.localizedDescription)
            return false
        }

        // ── Check if others are already in the room ───────────
        //
        // This is the key rejoin check. After connect(), LiveKit
        // has already synced room state. remoteParticipants is
        // populated if anyone else is present.
        //
        // - Empty room → we are first in → send invite to ring others
        // - Non-empty room → others are already here → join silently,
        //   no VoIP push, no one's phone rings unnecessarily
        let roomWasEmpty = room.remoteParticipants.isEmpty

        // ── Enable microphone ─────────────────────────────────
        // Done AFTER the empty-room check so the check reflects
        // remote participants only, not ourselves.
        // Done BEFORE sendInvite so we're audible when others join.
        do {
            try await room.localParticipant.setMicrophone(enabled: true)
        } catch {
            print("VoiceCallManager: mic enable failed: \(error.localizedDescription)")
        }

        // ── Update published state ────────────────────────────
        await MainActor.run {
            self.callState = .connected
            self.isMuted = false
            self.currentCompetitionId = competitionId
            self.rebuildParticipants()
        }

        // ── Send invite only if we were first in ─────────────
        //
        // sendInvite (caller intent) AND roomWasEmpty (reality check)
        // AND !inviteSent (dedup within session) must all be true.
        //
        // Scenarios:
        //  • First ever join into empty room → all three true → rings others ✅
        //  • Answerer joining → sendInvite=false → no ring ✅
        //  • Rejoin after leave, others still present → roomWasEmpty=false → no ring ✅
        //  • Rejoin into genuinely empty room (everyone left) → rings again ✅
        if sendInvite && roomWasEmpty && !inviteSent {
            inviteSent = true
            CallKitManager.shared.sendCallInvite(
                competitionId:   competitionId,
                competitionName: competitionName
            )
        }

        print("VoiceCallManager: connected to \(competitionId). roomWasEmpty=\(roomWasEmpty) inviteSent=\(inviteSent)")
        return true
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Connect Failure
    // ─────────────────────────────────────────────────────────

    private func handleConnectFailure(error: String) async {
        await lifecycle.end()
        await MainActor.run {
            self.callState = .idle
            self.currentCompetitionId = nil
            self.errorMessage = error
            CallKitManager.shared.endActiveCall(reason: .failed)
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Fetch Token
    // ─────────────────────────────────────────────────────────

    private func fetchToken(competitionId: String) async -> Result<(String, String), Error> {
        await withCheckedContinuation { continuation in
            functions.httpsCallable("getLiveKitToken").call([
                "competitionId": competitionId
            ]) { result, error in
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
    // MARK: - Leave Call (public — UI / CallKit)
    //
    // Safe to call multiple times. If already disconnecting or
    // idle the call is a no-op.
    // ─────────────────────────────────────────────────────────

    func leaveCall(completion: (() -> Void)? = nil) {
        Task {
            await leaveCallAsync()
            completion?()
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Leave Call (async — internal)
    //
    // Awaitable so joinCall can do leave→rejoin sequentially.
    // ─────────────────────────────────────────────────────────

    func leaveCallAsync() async {
        guard callState != .idle && callState != .disconnecting else { return }

        await MainActor.run { self.callState = .disconnecting }

        await room.disconnect()
        await lifecycle.end()

        await MainActor.run {
            self.callState            = .idle
            self.isMuted              = false
            self.participants         = []
            self.currentCompetitionId = nil
            self.errorMessage         = nil
            self.inviteSent           = false
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Mute
    // ─────────────────────────────────────────────────────────

    func toggleMute() {
        let newMuted = !isMuted
        Task {
            try? await room.localParticipant.setMicrophone(enabled: !newMuted)
            await MainActor.run {
                self.isMuted = newMuted
                self.rebuildParticipants()
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Rebuild Participants
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
        print("VoiceCallManager: \(old) → \(state)")
        Task { @MainActor in
            switch state {
            case .disconnected:
                // Only wipe if WE initiated — unexpected drops let LiveKit reconnect
                if self.callState == .disconnecting {
                    self.callState    = .idle
                    self.participants = []
                }
            case .reconnecting:
                break // stay visually connected
            case .connected:
                self.callState = .connected
                self.rebuildParticipants()
            default:
                break
            }
        }
    }

    func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        Task { @MainActor in self.rebuildParticipants() }
    }

    func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
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
        Task { @MainActor in self.rebuildParticipants() }
    }
}
