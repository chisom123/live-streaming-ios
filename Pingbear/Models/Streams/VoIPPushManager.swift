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
        registry.desiredPushTypes = [.voIP]
    }

    /// Call this after the user document has been created (new user signup).
    /// Re-triggers PushKit registration so didUpdate pushCredentials fires
    /// with the user now logged in, guaranteeing the token saves to Firestore.
    /// Also flushes any already-stashed token as a belt-and-braces fallback.
    func registerAndSaveToken() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // Flush any token that arrived before the document existed
        if let token = UserDefaults.standard.string(forKey: "pendingVoIPToken") {
            persistToken(token, uid: uid)
        }

        // Re-trigger PushKit — didUpdate pushCredentials fires immediately
        // and since the user is now logged in, saveToken → persistToken directly
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
        UserDefaults.standard.set(token, forKey: "pendingVoIPToken")

        guard let uid = Auth.auth().currentUser?.uid else {
            print("[VoIP] No user yet — token stashed for later")
            return
        }
        persistToken(token, uid: uid)
    }

    private func persistToken(_ token: String, uid: String) {
        Firestore.firestore()
            .collection("users")
            .document(uid)
            .updateData(["voipToken": token]) { err in
                if let err {
                    print("[VoIP] Failed to save token: \(err)")
                } else {
                    print("[VoIP] Token saved for \(uid)")
                    UserDefaults.standard.removeObject(forKey: "pendingVoIPToken")
                }
            }
    }

    /// Call this after login completes (returning users) to flush any
    /// token that arrived before auth.
    func savePendingTokenIfNeeded() {
        guard let uid   = Auth.auth().currentUser?.uid,
              let token = UserDefaults.standard.string(forKey: "pendingVoIPToken")
        else { return }
        persistToken(token, uid: uid)
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
