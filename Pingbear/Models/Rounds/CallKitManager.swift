import Foundation
import CallKit
import PushKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import AVFoundation

// ─────────────────────────────────────────────────────────────
// MARK: - CallKitManager
//
// SELF-NOTIFICATION FIX SUMMARY
// ─────────────────────────────────────────────────────────────
//
// The original bug: when a user joins a call, CallKit rings on
// their own device. This happened because of three separate
// failure modes, all now fixed:
//
// 1. SERVER-SIDE (callKitFunctions.js)
//    The caller's uid is now always excluded from the recipient
//    list in getVoipTokensForMembers, so the push is never
//    delivered to their device at all. This is the primary guard.
//    A 5s per-caller cooldown also suppresses duplicate invites
//    from rapid LiveKit drop+rejoin.
//
// 2. CLIENT-SIDE AUTH RACE
//    Auth.auth().currentUser can be nil when a VoIP push arrives
//    cold (app launched by push). isOwnJoin now falls back to a
//    uid cached in UserDefaults on login, so it works even if
//    Firebase Auth hasn't restored the session yet.
//    Cache the uid on login:
//      UserDefaults.standard.set(userId, forKey: "cachedUserId")
//
// 3. ALREADY-IN-CALL GUARD TOO NARROW
//    The original guard only caught .connected. It now catches
//    any non-idle state (.connecting, .answering, .disconnecting)
//    so a push arriving during connection setup is also suppressed.
//
// ─────────────────────────────────────────────────────────────

class CallKitManager: NSObject, ObservableObject {
    static let shared = CallKitManager()

    @Published var incomingCallData: IncomingCallData? = nil

    private let provider:       CXProvider
    private let callController: CXCallController
    private let pushRegistry:   PKPushRegistry
    private lazy var db        = Firestore.firestore()
    private lazy var functions = Functions.functions()

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

    // ─────────────────────────────────────────────────────────
    // MARK: - Configure
    // ─────────────────────────────────────────────────────────

