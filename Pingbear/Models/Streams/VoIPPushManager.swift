import Foundation
import UIKit
import PushKit
import CallKit
import AVFAudio
import FirebaseAuth
import FirebaseFirestore

// MARK: - VoIPCallInfo
struct VoIPCallInfo {
    let callUUID:     UUID
    let streamId:     String
    let streamerName: String
    let streamerId:   String
}

// MARK: - VoIPPushManager
//
// Owns the PushKit registry, CallKit provider, and Firestore token persistence.
//
// Token healing
// ─────────────
// VoIPTokenWatcher holds a real-time Firestore listener on the user document.
// It detects two failure modes:
//
//   1. Missing/empty voipToken  — healed immediately on the first snapshot.
//   2. Stale token              — detected by comparing the Firestore value
//                                 against currentTokenString (the last token
//                                 PushKit delivered to this device).
//
// Recovery has two steps:
//   Step 1 — persistTokenDirectly() writes a known-good token straight to
//             Firestore. This handles rapid user switches where PushKit
//             rate-limits re-delivery and didUpdate pushCredentials never fires.
//   Step 2 — syncTokenForCurrentUser() triggers a PushKit re-delivery as a
//             belt-and-braces fallback, ensuring the token is always eventually
//             refreshed from the authoritative source.
//
// Failed Firestore writes are retried up to 3 times with exponential backoff
// (2 s, 4 s, 6 s). On final failure the token is stashed in UserDefaults so
// the watcher can detect the mismatch on the next snapshot or foreground
// resume and trigger recovery again.
//
// CallKit audio session handling
// ──────────────────────────────
// CallKit is used purely as a ringer/launcher — the actual media is LiveKit,
// not a CallKit-managed call. When a call is answered, iOS puts the audio
// session into "phone call" mode under CallKit's ownership. If the CallKit
// call is left alive, LiveKit plays remote audio into a session it doesn't
// own and the viewer hears silence.
//
// Fix: the moment CXAnswerCallAction fulfills, the call is reported as ended
// (reportCall(with:endedAt:reason:)), releasing the AVAudioSession back to
// the app before LiveKit connects. reportCall is a *report*, not an action,
// so it does NOT trigger the CXEndCallAction handler — and the call is
// removed from activeCalls first, so no path can mistake the accept for a
// decline. CallKit state is entirely local per device: ending the call on
// the accepting viewer's phone has no effect on other viewers' ringers.

final class VoIPPushManager: NSObject {

    static let shared = VoIPPushManager()

    var onAcceptCall:  ((VoIPCallInfo) -> Void)?
    var onDeclineCall: ((VoIPCallInfo) -> Void)?

    // Exposed so VoIPTokenWatcher can compare against the Firestore value
    // and detect stale tokens, not just missing ones.
    private(set) var currentTokenString: String? = nil

    private let registry       = PKPushRegistry(queue: .main)
    private let provider:        CXProvider
    private let callController = CXCallController()
    private var activeCalls:   [UUID: VoIPCallInfo] = [:]

    // The UUID of a call that was answered while the app was NOT active
    // (killed or backgrounded). The CallKit call is kept alive until the
    // app reaches the foreground — iOS only launches/foregrounds the app
    // for an *active* call — and is then ended to release the audio
    // session back to the app. See CXAnswerCallAction below.
    private var pendingAnsweredCallUUID: UUID?
    private var foregroundObserver:      NSObjectProtocol?

    // Gate for LiveKit: true from the moment a call is answered until
    // CallKit has released the audio session (didDeactivate, or a fallback
    // timer after the call-end report). While true, StreamViewerViewModel
    // parks in waitUntilCallKitAudioReleased() before room.connect —
    // otherwise LiveKit starts its audio engine inside CallKit's session,
    // the engine fails (AURemoteIO error) and never retries → silent stream.
    private var awaitingSessionRelease = false
    private var audioReleaseWaiters: [CheckedContinuation<Void, Never>] = []

    // MARK: - Init

