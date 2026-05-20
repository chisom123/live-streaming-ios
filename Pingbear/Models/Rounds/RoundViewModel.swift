import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

class RoundViewModel: ObservableObject {

    // ─────────────────────────────────────────────────────────────
    // MARK: - Published State
    // ─────────────────────────────────────────────────────────────

    @Published var roundInfo: RoundInfo?
    @Published var submissions: [RoundSubmission] = []
    @Published var userProfiles: [String: UserProfile] = [:]
    @Published var isLoading: Bool = true
    @Published var isStartingRound: Bool = false
    @Published var isJoining: Bool = false
    @Published var isLeaving: Bool = false
    @Published var errorMessage: String? = nil

    /// Flips to true when a round completes. Watched by CompDetails via
    /// onChange to refresh the leaderboard once results are dismissed.
    @Published var justCompletedRound: Bool = false

    /// Remembered from the most recently completed round.
    /// Used to skip the theme picker on Play Again.
    @Published var lastThemeId: String? = nil
    @Published var lastThemeName: String? = nil

    /// Set to true when the user taps the back arrow in the lobby or judging view.
    /// Reset to false when status flips to .judging, or user taps Open Round.
    @Published var isDismissedByUser: Bool = false

    // ── Results snapshot ──────────────────────────────────────────
    /// True while RoundResultsView should be shown. Presented from
    /// RoundJudgingView's own fullScreenCover — CompDetails never
    /// touches this directly.
    @Published var showResults: Bool = false
    private(set) var completedRoundInfo: RoundInfo? = nil
    private(set) var completedSubmissions: [RoundSubmission] = []
    private(set) var completedUserProfiles: [String: UserProfile] = [:]

    /// True from the moment Play Again is tapped until the Firestore
    /// listener delivers the new round. Keeps shouldShowRoundCover true
    /// so the cover never collapses between rounds.
    @Published var isAwaitingNextRound: Bool = false

    /// True while RoundJudgingView is running the score reveal sequence.
    /// Keeps shouldShowRoundCover true between fetchCompletedSubmissions
    /// completing (roundInfo=nil, showResults=false) and the reveal
    /// finishing and setting showResults=true.
    @Published var isRevealingScores: Bool = false

    // ─────────────────────────────────────────────────────────────
    // MARK: - Computed Helpers
    // ─────────────────────────────────────────────────────────────

    var hasActiveRound: Bool { roundInfo != nil }

    /// CompDetails' cover stays open when:
    ///   - there's an active round (lobby or judging), OR
    ///   - judging just finished and we're holding the judging view
    ///     alive underneath the results cover, OR
    ///   - Play Again was tapped and we're waiting for the new round doc
    /// AND the user hasn't explicitly backed out.
    var shouldShowRoundCover: Bool {
        (hasActiveRound || showResults || isAwaitingNextRound || isRevealingScores) && !isDismissedByUser
    }

    var canStart: Bool {
        submissions.count >= 2 &&
        roundInfo?.status == .waiting &&
        !isStartingRound &&
        currentUserIsInRound
    }

