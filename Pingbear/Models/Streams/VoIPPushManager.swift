import Foundation
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
        DispatchQueue.main.async { [weak self] in
            self?.onAcceptCall?(info)
        }
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
        print("[VoIPPushManager] 🔊 Audio session activated")
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("[VoIPPushManager] 🔇 Audio session deactivated")
    }
}