    private override init() {
        let config = CXProviderConfiguration(localizedName: "SocialStar")
        config.supportsVideo            = true
        config.maximumCallsPerCallGroup = 1
        config.maximumCallGroups        = 1
        config.supportedHandleTypes     = [.generic]
        config.iconTemplateImageData    = UIImage(named: "Logo-T")?.pngData()
        config.ringtoneSound            = nil

        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: nil)
        print("[VoIPPushManager] Initialised")
    }

    // MARK: - Public API

    /// Parks until CallKit has fully released the audio session after an
    /// answered call. StreamViewerViewModel calls this immediately before
    /// room.connect. If no CallKit answer is in flight, returns instantly,
    /// so it costs nothing on the normal in-app join path.
    func waitUntilCallKitAudioReleased() async {
        let mustWait: Bool = await MainActor.run { self.awaitingSessionRelease }
        guard mustWait else { return }

        AudioDebug.log("⏸ LiveKit join gated", "waiting for CallKit to release the audio session")
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                // Re-check on main in case release happened while hopping queues.
                guard self.awaitingSessionRelease else { cont.resume(); return }
                self.audioReleaseWaiters.append(cont)
            }
        }
        AudioDebug.log("▶️ LiveKit join released", "audio session is now free")
    }

    /// Resumes any parked join waiters. Called from CallKit's didDeactivate
    /// (the authoritative "session is free" signal) and from a 1 s fallback
    /// timer after the call-end report, in case didDeactivate never fires.
    /// Must be called on the main queue.
    private func resumeAudioWaiters(reason: String) {
        guard awaitingSessionRelease || !audioReleaseWaiters.isEmpty else { return }
        awaitingSessionRelease = false
        let waiters = audioReleaseWaiters
        audioReleaseWaiters.removeAll()
        if !waiters.isEmpty {
            AudioDebug.log("🔓 resuming \(waiters.count) gated join(s)", reason)
        }
        waiters.forEach { $0.resume() }
    }

    func start() {
        print("[VoIPPushManager] start() — registering with PushKit")
        registry.delegate         = self
        registry.desiredPushTypes = []
        registry.desiredPushTypes = [.voIP]
    }

    /// Re-sets desiredPushTypes so PushKit immediately re-fires
    /// didUpdate pushCredentials with the authoritative current token.
    /// Safe to call multiple times — idempotent.
    /// Note: PushKit rate-limits this after rapid calls, so use
    /// persistTokenDirectly() as the primary recovery path when a
    /// known token is already available.
    func syncTokenForCurrentUser() {
        guard Auth.auth().currentUser != nil else {
            print("[VoIPPushManager] syncTokenForCurrentUser() — no signed-in user, skipping")
            return
        }
        print("[VoIPPushManager] syncTokenForCurrentUser() — triggering PushKit re-delivery")
        registry.desiredPushTypes = [.voIP]
    }

    /// Writes a known token directly to Firestore without waiting for PushKit
    /// re-delivery. Called by VoIPTokenWatcher when it already has a valid
    /// token (from currentTokenString or UserDefaults) and doesn't want to
    /// rely on PushKit firing — e.g. after a rapid user switch where PushKit
    /// rate-limits didUpdate pushCredentials.
    func persistTokenDirectly(_ token: String, uid: String) {
        print("[VoIPPushManager] 📝 persistTokenDirectly() called for user \(uid)")

        // Keep currentTokenString current so subsequent watcher snapshots
        // can correctly evaluate staleness.
        currentTokenString = token

        guard let user = Auth.auth().currentUser, user.uid == uid else {
            print("[VoIPPushManager] ⚠️ persistTokenDirectly() — uid mismatch or no current user, aborting")
            return
        }

        user.getIDTokenForcingRefresh(true) { _, error in
            if let error {
                print("[VoIPPushManager] ❌ JWT refresh failed in persistTokenDirectly: \(error.localizedDescription)")
                UserDefaults.standard.set(token, forKey: "pendingVoIPToken")
                return
            }
            print("[VoIPPushManager] ✅ JWT refreshed in persistTokenDirectly — writing token")
            self.persistToken(token, uid: uid)
        }
    }

    func endActiveCall(for streamId: String) {
        guard let (uuid, _) = activeCalls.first(where: { $0.value.streamId == streamId }) else { return }
        provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
        activeCalls.removeValue(forKey: uuid)
        print("[VoIPPushManager] Ended CallKit call for stream \(streamId)")
    }

    func endAllActiveCalls() {
        for (uuid, _) in activeCalls {
            provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
        }
        activeCalls.removeAll()
        print("[VoIPPushManager] Ended all active CallKit calls")
    }

    // MARK: - Token handling

    private func saveToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        print("[VoIPPushManager] 📬 PushKit delivered token: \(token.prefix(16))…")

        // Always keep currentTokenString up to date so VoIPTokenWatcher
        // can detect staleness even before the Firestore write completes.
        currentTokenString = token

        guard let user = Auth.auth().currentUser else {
            print("[VoIPPushManager] ⚠️ No signed-in user — stashing token in UserDefaults")
            UserDefaults.standard.set(token, forKey: "pendingVoIPToken")
            return
        }

        print("[VoIPPushManager] 🔐 Force-refreshing JWT for user \(user.uid)")
        user.getIDTokenForcingRefresh(true) { _, error in
            if let error {
                print("[VoIPPushManager] ❌ JWT refresh failed: \(error.localizedDescription) — stashing token")
                UserDefaults.standard.set(token, forKey: "pendingVoIPToken")
                return
            }
            print("[VoIPPushManager] ✅ JWT refreshed — proceeding to persist token")
            self.persistToken(token, uid: user.uid)
        }
    }

    /// Writes the token to Firestore with exponential-backoff retry (up to 3
    /// attempts: 2 s, 4 s, 6 s). On final failure the token is stashed in
    /// UserDefaults so VoIPTokenWatcher can detect the mismatch on the next
    /// snapshot or foreground resume and trigger a fresh recovery cycle.
    func persistToken(_ token: String, uid: String, retryCount: Int = 0) {
        print("[VoIPPushManager] 💾 Attempting Firestore write (attempt \(retryCount + 1)) for user \(uid)")
        Firestore.firestore()
            .collection("users")
            .document(uid)
            .updateData(["voipToken": token]) { err in
                if let err {
                    print("[VoIPPushManager] ❌ Firestore write failed (attempt \(retryCount + 1)): \(err.localizedDescription)")

                    guard retryCount < 3 else {
                        print("[VoIPPushManager] ⚠️ All retries exhausted — stashing token for watcher to heal")
                        UserDefaults.standard.set(token, forKey: "pendingVoIPToken")
                        return
                    }

                    let delay = Double(retryCount + 1) * 2.0
                    print("[VoIPPushManager] ⏱ Retrying in \(Int(delay))s…")
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.persistToken(token, uid: uid, retryCount: retryCount + 1)
                    }
                } else {
                    print("[VoIPPushManager] ✅ voipToken written to Firestore for \(uid)")
                    UserDefaults.standard.removeObject(forKey: "pendingVoIPToken")
                }
            }
    }

    /// Removes the voipToken field from Firestore and clears the UserDefaults
    /// stash. Call on sign-out so a logged-out device is never rung.
    func clearToken() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[VoIPPushManager] clearToken() — no current user, nothing to clear")
            return
        }
        print("[VoIPPushManager] 🗑 Clearing voipToken for user \(uid)")
        Firestore.firestore()
            .collection("users")
            .document(uid)
            .updateData(["voipToken": FieldValue.delete()])
        UserDefaults.standard.removeObject(forKey: "pendingVoIPToken")
        currentTokenString = nil
    }

    // MARK: - Report incoming call to CallKit

    private func reportIncomingCall(payload: PKPushPayload) {
        let dict         = payload.dictionaryPayload
        let streamId     = dict["stream_id"]     as? String ?? ""
        let streamerName = dict["streamer_name"] as? String ?? "Someone"
        let streamerId   = dict["streamer_id"]   as? String ?? ""

        print("[VoIPPushManager] 📞 Incoming call — stream: \(streamId), streamer: \(streamerName)")

        let callUUID = UUID()
        let info     = VoIPCallInfo(
            callUUID:     callUUID,
            streamId:     streamId,
            streamerName: streamerName,
            streamerId:   streamerId
        )
        activeCalls[callUUID] = info

        let update = CXCallUpdate()
        update.remoteHandle        = CXHandle(type: .generic, value: streamerName)
        update.hasVideo            = true
        update.localizedCallerName = "\(streamerName) is live"
        update.supportsGrouping    = false
        update.supportsUngrouping  = false
        update.supportsHolding     = false
        update.supportsDTMF        = false

        provider.reportNewIncomingCall(with: callUUID, update: update) { [weak self] error in
            if let error {
                print("[VoIPPushManager] ❌ reportNewIncomingCall error: \(error.localizedDescription)")
                self?.activeCalls.removeValue(forKey: callUUID)
            } else {
                print("[VoIPPushManager] ✅ Reported incoming call to CallKit — UUID: \(callUUID)")
            }
        }
    }
}

