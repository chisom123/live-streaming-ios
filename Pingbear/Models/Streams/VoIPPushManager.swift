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
final class VoIPPushManager: NSObject {

    static let shared = VoIPPushManager()

    var onAcceptCall:  ((VoIPCallInfo) -> Void)?
    var onDeclineCall: ((VoIPCallInfo) -> Void)?

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
    }

    // MARK: - Public API

    func start() {
        registry.delegate         = self
        registry.desiredPushTypes = []
        registry.desiredPushTypes = [.voIP]
    }

    /// Call after auth is confirmed — works for both new and returning users.
    /// Re-setting desiredPushTypes causes didUpdate pushCredentials to fire
    /// immediately with the current token, which then writes it to Firestore.
    /// No UserDefaults dependency, no race conditions.
    func syncTokenForCurrentUser() {
        guard Auth.auth().currentUser != nil else { return }
        registry.desiredPushTypes = [.voIP]
    }

    func endActiveCall(for streamId: String) {
        guard let (uuid, _) = activeCalls.first(where: { $0.value.streamId == streamId }) else { return }
        provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
        activeCalls.removeValue(forKey: uuid)
        print("[VoIP] Ended CallKit call for stream \(streamId)")
    }

    func endAllActiveCalls() {
        for (uuid, _) in activeCalls {
            provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
        }
        activeCalls.removeAll()
        print("[VoIP] Ended all active CallKit calls")
    }

    // MARK: - Token handling

    private func saveToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()

        guard let user = Auth.auth().currentUser else {
            // No user yet — stash it, syncTokenForCurrentUser will flush it after auth
            UserDefaults.standard.set(token, forKey: "pendingVoIPToken")
            print("[VoIP] No user yet — token stashed for later")
            return
        }

        // User exists — force refresh JWT so Firestore accepts the write immediately
        user.getIDTokenForcingRefresh(true) { _, error in
            if let error {
                print("[VoIP] JWT refresh failed: \(error) — stashing token")
                UserDefaults.standard.set(token, forKey: "pendingVoIPToken")
                return
            }
            self.persistToken(token, uid: user.uid)
        }
    }

    private func persistToken(_ token: String, uid: String) {
        Firestore.firestore()
            .collection("users")
            .document(uid)
            .updateData(["voipToken": token]) { err in
                if let err {
                    print("[VoIP] ❌ Failed to save token: \(err)")
                } else {
                    print("[VoIP] ✅ Token saved for \(uid)")
                    UserDefaults.standard.removeObject(forKey: "pendingVoIPToken")
                }
            }
    }

    /// Call on sign-out so stale tokens don't ring a logged-out device.
    func clearToken() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore()
            .collection("users")
            .document(uid)
            .updateData(["voipToken": FieldValue.delete()])
        UserDefaults.standard.removeObject(forKey: "pendingVoIPToken")
    }

    // MARK: - Report incoming call to CallKit

    private func reportIncomingCall(payload: PKPushPayload) {
        let dict         = payload.dictionaryPayload
        let streamId     = dict["stream_id"]     as? String ?? ""
        let streamerName = dict["streamer_name"] as? String ?? "Someone"
        let streamerId   = dict["streamer_id"]   as? String ?? ""

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
                print("[VoIP] reportNewIncomingCall error: \(error)")
                self?.activeCalls.removeValue(forKey: callUUID)
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
        saveToken(pushCredentials.token)
    }

    func pushRegistry(_ registry: PKPushRegistry,
                      didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP else { return }
        clearToken()
    }

    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType,
                      completion: @escaping () -> Void) {
        guard type == .voIP else { completion(); return }

        let streamId = payload.dictionaryPayload["stream_id"] as? String ?? ""

        if streamId.isEmpty {
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
        activeCalls.removeAll()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        guard let info = activeCalls[action.callUUID] else {
            action.fail()
            return
        }
        action.fulfill()
        DispatchQueue.main.async { [weak self] in
            self?.onAcceptCall?(info)
        }
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        if let info = activeCalls[action.callUUID] {
            DispatchQueue.main.async { [weak self] in
                self?.onDeclineCall?(info)
            }
            activeCalls.removeValue(forKey: action.callUUID)
        }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("[VoIP] Audio session activated")
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("[VoIP] Audio session deactivated")
    }
}