    func configure() {
        if let user = Auth.auth().currentUser, let token = pendingVoipToken {
            persistVoipToken(token, userId: user.uid)
            pendingVoipToken = nil
        }

        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            if let user {
                // Cache uid for cold-launch VoIP push auth race fix
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

    // ─────────────────────────────────────────────────────────
    // MARK: - Current User ID
    //
    // Falls back to UserDefaults when Firebase Auth hasn't
    // restored the session yet (cold VoIP push launch).
    // This is what makes isOwnJoin reliable at push receipt time.
    // ─────────────────────────────────────────────────────────

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
            ?? UserDefaults.standard.string(forKey: "cachedUserId")
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Report Incoming Call
    // ─────────────────────────────────────────────────────────

    func reportIncomingCall(data: IncomingCallData) {
        let callUUID       = UUID()
        activeCallUUID     = callUUID
        callEndedByCallKit = false

        let update = CXCallUpdate()
        update.remoteHandle        = CXHandle(type: .generic, value: data.competitionName)
        update.localizedCallerName = "\(data.callerName) • \(data.competitionName)"
        update.hasVideo            = false
        update.supportsHolding     = false
        update.supportsGrouping    = false
        update.supportsUngrouping  = false
        update.supportsDTMF        = false

        provider.reportNewIncomingCall(with: callUUID, update: update) { [weak self] error in
            if let error {
                print("CallKitManager: reportNewIncomingCall error: \(error.localizedDescription)")
                self?.activeCallUUID = nil
            } else {
                print("CallKitManager: Incoming call reported for \(data.competitionName)")
                DispatchQueue.main.async {
                    self?.incomingCallData = data
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Report And Immediately End
    //
    // Apple requires every VoIP push to result in a CallKit call.
    // Uses its own UUID — never touches activeCallUUID.
    // ─────────────────────────────────────────────────────────

    private func reportAndImmediatelyEnd(competitionName: String) {
        let uuid   = UUID()
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: competitionName)

        provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] _ in
            guard let self else { return }
            self.provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
            let transaction = CXTransaction(action: CXEndCallAction(call: uuid))
            self.callController.request(transaction) { _ in }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - End Active Call
    // ─────────────────────────────────────────────────────────

    func endActiveCall(reason: CXCallEndedReason = .remoteEnded) {
        guard let uuid = activeCallUUID else { return }
        activeCallUUID = nil

        if callEndedByCallKit {
            callEndedByCallKit = false
            return
        }

        provider.reportCall(with: uuid, endedAt: Date(), reason: reason)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Send Call Invite
    // ─────────────────────────────────────────────────────────

    func sendCallInvite(competitionId: String, competitionName: String) {
        functions.httpsCallable("sendCallInvite").call([
            "competitionId":   competitionId,
            "competitionName": competitionName,
            "roomName":        competitionId
        ]) { _, error in
            if let error {
                print("CallKitManager: sendCallInvite failed: \(error.localizedDescription)")
            } else {
                print("CallKitManager: Call invite sent for \(competitionId)")
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Save VoIP Token
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
        db.collection("users").document(userId).setData([
            "voipPushToken": tokenString
        ], merge: true) { error in
            if let error {
                print("CallKitManager: Failed to save VoIP token: \(error.localizedDescription)")
            } else {
                print("CallKitManager: VoIP token saved for \(userId)")
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - CXProviderDelegate
// ─────────────────────────────────────────────────────────────

extension CallKitManager: CXProviderDelegate {

    func providerDidReset(_ provider: CXProvider) {
        VoiceCallManager.shared.leaveCall()
        activeCallUUID     = nil
        callEndedByCallKit = false
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("CallKitManager: Answer action received")

        guard let callData = incomingCallData else {
            print("CallKitManager: No incomingCallData — failing action")
            action.fail()
            return
        }

        // 1. Configure audio session synchronously before fulfill()
        try? AVAudioSession.sharedInstance().setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.allowBluetoothHFP, .mixWithOthers]
        )

        // 2. Fulfill immediately — CallKit has a hard ~5s deadline
        action.fulfill()
        print("CallKitManager: Action fulfilled")

        // 3. Connect to LiveKit asynchronously
        VoiceCallManager.shared.answerCall(
            competitionId:   callData.competitionId,
            competitionName: callData.competitionName
        )

        DispatchQueue.main.async {
            self.incomingCallData = nil
        }
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        callEndedByCallKit = true
        VoiceCallManager.shared.leaveCall()
        activeCallUUID = nil
        DispatchQueue.main.async { self.incomingCallData = nil }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("CallKitManager: Audio session activated")
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("CallKitManager: Audio session deactivated")
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - PKPushRegistryDelegate
// ─────────────────────────────────────────────────────────────

extension CallKitManager: PKPushRegistryDelegate {

    func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate pushCredentials: PKPushCredentials,
        for type: PKPushType
    ) {
        guard type == .voIP else { return }
        saveVoipToken(pushCredentials.token)
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        guard type == .voIP else {
            completion()
            return
        }

        let dict   = payload.dictionaryPayload
        let action = dict["action"] as? String ?? ""

        print("CallKitManager: VoIP push received — action: \(action)")

        if action == "call_ended" {
            endActiveCall(reason: .remoteEnded)
            completion()
            return
        }

        guard
            let competitionId   = dict["competitionId"]   as? String,
            let competitionName = dict["competitionName"]  as? String,
            let callerName      = dict["callerName"]       as? String,
            let callerId        = dict["callerId"]         as? String,
            let roomName        = dict["roomName"]         as? String
        else {
            reportAndImmediatelyEnd(competitionName: "SocialStar")
            completion()
            return
        }

        // ── Self-notification guard ───────────────────────────
        // Uses cached uid so this works even when Firebase Auth
        // hasn't restored the session yet (cold VoIP push launch).
        let isOwnJoin = callerId == currentUserId

        // ── Already-in-call guard ─────────────────────────────
        // Widened from .connected to any non-idle state so a push
        // arriving during .connecting/.answering is also suppressed.
        let callState     = VoiceCallManager.shared.callState
        let alreadyInCall = VoiceCallManager.shared.currentCompetitionId == competitionId
                          && callState != .idle

        if isOwnJoin || alreadyInCall {
            print("CallKitManager: Suppressing push — isOwnJoin:\(isOwnJoin) alreadyInCall:\(alreadyInCall)")
            reportAndImmediatelyEnd(competitionName: competitionName)
            completion()
            return
        }

        reportIncomingCall(data: IncomingCallData(
            competitionId:   competitionId,
            competitionName: competitionName,
            callerName:      callerName,
            callerId:        callerId,
            roomName:        roomName
        ))
        completion()
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didInvalidatePushTokenFor type: PKPushType
    ) {
        print("CallKitManager: VoIP push token invalidated")
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - IncomingCallData
// ─────────────────────────────────────────────────────────────

struct IncomingCallData {
    let competitionId:   String
    let competitionName: String
    let callerName:      String
    let callerId:        String
    let roomName:        String
}