// MARK: - PKPushRegistryDelegate
extension VoIPPushManager: PKPushRegistryDelegate {

    func pushRegistry(_ registry: PKPushRegistry,
                      didUpdate pushCredentials: PKPushCredentials,
                      for type: PKPushType) {
        guard type == .voIP else { return }
        print("[VoIPPushManager] 🔔 PKPushRegistry didUpdate pushCredentials")
        saveToken(pushCredentials.token)
    }

    func pushRegistry(_ registry: PKPushRegistry,
                      didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP else { return }
        print("[VoIPPushManager] ⚠️ PKPushRegistry didInvalidatePushToken — clearing")
        clearToken()
    }

    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType,
                      completion: @escaping () -> Void) {
        guard type == .voIP else { completion(); return }

        let streamId = payload.dictionaryPayload["stream_id"] as? String ?? ""
        print("[VoIPPushManager] 📨 Received VoIP push — stream_id: '\(streamId)'")

        if streamId.isEmpty {
            print("[VoIPPushManager] ⚠️ Empty stream_id — reporting and immediately ending dummy call")
            let dummyUUID = UUID()
            let update    = CXCallUpdate()
            update.remoteHandle = CXHandle(type: .generic, value: "Unknown")
            provider.reportNewIncomingCall(with: dummyUUID, update: update) { _ in
                self.provider.reportCall(with: dummyUUID, endedAt: Date(), reason: .failed)
                completion()
            }
            return
        }

        reportIncomingCall(payload: payload)
        completion()
    }
}