    var currentUserIsInRound: Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        return submissions.contains { $0.userId == uid }
    }

    var currentUserSubmission: RoundSubmission? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return submissions.first { $0.userId == uid }
    }

    var totalPot: Double { roundInfo?.totalPot ?? 0.0 }

    var sortedSubmissions: [RoundSubmission] {
        switch roundInfo?.status {
        case .waiting:
            return submissions.sorted { $0.submittedAt < $1.submittedAt }
        default:
            return submissions.sorted { ($0.aiScore ?? -1) > ($1.aiScore ?? -1) }
        }
    }

    func isWinner(_ userId: String) -> Bool {
        roundInfo?.winnerIds.contains(userId) ?? false
    }

    func profile(for userId: String) -> UserProfile? {
        userProfiles[userId]
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Private
    // ─────────────────────────────────────────────────────────────

    private let db = Firestore.firestore()
    private var roundListener: ListenerRegistration?
    private var submissionsListener: ListenerRegistration?
    private var competitionId: String = ""

    deinit { stopListening() }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Start Listening
    // ─────────────────────────────────────────────────────────────

    func startListening(competitionId: String) {
        self.competitionId = competitionId
        isLoading = true

        roundListener?.remove()
        roundListener = db.collection("rounds")
            .whereField("competition_id", isEqualTo: competitionId)
            .whereField("status", in: ["waiting", "judging"])
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    print("RoundViewModel: Listener error: \(error)")
                    DispatchQueue.main.async { self.isLoading = false }
                    return
                }

                guard let doc = snapshot?.documents.first,
                      let round = RoundInfo(document: doc) else {
                    // No active round — may have just completed.
                    if let activeRound = self.roundInfo {
                        self.fetchCompletedSubmissions(for: activeRound)
                    } else {
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.roundInfo = nil
                            self.submissions = []
                        }
                    }
                    self.submissionsListener?.remove()
                    return
                }

                // While results are shown, ignore listener updates UNLESS
                // Play Again created a new round (isAwaitingNextRound = true).
                if self.showResults && !self.isAwaitingNextRound { return }

                DispatchQueue.main.async {
                    if round.status == .judging && self.roundInfo?.status == .waiting {
                        self.isDismissedByUser = false
                    }
                    self.roundInfo = round
                    self.isLoading = false
                    // isAwaitingNextRound intentionally NOT cleared here.
                    // It stays true until dismissResults() is called so the
                    // Play Again button keeps showing its spinner right up
                    // until the results cover finishes sliding away.
                }

                self.listenToSubmissions(roundId: round.roundId)
            }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Dismiss / Re-enter
    // ─────────────────────────────────────────────────────────────

    func dismissRoundCover() {
        isDismissedByUser = true
    }

    func reenterRound() {
        isDismissedByUser = false
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Fetch Completed Submissions
    // ─────────────────────────────────────────────────────────────

    private func fetchCompletedSubmissions(for round: RoundInfo) {
        db.collection("rounds").document(round.roundId).getDocument { [weak self] snap, _ in
            guard let self else { return }

            var finalRound = round
            if let data = snap?.data() {
                finalRound = RoundInfo(
                    roundId:          round.roundId,
                    competitionId:    round.competitionId,
                    status:           .complete,
                    themeName:        round.themeName,
                    themeId:          round.themeId,
                    createdBy:        round.createdBy,
                    totalPot:         data["total_pot"]    as? Double   ?? round.totalPot,
                    platformFee:      data["platform_fee"] as? Double   ?? 0.0,
                    roundReward:      data["round_reward"] as? Double   ?? 0.0,
                    winnerIds:        data["winner_ids"]   as? [String] ?? [],
                    participantCount: round.participantCount,
                    createdAt:        round.createdAt,
                    startedAt:        round.startedAt,
                    endedAt:          (data["ended_at"] as? Timestamp)?.dateValue()
                )
            }

            self.db.collection("rounds")
                .document(round.roundId)
                .collection("submissions")
                .getDocuments { [weak self] subSnap, _ in
                    guard let self else { return }

                    let finalSubs = subSnap?.documents.compactMap {
                        RoundSubmission(document: $0)
                    } ?? []

                    let sortedSubs = finalSubs.sorted {
                        ($0.aiScore ?? -1) > ($1.aiScore ?? -1)
                    }

                    self.prefetchImages(for: sortedSubs) {
                        DispatchQueue.main.async {
                            self.completedRoundInfo      = finalRound
                            self.completedSubmissions    = sortedSubs
                            self.completedUserProfiles   = self.userProfiles
                            self.roundInfo               = nil
                            self.submissions             = []
                            self.isLoading               = false
                            self.justCompletedRound      = true
                            self.isDismissedByUser       = false
                            self.lastThemeId             = finalRound.themeId
                            self.lastThemeName           = finalRound.themeName
                            // Signal that the reveal sequence is about to start.
                            // Keeps shouldShowRoundCover true until showResults
                            // takes over at the end of the reveal.
                            self.isRevealingScores       = true
                            // Do NOT set showResults here. RoundJudgingView runs
                            // the reveal sequence first; it sets showResults = true
                            // itself after the winner card lands and the 2s hold
                            // completes. This keeps the reveal and navigation in sync.
                        }
                    }
                }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Prefetch Images
    // ─────────────────────────────────────────────────────────────

    private func prefetchImages(for submissions: [RoundSubmission], completion: @escaping () -> Void) {
        let urls = submissions.compactMap { URL(string: $0.photoUrl) }
        guard !urls.isEmpty else { completion(); return }

        let group = DispatchGroup()
        for url in urls {
            let request = URLRequest(url: url)
            if URLCache.shared.cachedResponse(for: request) != nil { continue }
            group.enter()
            URLSession.shared.dataTask(with: request) { data, response, _ in
                if let data, let response {
                    URLCache.shared.storeCachedResponse(
                        CachedURLResponse(response: response, data: data), for: request)
                }
                group.leave()
            }.resume()
        }
        group.notify(queue: .global()) { completion() }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Listen To Submissions
    // ─────────────────────────────────────────────────────────────

    private func listenToSubmissions(roundId: String) {
        submissionsListener?.remove()
        submissionsListener = db.collection("rounds")
            .document(roundId)
            .collection("submissions")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("RoundViewModel: Submissions error: \(error)")
                    return
                }
                let parsed = snapshot?.documents.compactMap {
                    RoundSubmission(document: $0)
                } ?? []
                DispatchQueue.main.async { self.submissions = parsed }
                let newIds = Set(parsed.map { $0.userId }).subtracting(Set(self.userProfiles.keys))
                if !newIds.isEmpty { self.fetchUserProfiles(userIds: Array(newIds)) }
            }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Fetch User Profiles
    // ─────────────────────────────────────────────────────────────

    private func fetchUserProfiles(userIds: [String]) {
        guard !userIds.isEmpty else { return }
        let currentUserId = Auth.auth().currentUser?.uid
        db.collection("users")
            .whereField(FieldPath.documentID(), in: userIds)
            .getDocuments { [weak self] snapshot, _ in
                guard let self else { return }
                var profiles: [String: UserProfile] = [:]
                snapshot?.documents.forEach { doc in
                    let data = doc.data()
                    let isMe = doc.documentID == currentUserId
                    profiles[doc.documentID] = UserProfile(
                        userId:            doc.documentID,
                        username:          isMe ? "Me" : (data["name"] as? String ?? "Unknown"),
                        profilePictureUrl: data["profilePictureUrl"] as? String,
                        isCurrentUser:     isMe
                    )
                }
                DispatchQueue.main.async {
                    self.userProfiles.merge(profiles) { _, new in new }
                }
            }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Dismiss Results
    // ─────────────────────────────────────────────────────────────

    func dismissResults() {
        showResults           = false
        completedRoundInfo    = nil
        completedSubmissions  = []
        completedUserProfiles = [:]
        isRevealingScores     = false
        // Clear here — not in the listener — so the spinner stays visible
        // on the Play Again button right until the cover finishes sliding away.
        isAwaitingNextRound   = false
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Reset For Next Round (Play Again)
    //
    // Does NOT dismiss results — results stay visible as the foreground
    // while we wait for the new round doc. Once Firestore delivers it,
    // RoundJudgingView's onChange(roundInfo) calls dismissResults(),
    // which drops the results cover and reveals the fresh lobby beneath.
    // This means the user never sees the judging spinner between rounds.
    // ─────────────────────────────────────────────────────────────

    func resetForNextRound() {
        // Signal that a new round is incoming so shouldShowRoundCover
        // stays true even after results are eventually dismissed.
        isAwaitingNextRound = true
        // Clear round state but leave showResults = true so results
        // stay on screen until the lobby is ready to replace them.
        roundInfo        = nil
        submissions      = []
        isStartingRound  = false
        isJoining        = false
        isLeaving        = false
        errorMessage     = nil
        isDismissedByUser = false
        startListening(competitionId: competitionId)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Clear Results On Disappear
    // ─────────────────────────────────────────────────────────────

    func clearResultsIfNotDismissed() {
        if showResults {
            showResults           = false
            completedRoundInfo    = nil
            completedSubmissions  = []
            completedUserProfiles = [:]
            isAwaitingNextRound   = false
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Actions
    // ─────────────────────────────────────────────────────────────

    func createRound(
        themeId: String?,
        themeName: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        RoundManager.shared.createRound(
            competitionId: competitionId,
            themeId: themeId,
            themeName: themeName
        ) { [weak self] result in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                }
                completion(result)
            }
        }
    }

    func updateTheme(themeId: String?, themeName: String) {
        guard let roundId = roundInfo?.roundId else { return }
        RoundManager.shared.updateRoundTheme(
            roundId: roundId,
            themeId: themeId,
            themeName: themeName
        ) { [weak self] success in
            DispatchQueue.main.async {
                if !success { self?.errorMessage = "Failed to update theme." }
            }
        }
    }

    func joinRound(
        roundId: String,
        photoUrl: String,
        entryFee: Double,
        isFromCamera: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        isJoining = true
        RoundManager.shared.joinRound(
            roundId: roundId,
            competitionId: competitionId,
            photoUrl: photoUrl,
            entryFee: entryFee,
            isFromCamera: isFromCamera
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isJoining = false
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                }
                completion(result)
            }
        }
    }

    func leaveRound(completion: @escaping (Result<LeaveRoundResult, Error>) -> Void) {
        guard let roundId = roundInfo?.roundId else { return }
        isLeaving = true
        RoundManager.shared.leaveRound(
            roundId: roundId,
            competitionId: competitionId
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLeaving = false
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                }
                completion(result)
            }
        }
    }

    func startRound(completion: @escaping (Result<RoundResult, Error>) -> Void) {
        guard let roundId = roundInfo?.roundId else { return }
        guard canStart else {
            completion(.failure(RoundError.notEnoughPlayers))
            return
        }
        isStartingRound = true
        RoundManager.shared.startRound(
            roundId: roundId,
            competitionId: competitionId
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isStartingRound = false
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                }
                completion(result)
            }
        }
    }

    func sendNudge(
        competitionName: String,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        RoundManager.shared.sendRoundNudge(
            competitionId: competitionId,
            competitionName: competitionName
        ) { [weak self] result in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                }
                completion(result)
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Cleanup
    // ─────────────────────────────────────────────────────────────

    func stopListening() {
        roundListener?.remove()
        submissionsListener?.remove()
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Supporting Models
// ─────────────────────────────────────────────────────────────

struct UserProfile {
    let userId:            String
    let username:          String
    let profilePictureUrl: String?
    let isCurrentUser:     Bool
}
