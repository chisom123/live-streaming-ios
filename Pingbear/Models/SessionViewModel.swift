import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

// ─────────────────────────────────────────────────────────────
// MARK: - Round Phase
// ─────────────────────────────────────────────────────────────

enum RoundPhase: Equatable {
    case idle
    case lobby(Round)
    case joining(Round)
    case joined(Round)
    case judging(Round)
    case results(Round, [Submission], [String: UserProfile])

    static func == (lhs: RoundPhase, rhs: RoundPhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):                               return true
        case (.lobby(let a),   .lobby(let b)):             return a.id == b.id
        case (.joining(let a), .joining(let b)):           return a.id == b.id
        case (.joined(let a),  .joined(let b)):            return a.id == b.id
        case (.judging(let a), .judging(let b)):           return a.id == b.id
        case (.results(let a,_,_), .results(let b,_,_)):  return a.id == b.id
        default:                                           return false
        }
    }

    var round: Round? {
        switch self {
        case .idle:                  return nil
        case .lobby(let r):          return r
        case .joining(let r):        return r
        case .joined(let r):         return r
        case .judging(let r):        return r
        case .results(let r, _, _): return r
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Round Error
// ─────────────────────────────────────────────────────────────

enum RoundError: LocalizedError, Identifiable {
    case insufficientFunds
    case roundAlreadyStarted
    case alreadyJoined
    case notEnoughPlayers
    case mustSubmitFirst
    case sessionNotFound
    case roundNotFound
    case uploadFailed(String)
    case unknown(String)

    // Identifiable — uses a stable string so alert(item:) works
    var id: String {
        switch self {
        case .insufficientFunds:    return "insufficientFunds"
        case .roundAlreadyStarted:  return "roundAlreadyStarted"
        case .alreadyJoined:        return "alreadyJoined"
        case .notEnoughPlayers:     return "notEnoughPlayers"
        case .mustSubmitFirst:      return "mustSubmitFirst"
        case .sessionNotFound:      return "sessionNotFound"
        case .roundNotFound:        return "roundNotFound"
        case .uploadFailed(let m):  return "uploadFailed_\(m)"
        case .unknown(let m):       return "unknown_\(m)"
        }
    }

    var errorDescription: String? {
        switch self {
        case .insufficientFunds:    return "You don't have enough balance for this entry fee."
        case .roundAlreadyStarted:  return "This round has already started."
        case .alreadyJoined:        return "You've already joined this round."
        case .notEnoughPlayers:     return "Need at least 2 players to start."
        case .mustSubmitFirst:      return "You need to submit a photo first."
        case .sessionNotFound:      return "Session not found."
        case .roundNotFound:        return "Round not found."
        case .uploadFailed(let m):  return "Upload failed: \(m)"
        case .unknown(let m):       return m
        }
    }

    var requiresTopUp: Bool {
        if case .insufficientFunds = self { return true }
        return false
    }

    static func from(_ error: Error) -> RoundError {
        let msg = error.localizedDescription
        if msg.contains("Insufficient funds")  { return .insufficientFunds }
        if msg.contains("already started")     { return .roundAlreadyStarted }
        if msg.contains("already joined")      { return .alreadyJoined }
        if msg.contains("2 players")           { return .notEnoughPlayers }
        if msg.contains("submit a photo")      { return .mustSubmitFirst }
        if msg.contains("Session not found")   { return .sessionNotFound }
        if msg.contains("Round not found")     { return .roundNotFound }
        return .unknown(msg)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Camera Step
// ─────────────────────────────────────────────────────────────

enum CameraStep {
    case hidden
    case camera
    case preview(UIImage, Bool)
    case entryFee(UIImage, Bool)
}

// ─────────────────────────────────────────────────────────────
// MARK: - SessionViewModel
// ─────────────────────────────────────────────────────────────

final class SessionViewModel: ObservableObject {

    // ── Public state ──────────────────────────────────────────
    @Published private(set) var phase: RoundPhase          = .idle
    @Published private(set) var cameraStep: CameraStep     = .hidden
    @Published private(set) var submissions: [Submission]  = []
    @Published private(set) var userProfiles: [String: UserProfile] = [:]
    @Published private(set) var participantIds: [String]   = []
    @Published private(set) var invitedIds: [String]       = []
    @Published private(set) var error: RoundError?         = nil
    @Published private(set) var isCreatingRound            = false
    @Published private(set) var isStartingRound            = false
    @Published private(set) var isLeavingRound             = false
    @Published var selectedEntryFee: Double                = 0.00

    let sessionId: String

    // ── Private ───────────────────────────────────────────────
    private let db            = Firestore.firestore()
    private let functions     = Functions.functions()
    private let currentUserId = Auth.auth().currentUser?.uid ?? ""

    private var sessionListener:     ListenerRegistration?
    private var roundListener:       ListenerRegistration?
    private var submissionsListener: ListenerRegistration?

    private var shownResultsForRoundId: String? = nil
    private var currentActiveRoundId: String?   = nil

    // ─────────────────────────────────────────────────────────
    // MARK: - Init / lifecycle
    // ─────────────────────────────────────────────────────────

    init(sessionId: String) {
        self.sessionId = sessionId
    }

    func start() {
        fetchSessionMetadata()
        attachSessionListener()
        attachRoundListener()
        ensureRoundExists()
    }

    func stopListening() {
        sessionListener?.remove()
        roundListener?.remove()
        submissionsListener?.remove()
        sessionListener     = nil
        roundListener       = nil
        submissionsListener = nil
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Computed
    // ─────────────────────────────────────────────────────────

    var currentRound: Round? { phase.round }

    var currentUserIsInRound: Bool {
        submissions.contains { $0.userId == currentUserId }
    }

    var currentUserSubmission: Submission? {
        submissions.first { $0.userId == currentUserId }
    }

    var pendingParticipantIds: [String] {
        invitedIds.filter { !participantIds.contains($0) }
    }

    var canStart: Bool {
        guard case .joined(let round) = phase, round.isWaiting else { return false }
        return submissions.count >= 2 && !isStartingRound
    }

    var sortedSubmissions: [Submission] {
        submissions.sorted { ($0.aiScore ?? 0) > ($1.aiScore ?? 0) }
    }

    func profile(for userId: String) -> UserProfile? {
        userProfiles[userId]
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Session metadata
    // ─────────────────────────────────────────────────────────

    private func fetchSessionMetadata() {
        db.collection("sessions").document(sessionId).getDocument { [weak self] snap, _ in
            guard let self, let data = snap?.data() else { return }
            DispatchQueue.main.async {
                self.participantIds = data["participant_ids"] as? [String] ?? []
                self.invitedIds     = data["invited_ids"]     as? [String] ?? []
                let allIds = Array(Set(self.participantIds + self.invitedIds))
                self.fetchProfiles(for: allIds)
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Session listener
    //
    // Watches last_completed_round_id. When it changes to a new
    // value, fetches that round + submissions and shows results.
    // This is the definitive fix for the judging→results race.
    // ─────────────────────────────────────────────────────────

    private func attachSessionListener() {
        sessionListener = db.collection("sessions").document(sessionId)
            .addSnapshotListener { [weak self] snap, error in
                guard let self else { return }
                if let error {
                    AppLogger.session("[SessionVM] session listener error: \(error)")
                    return
                }
                guard let data = snap?.data() else { return }

                DispatchQueue.main.async {
                    // Update participant lists
                    let newParticipants = data["participant_ids"] as? [String] ?? []
                    let newInvited      = data["invited_ids"]     as? [String] ?? []
                    if newParticipants != self.participantIds || newInvited != self.invitedIds {
                        self.participantIds = newParticipants
                        self.invitedIds     = newInvited
                        let unknown = Array(Set(newParticipants + newInvited))
                            .filter { self.userProfiles[$0] == nil }
                        if !unknown.isEmpty { self.fetchProfiles(for: unknown) }
                    }

                    // Check for a newly completed round
                    guard let completedId = data["last_completed_round_id"] as? String,
                          completedId != self.shownResultsForRoundId else { return }

                    // Only show results if we were part of this round
                    guard self.phase.round != nil else { return }

                    AppLogger.session("[SessionVM] last_completed_round_id → \(completedId)")
                    self.fetchAndShowResults(roundId: completedId)
                }
            }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Round listener
    // ─────────────────────────────────────────────────────────

    private func attachRoundListener() {
        let roundsRef = db.collection("sessions").document(sessionId).collection("rounds")

        roundListener = roundsRef
            .whereField("status", in: ["waiting", "judging"])
            .limit(to: 1)
            .addSnapshotListener { [weak self] snap, error in
                guard let self else { return }
                if let error {
                    AppLogger.session("[SessionVM] round listener error: \(error)")
                    return
                }

                DispatchQueue.main.async {
                    guard let doc = snap?.documents.first else {
                        AppLogger.session("[SessionVM] no active round in listener")
                        // Don't touch phase if we're showing results or judging
                        // (results come via session listener)
                        switch self.phase {
                        case .results, .judging: return
                        default:
                            self.phase       = .idle
                            self.submissions = []
                            self.currentActiveRoundId = nil
                        }
                        return
                    }

                    guard let round = Round(id: doc.documentID, sessionId: self.sessionId, data: doc.data()) else {
                        return
                    }

                    if round.id != self.currentActiveRoundId {
                        self.currentActiveRoundId = round.id
                        self.attachSubmissionsListener(roundId: round.id)
                    }

                    self.applyRoundUpdate(round)
                }
            }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Apply round update (guarded transitions)
    // ─────────────────────────────────────────────────────────

    private func applyRoundUpdate(_ round: Round) {
        switch round.status {
        case .waiting:
            switch phase {
            case .idle:
                phase = currentUserIsInRound ? .joined(round) : .lobby(round)
            case .lobby:
                phase = .lobby(round)
            case .joining:
                break // join call will transition us
            case .joined:
                phase = .joined(round)
            case .judging, .results:
                break // never move backwards
            }

        case .judging:
            switch phase {
            case .lobby, .joining, .joined:
                phase      = .judging(round)
                cameraStep = .hidden
            case .judging:
                phase = .judging(round)
            case .idle, .results:
                break
            }

        case .complete:
            break // handled by session listener

        case .failed:
            error = .unknown("Something went wrong with this round.")
            phase = .idle

        case .cancelled:
            switch phase {
            case .results: break
            default:
                phase       = .idle
                submissions = []
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Submissions listener
    // ─────────────────────────────────────────────────────────

    private func attachSubmissionsListener(roundId: String) {
        submissionsListener?.remove()

        let ref = db.collection("sessions").document(sessionId)
            .collection("rounds").document(roundId)
            .collection("submissions")

        submissionsListener = ref.addSnapshotListener { [weak self] snap, error in
            guard let self else { return }
            guard let docs = snap?.documents else { return }

            DispatchQueue.main.async {
                let subs = docs.compactMap { Submission(userId: $0.documentID, data: $0.data()) }

                // ── Logging ──────────────────────────────────────
                AppLogger.session("[SubListener] fired — \(subs.count) submissions, phase=\(self.phaseDescription)")
                for sub in subs {
                    let isMe = sub.userId == self.currentUserId
                    let urlTail = String(sub.photoUrl.suffix(60))
                    AppLogger.session("[SubListener] \(isMe ? "ME" : sub.userId.prefix(6)) → url=...\(urlTail)")
                }
                // ── End logging ──────────────────────────────────

                // Log if our own URL changed vs what we currently have
                if let currentMySub = self.submissions.first(where: { $0.userId == self.currentUserId }),
                   let newMySub     = subs.first(where: { $0.userId == self.currentUserId }) {
                    if currentMySub.photoUrl != newMySub.photoUrl {
                        AppLogger.session("[SubListener] MY PHOTO URL CHANGED — old=...\(currentMySub.photoUrl.suffix(40)) new=...\(newMySub.photoUrl.suffix(40))")
                    } else {
                        AppLogger.session("[SubListener] my photo URL unchanged")
                    }
                }

                self.submissions = subs

                let unknown = subs.map(\.userId).filter { self.userProfiles[$0] == nil }
                if !unknown.isEmpty { self.fetchProfiles(for: unknown) }

                // Confirm join if we were in joining state
                if case .joining(let round) = self.phase {
                    if subs.contains(where: { $0.userId == self.currentUserId }) {
                        AppLogger.session("[SubListener] joining → joined confirmed")
                        self.phase = .joined(round)
                    }
                }

                // Detect leave — if we were joined but our submission
                // is gone, drop back to lobby so the join card reappears
                if case .joined(let round) = self.phase {
                    if !subs.contains(where: { $0.userId == self.currentUserId }) {
                        AppLogger.session("[SubListener] joined → lobby (submission removed)")
                        self.phase = .lobby(round)
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Fetch and show results
    // ─────────────────────────────────────────────────────────

    private func fetchAndShowResults(roundId: String) {
        let sessionId = self.sessionId
        let roundRef  = db.collection("sessions").document(sessionId)
            .collection("rounds").document(roundId)

        roundRef.getDocument { [weak self] roundSnap, _ in
            guard let self,
                  let roundData = roundSnap?.data(),
                  let round = Round(id: roundId, sessionId: sessionId, data: roundData) else { return }

            roundRef.collection("submissions").getDocuments { [weak self] subsSnap, _ in
                guard let self else { return }
                let subs = subsSnap?.documents
                    .compactMap { Submission(userId: $0.documentID, data: $0.data()) } ?? []

                DispatchQueue.main.async {
                    self.shownResultsForRoundId = roundId
                    self.submissions            = subs
                    self.phase                  = .results(round, subs, self.userProfiles)
                    AppLogger.session("[SessionVM] showing results for \(roundId)")
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Profiles
    // ─────────────────────────────────────────────────────────

    func fetchProfiles(for userIds: [String]) {
        guard !userIds.isEmpty else { return }
        let chunks = stride(from: 0, to: userIds.count, by: 30).map {
            Array(userIds[$0..<min($0 + 30, userIds.count)])
        }
        for chunk in chunks {
            db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments { [weak self] snap, _ in
                    guard let self, let docs = snap?.documents else { return }
                    DispatchQueue.main.async {
                        for doc in docs {
                            self.userProfiles[doc.documentID] = UserProfile(id: doc.documentID, data: doc.data())
                        }
                        // Refresh results with updated profiles
                        if case .results(let r, let s, _) = self.phase {
                            self.phase = .results(r, s, self.userProfiles)
                        }
                    }
                }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Ensure round exists
    // ─────────────────────────────────────────────────────────

    private func ensureRoundExists() {
        functions.httpsCallable("createRound").call(["sessionId": sessionId]) { [weak self] result, error in
            guard let self else { return }
            if let error {
                AppLogger.session("[SessionVM] ensureRoundExists failed: \(error)")
                return
            }
            let data    = result?.data as? [String: Any]
            let roundId = data?["round_id"] as? String ?? "?"
            let created = data?["created"]  as? Bool   ?? false
            AppLogger.session("[SessionVM] ensureRoundExists → \(roundId) created=\(created)")
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Camera flow
    // ─────────────────────────────────────────────────────────

    func openCamera() {
        cameraStep = .camera
    }

    func onPhotoSelected(image: UIImage, isFromCamera: Bool) {
        cameraStep = .preview(image, isFromCamera)
    }

    func onPreviewConfirmed(image: UIImage, isFromCamera: Bool) {
        cameraStep = .entryFee(image, isFromCamera)
    }

    func onPreviewRetake() {
        cameraStep = .camera
    }

    func onCameraCancel() {
        cameraStep = .hidden
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Join round
    // ─────────────────────────────────────────────────────────

    func joinRound(photoUrl: String, entryFee: Double, isFromCamera: Bool) {
        guard let round = currentRound, round.isWaiting else {
            error      = .roundAlreadyStarted
            cameraStep = .hidden
            return
        }

        phase      = .joining(round)
        cameraStep = .hidden

        let params: [String: Any] = [
            "sessionId":    sessionId,
            "roundId":      round.id,
            "photoUrl":     photoUrl,
            "entryFee":     entryFee,
            "isFromCamera": isFromCamera
        ]

        functions.httpsCallable("joinRound").call(params) { [weak self] _, error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let error {
                    AppLogger.session("[SessionVM] joinRound failed: \(error)")
                    self.error = RoundError.from(error)
                    self.phase = .lobby(round)
                } else {
                    AppLogger.session("[SessionVM] joinRound succeeded")
                    // Submissions listener will also confirm this,
                    // but set it here so there's no visible gap
                    self.phase = .joined(round)
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Leave round
    // ─────────────────────────────────────────────────────────

    func leaveRound() {
        guard let round = currentRound, round.isWaiting, !isLeavingRound else { return }
        isLeavingRound = true

        let params: [String: Any] = ["sessionId": sessionId, "roundId": round.id]
        functions.httpsCallable("leaveRound").call(params) { [weak self] _, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isLeavingRound = false
                if let error {
                    AppLogger.session("[SessionVM] leaveRound failed: \(error)")
                    self.error = RoundError.from(error)
                }
                // Listener handles phase transition
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Start round
    // ─────────────────────────────────────────────────────────

    func startRound() {
        guard canStart, let round = currentRound else { return }
        isStartingRound = true

        let params: [String: Any] = ["sessionId": sessionId, "roundId": round.id]
        functions.httpsCallable("startRound").call(params) { [weak self] _, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isStartingRound = false
                if let error {
                    AppLogger.session("[SessionVM] startRound failed: \(error)")
                    self.error = RoundError.from(error)
                }
                // Listeners drive the phase to judging → results
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Play again
    // ─────────────────────────────────────────────────────────

    func playAgain() {
        AppLogger.session("[SessionVM] playAgain")
        submissions      = []
        selectedEntryFee = 0.00
        isCreatingRound  = true
        phase            = .idle

        functions.httpsCallable("createRound").call(["sessionId": sessionId]) { [weak self] result, error in
            guard let self else { return }

            if let error {
                AppLogger.session("[SessionVM] playAgain createRound failed: \(error)")
                DispatchQueue.main.async {
                    self.isCreatingRound = false
                    self.error = RoundError.from(error)
                }
                return
            }

            guard let roundId = (result?.data as? [String: Any])?["round_id"] as? String else {
                DispatchQueue.main.async { self.isCreatingRound = false }
                return
            }

            AppLogger.session("[SessionVM] playAgain: new round \(roundId)")

            // Fetch the round directly — don't wait for the listener
            self.db.collection("sessions").document(self.sessionId)
                .collection("rounds").document(roundId)
                .getDocument { [weak self] snap, _ in
                    guard let self else { return }
                    DispatchQueue.main.async {
                        self.isCreatingRound = false
                        guard let data  = snap?.data(),
                              let round = Round(id: roundId, sessionId: self.sessionId, data: data) else { return }
                        self.currentActiveRoundId = roundId
                        self.attachSubmissionsListener(roundId: roundId)
                        self.phase = .lobby(round)
                    }
                }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Dismiss results
    // ─────────────────────────────────────────────────────────

    func dismissResults() {
        phase       = .idle
        submissions = []
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Invite more
    // ─────────────────────────────────────────────────────────

    func inviteMore(friendIds: [String]) {
        guard !friendIds.isEmpty else { return }

        functions.httpsCallable("inviteMore").call([
            "sessionId": sessionId,
            "friendIds": friendIds
        ]) { [weak self] _, error in
            guard let self else { return }
            if let error {
                AppLogger.session("[SessionVM] inviteMore failed: \(error)")
                return
            }
            DispatchQueue.main.async {
                for id in friendIds where !self.invitedIds.contains(id) {
                    self.invitedIds.append(id)
                }
            }
        }

        functions.httpsCallable("sendCallInvite").call([
            "sessionId": sessionId,
            "friendIds": friendIds
        ]) { _, _ in }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Clear error
    // ─────────────────────────────────────────────────────────

    private var phaseDescription: String {
        switch phase {
        case .idle:    return "idle"
        case .lobby:   return "lobby"
        case .joining: return "joining"
        case .joined:  return "joined"
        case .judging: return "judging"
        case .results: return "results"
        }
    }

    func clearError() {
        error = nil
    }
}
