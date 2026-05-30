import Foundation
import CallKit
import PushKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import AVFoundation
import LiveKit

struct IncomingCallData {
    let sessionId:  String
    let callerName: String
    let callerId:   String
}

class CallKitManager: NSObject, ObservableObject {
    static let shared = CallKitManager()

    @Published var incomingCallData: IncomingCallData? = nil

    private let provider:       CXProvider
    private let callController: CXCallController
    private let pushRegistry:   PKPushRegistry

    private var activeCallUUID:     UUID? = nil
    private var pendingVoipToken:   Data? = nil
    private var callEndedByCallKit: Bool  = false

    private override init() {
        let config = CXProviderConfiguration(localizedName: "SocialStar")
        config.supportsVideo            = false
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes     = [.generic]
        config.iconTemplateImageData    = UIImage(named: "AppIcon")?.pngData()

        self.provider       = CXProvider(configuration: config)
        self.callController = CXCallController()
        self.pushRegistry   = PKPushRegistry(queue: .main)

        super.init()

        provider.setDelegate(self, queue: nil)
        pushRegistry.delegate         = self
        pushRegistry.desiredPushTypes = [.voIP]
    }

    func configure() {
        if let user = Auth.auth().currentUser, let token = pendingVoipToken {
            persistVoipToken(token, userId: user.uid)
            pendingVoipToken = nil
        }

        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            if let user {
                UserDefaults.standard.set(user.uid, forKey: "cachedUserId")
                if let token = self.pendingVoipToken {
                    self.persistVoipToken(token, userId: user.uid)
                    self.pendingVoipToken = nil
                }
            } else {
                UserDefaults.standard.removeObject(forKey: "cachedUserId")
            }
        }
    }

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
            ?? UserDefaults.standard.string(forKey: "cachedUserId")
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Outgoing Call
    // ─────────────────────────────────────────────────────────

    func reportOutgoingCall(sessionId: String, displayName: String) {
        if let existingUUID = activeCallUUID {
            AppLogger.call("reportOutgoingCall — ending existing UUID=\(existingUUID) before new call")
            provider.reportCall(with: existingUUID, endedAt: Date(), reason: .remoteEnded)
            activeCallUUID = nil
        }

        let callUUID   = UUID()
        activeCallUUID = callUUID
        AppLogger.call("reportOutgoingCall — UUID=\(callUUID) display=\(displayName)")

        let handle = CXHandle(type: .generic, value: displayName)
        let action = CXStartCallAction(call: callUUID, handle: handle)
        action.isVideo = false

        let transaction = CXTransaction(action: action)
        callController.request(transaction) { error in
            if let error {
                AppLogger.call("reportOutgoingCall — CXStartCallAction FAILED: \(error.localizedDescription)")
            } else {
                AppLogger.call("reportOutgoingCall — CXStartCallAction accepted")
                self.provider.reportOutgoingCall(with: callUUID, connectedAt: nil)
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Incoming Call
    // ─────────────────────────────────────────────────────────

    func reportIncomingCall(data: IncomingCallData) {
        let callUUID       = UUID()
        activeCallUUID     = callUUID
        callEndedByCallKit = false

        AppLogger.ring("reportIncomingCall — UUID=\(callUUID) caller=\(data.callerName) sessionId=\(data.sessionId)")

        let update = CXCallUpdate()
        update.remoteHandle        = CXHandle(type: .generic, value: data.callerName)
        update.localizedCallerName = data.callerName
        update.hasVideo            = false
        update.supportsHolding     = false
        update.supportsGrouping    = false
        update.supportsUngrouping  = false
        update.supportsDTMF        = false

        provider.reportNewIncomingCall(with: callUUID, update: update) { [weak self] error in
            if let error {
                AppLogger.ring("reportIncomingCall — FAILED: \(error.localizedDescription)")
                self?.activeCallUUID = nil
            } else {
                AppLogger.ring("reportIncomingCall — ringer shown ✅")
                DispatchQueue.main.async { self?.incomingCallData = data }
            }
        }
    }

    private func reportAndImmediatelyEnd(callerName: String) {
        AppLogger.ring("reportAndImmediatelyEnd — \(callerName)")
        let uuid   = UUID()
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callerName)

        provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] _ in
            guard let self else { return }
            self.provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
            let transaction = CXTransaction(action: CXEndCallAction(call: uuid))
            self.callController.request(transaction) { _ in }
        }
    }

    func endActiveCall(reason: CXCallEndedReason = .remoteEnded) {
        guard let uuid = activeCallUUID else {
            AppLogger.call("endActiveCall — no active UUID to end")
            return
        }
        AppLogger.call("endActiveCall — UUID=\(uuid) reason=\(reason.rawValue)")
        activeCallUUID = nil

        if callEndedByCallKit {
            callEndedByCallKit = false
            return
        }

        provider.reportCall(with: uuid, endedAt: Date(), reason: reason)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Audio Engine
    // ─────────────────────────────────────────────────────────

    func activateAudioEngineIfNeeded() {
        AppLogger.audio("activateAudioEngineIfNeeded — enabling engine")
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetoothHFP, .mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            try AudioManager.shared.setEngineAvailability(.default)
            AppLogger.audio("activateAudioEngineIfNeeded — engine active ✅")
        } catch {
            AppLogger.audio("activateAudioEngineIfNeeded — FAILED: \(error.localizedDescription)")
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - VoIP Token
    // ─────────────────────────────────────────────────────────

    func saveVoipToken(_ token: Data) {
        if let userId = Auth.auth().currentUser?.uid {
            persistVoipToken(token, userId: userId)
        } else {
            pendingVoipToken = token
        }
    }

    private func persistVoipToken(_ token: Data, userId: String) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        AppLogger.ring("persistVoipToken — userId=\(userId) token=\(tokenString.prefix(16))...")
        Firestore.firestore().collection("users").document(userId).setData([
            "voipPushToken": tokenString
        ], merge: true) { error in
            if let error {
                AppLogger.ring("persistVoipToken — FAILED: \(error.localizedDescription)")
            } else {
                AppLogger.ring("persistVoipToken — saved ✅")
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - CXProviderDelegate
// ─────────────────────────────────────────────────────────────

extension CallKitManager: CXProviderDelegate {

    func providerDidReset(_ provider: CXProvider) {
        AppLogger.call("providerDidReset")
        VoiceCallManager.shared.leaveCall()
        activeCallUUID     = nil
        callEndedByCallKit = false
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        AppLogger.call("CXStartCallAction — call starting")
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        AppLogger.ring("CXAnswerCallAction — UUID=\(action.callUUID)")

        guard let callData = incomingCallData else {
            AppLogger.ring("CXAnswerCallAction — FAILED: no incomingCallData")
            action.fail()
            return
        }

        action.fulfill()
        AppLogger.ring("CXAnswerCallAction — fulfilled, joining session=\(callData.sessionId)")

        let sessionId = callData.sessionId
        DispatchQueue.main.async { self.incomingCallData = nil }

        Functions.functions().httpsCallable("joinSession").call([
            "sessionId": sessionId
        ]) { _, error in
            if let error {
                AppLogger.ring("joinSession — FAILED: \(error.localizedDescription)")
            } else {
                AppLogger.session("joinSession — success ✅")
            }
            VoiceCallManager.shared.answerCall(sessionId: sessionId)
        }
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        AppLogger.call("CXEndCallAction — UUID=\(action.callUUID) activeUUID=\(activeCallUUID?.uuidString ?? "nil")")

        guard action.callUUID == activeCallUUID else {
            AppLogger.call("CXEndCallAction — UUID mismatch, ignoring stale action")
            action.fulfill()
            return
        }

        callEndedByCallKit = true
        VoiceCallManager.shared.leaveCall()
        activeCallUUID = nil
        DispatchQueue.main.async { self.incomingCallData = nil }
        action.fulfill()
        AppLogger.call("CXEndCallAction — fulfilled")
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        AppLogger.audio("didActivate — enabling LiveKit audio engine ✅")
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothHFP, .mixWithOthers])
            try AudioManager.shared.setEngineAvailability(.default)
            AppLogger.audio("didActivate — engine set to .default")
        } catch {
            AppLogger.audio("didActivate — FAILED: \(error.localizedDescription)")
        }
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        AppLogger.audio("didDeactivate — disabling LiveKit audio engine")
        do {
            try AudioManager.shared.setEngineAvailability(.none)
            AppLogger.audio("didDeactivate — engine set to .none")
        } catch {
            AppLogger.audio("didDeactivate — FAILED: \(error.localizedDescription)")
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - PKPushRegistryDelegate
// ─────────────────────────────────────────────────────────────

extension CallKitManager: PKPushRegistryDelegate {

    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else { return }
        AppLogger.ring("VoIP token updated")
        saveVoipToken(pushCredentials.token)
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        guard type == .voIP else { completion(); return }

        let dict   = payload.dictionaryPayload
        let action = dict["action"] as? String ?? ""
        AppLogger.ring("VoIP push received — action=\(action)")

        if action == "call_ended" {
            AppLogger.ring("call_ended push — ending active call")
            endActiveCall(reason: .remoteEnded)
            completion()
            return
        }

        guard
            let sessionId  = dict["sessionId"]  as? String,
            let callerName = dict["callerName"] as? String,
            let callerId   = dict["callerId"]   as? String
        else {
            AppLogger.ring("VoIP push — missing required fields, ending immediately")
            reportAndImmediatelyEnd(callerName: "SocialStar")
            completion()
            return
        }

        AppLogger.ring("VoIP push — sessionId=\(sessionId) caller=\(callerName) callerId=\(callerId)")

        let isOwnCall    = callerId == currentUserId
        let callState    = VoiceCallManager.shared.callState
        let alreadyInCall = VoiceCallManager.shared.currentSessionId == sessionId && callState != .idle

        if isOwnCall {
            AppLogger.ring("VoIP push — suppressed (own call)")
            reportAndImmediatelyEnd(callerName: callerName)
            completion()
            return
        }

        if alreadyInCall {
            AppLogger.ring("VoIP push — suppressed (already in session=\(sessionId))")
            reportAndImmediatelyEnd(callerName: callerName)
            completion()
            return
        }

        // Deduplicate — if already showing this session's incoming call
        if let existingData = incomingCallData, existingData.sessionId == sessionId {
            AppLogger.ring("VoIP push — suppressed (duplicate for session=\(sessionId))")
            reportAndImmediatelyEnd(callerName: callerName)
            completion()
            return
        }

        AppLogger.ring("VoIP push — reporting incoming call for session=\(sessionId)")
        reportIncomingCall(data: IncomingCallData(
            sessionId:  sessionId,
            callerName: callerName,
            callerId:   callerId
        ))
        completion()
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        AppLogger.ring("VoIP push token invalidated")
    }
}