// MARK: - CXProviderDelegate
extension VoIPPushManager: CXProviderDelegate {

    func providerDidReset(_ provider: CXProvider) {
        print("[VoIPPushManager] providerDidReset — clearing active calls")
        activeCalls.removeAll()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        guard let info = activeCalls[action.callUUID] else {
            print("[VoIPPushManager] ❌ CXAnswerCallAction — no matching call for UUID \(action.callUUID)")
            action.fail()
            return
        }
        print("[VoIPPushManager] ✅ Call answered — stream: \(info.streamId)")
        action.fulfill()

        // Remove from activeCalls FIRST so no other path (endActiveCall,
        // endAllActiveCalls, CXEndCallAction) can treat this accepted
        // call as a decline later.
        activeCalls.removeValue(forKey: action.callUUID)

        // The CallKit call must be ended so it releases the AVAudioSession
        // back to the app — CallKit is only the ringer, the actual media is
        // LiveKit. But WHEN it's ended matters:
        //
        //   • App already active  → end immediately. iOS has nothing left
        //     to do; keeping the call alive would hold the session in
        //     phone-call mode and mute stream audio.
        //
        //   • App killed/background → iOS launches and foregrounds the app
        //     *because* there is an active call. Ending it in the same
        //     instant cancels that foregrounding, leaving the app stuck in
        //     the background. So the call is kept alive until
        //     didBecomeActive fires, then ended (with a 5 s timeout
        //     fallback in case activation never happens).
        //
        // reportCall is a *report*, not an action, so ending this way does
        // NOT trigger the CXEndCallAction (decline) handler.
        //
        // In BOTH branches, awaitingSessionRelease gates LiveKit: the stream
        // view's join() parks in waitUntilCallKitAudioReleased() until the
        // session is actually free, so the audio engine never starts inside
        // CallKit's session (which fails with an AURemoteIO error and is
        // never retried → silent stream on lock-screen answers).
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.awaitingSessionRelease = true
            self.onAcceptCall?(info)

            if UIApplication.shared.applicationState == .active {
                print("[VoIPPushManager] 🔚 App active — ending answered call immediately to release audio session")
                self.endAnsweredCall(uuid: action.callUUID, trigger: "immediate (app active)")
            } else {
                print("[VoIPPushManager] ⏳ App not active — deferring call end until foreground")
                self.pendingAnsweredCallUUID = action.callUUID
                self.scheduleEndOnForeground()
            }
        }
    }

    /// Reports the answered call as ended and arms a 1 s fallback that
    /// releases any gated joins in case CallKit never delivers
    /// didDeactivate (the authoritative release signal).
    private func endAnsweredCall(uuid: UUID, trigger: String) {
        print("[VoIPPushManager] 🔚 Ending answered call (\(trigger)) — releasing audio session to app")
        AudioDebug.dump("ending answered call (\(trigger))")
        provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.resumeAudioWaiters(reason: "1s fallback after call end")
        }
    }

    /// Ends the pending answered call once the app becomes active, so a
    /// cold-launch keeps its foregrounding trigger (the active call) until
    /// iOS has finished bringing the app up. A 5 s fallback guarantees the
    /// audio session is always eventually released even if activation
    /// never fires.
    private func scheduleEndOnForeground() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object:  nil,
            queue:   .main
        ) { [weak self] _ in
            self?.endPendingAnsweredCall(trigger: "didBecomeActive")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.endPendingAnsweredCall(trigger: "timeout fallback")
        }
    }

    private func endPendingAnsweredCall(trigger: String) {
        guard let uuid = pendingAnsweredCallUUID else { return }
        pendingAnsweredCallUUID = nil

        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
            foregroundObserver = nil
        }

        endAnsweredCall(uuid: uuid, trigger: trigger)
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        if let info = activeCalls[action.callUUID] {
            print("[VoIPPushManager] 📵 Call ended — stream: \(info.streamId)")
            DispatchQueue.main.async { [weak self] in
                self?.onDeclineCall?(info)
            }
            activeCalls.removeValue(forKey: action.callUUID)
        }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("[VoIPPushManager] 🔊 CallKit activated audio session")
        AudioDebug.dump("CallKit didActivate")
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("[VoIPPushManager] 🔇 CallKit deactivated audio session — restoring app audio config")
        AudioDebug.dump("CallKit didDeactivate (before restore)")
        // Belt-and-braces: after CallKit releases the session, restore the
        // category/mode LiveKit expects for stream playback. LiveKit's
        // AudioManager usually reconfigures this itself, but doing it here
        // guarantees the session is never left in phone-call mode.
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord,
                mode: .videoChat,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[VoIPPushManager] ❌ session restore failed: \(error)")
        }
        AudioDebug.dump("CallKit didDeactivate (after restore)")

        // Authoritative release point: the session is now free, so any
        // LiveKit join parked in waitUntilCallKitAudioReleased() can proceed.
        DispatchQueue.main.async { [weak self] in
            self?.resumeAudioWaiters(reason: "CallKit didDeactivate")
        }
    }
}
