import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

class RoundManager {
    static let shared = RoundManager()
    private let functions = Functions.functions()
    private init() {}

    // ─────────────────────────────────────────────────────────────
    // MARK: - Create Round
    //
    // Creates a new round lobby for a competition.
    // If an active round already exists, returns that instead.
    // ─────────────────────────────────────────────────────────────

    func createRound(
        competitionId: String,
        themeId: String?,
        themeName: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        var params: [String: Any] = [
            "competitionId": competitionId,
            "themeName":     themeName
        ]
        if let themeId { params["themeId"] = themeId }

        functions.httpsCallable("createRound").call(params) { result, error in
            if let error {
                print("RoundManager: ❌ createRound failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data   = result?.data as? [String: Any],
                  let roundId = data["round_id"] as? String else {
                completion(.failure(RoundError.invalidResponse))
                return
            }

            let created = data["created"] as? Bool ?? true
            print("RoundManager: ✅ Round \(roundId) \(created ? "created" : "already existed") for competition \(competitionId)")
            completion(.success(roundId))
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Update Round Theme
    //
    // Any participant in the waiting lobby can change the theme.
    // ─────────────────────────────────────────────────────────────

    func updateRoundTheme(
        roundId: String,
        themeId: String?,
        themeName: String,
        completion: @escaping (Bool) -> Void
    ) {
        var params: [String: Any] = [
            "roundId":   roundId,
            "themeName": themeName
        ]
        if let themeId { params["themeId"] = themeId }

        functions.httpsCallable("updateRoundTheme").call(params) { _, error in
            if let error {
                print("RoundManager: ❌ updateRoundTheme failed: \(error.localizedDescription)")
                completion(false)
                return
            }
            print("RoundManager: ✅ Theme updated to \"\(themeName)\" in round \(roundId)")
            completion(true)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Join Round
    //
    // Submits a photo and optional entry fee to the round lobby.
    // Entry fee is deducted from wallet atomically server-side.
    // ─────────────────────────────────────────────────────────────

    func joinRound(
        roundId: String,
        competitionId: String,
        photoUrl: String,
        entryFee: Double,
        isFromCamera: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let params: [String: Any] = [
            "roundId":       roundId,
            "competitionId": competitionId,
            "photoUrl":      photoUrl,
            "entryFee":      entryFee,
            "isFromCamera":  isFromCamera
        ]

        functions.httpsCallable("joinRound").call(params) { _, error in
            if let error {
                print("RoundManager: ❌ joinRound failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            print("RoundManager: ✅ Joined round \(roundId) with entry fee $\(String(format: "%.2f", entryFee))")
            completion(.success(()))
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Leave Round
    //
    // Removes player from lobby and refunds their entry fee.
    // If last player, the round document is deleted entirely.
    // ─────────────────────────────────────────────────────────────

    func leaveRound(
        roundId: String,
        competitionId: String,
        completion: @escaping (Result<LeaveRoundResult, Error>) -> Void
    ) {
        let params: [String: Any] = [
            "roundId":       roundId,
            "competitionId": competitionId
        ]

        functions.httpsCallable("leaveRound").call(params) { result, error in
            if let error {
                print("RoundManager: ❌ leaveRound failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = result?.data as? [String: Any] else {
                completion(.failure(RoundError.invalidResponse))
                return
            }

            let refundAmount = data["refund_amount"] as? Double ?? 0.0
            let roundDeleted = data["round_deleted"] as? Bool   ?? false

            print("RoundManager: ✅ Left round \(roundId). Refund: $\(String(format: "%.2f", refundAmount)). Deleted: \(roundDeleted)")
            completion(.success(LeaveRoundResult(refundAmount: refundAmount, roundDeleted: roundDeleted)))
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Start Round
    //
    // Locks the lobby, triggers Gemini scoring, distributes payouts.
    // Requires 2+ submissions. Any participant can call this.
    // This call may take up to ~30 seconds while Gemini scores photos.
    // ─────────────────────────────────────────────────────────────

    func startRound(
        roundId: String,
        competitionId: String,
        completion: @escaping (Result<RoundResult, Error>) -> Void
    ) {
        let params: [String: Any] = [
            "roundId":       roundId,
            "competitionId": competitionId
        ]

        // Longer timeout — Gemini scoring can take up to 30 seconds
        let callable = functions.httpsCallable(
            "startRound",
            options: HTTPSCallableOptions(requireLimitedUseAppCheckTokens: false)
        )

        callable.timeoutInterval = 120

        callable.call(params) { result, error in
            if let error {
                print("RoundManager: ❌ startRound failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = result?.data as? [String: Any] else {
                completion(.failure(RoundError.invalidResponse))
                return
            }

            let winnerIds       = data["winner_ids"]        as? [String] ?? []
            let highScore       = data["high_score"]        as? Double   ?? 0.0
            let totalPot        = data["total_pot"]         as? Double   ?? 0.0
            let platformFee     = data["platform_fee"]      as? Double   ?? 0.0
            let roundReward     = data["round_reward"]      as? Double   ?? 0.0
            let payoutPerWinner = data["payout_per_winner"] as? Double   ?? 0.0

            // Parse individual results
            let rawResults = data["results"] as? [[String: Any]] ?? []
            let results: [SubmissionResult] = rawResults.compactMap { dict in
                guard let userId   = dict["user_id"]   as? String,
                      let score    = dict["score"]     as? Double,
                      let reason   = dict["reason"]    as? String else { return nil }
                let entryFee = dict["entry_fee"] as? Double ?? 0.0
                return SubmissionResult(
                    userId:   userId,
                    score:    score,
                    reason:   reason,
                    entryFee: entryFee
                )
            }

            let roundResult = RoundResult(
                winnerIds:       winnerIds,
                highScore:       highScore,
                totalPot:        totalPot,
                platformFee:     platformFee,
                roundReward:     roundReward,
                payoutPerWinner: payoutPerWinner,
                results:         results
            )

            print("RoundManager: ✅ Round \(roundId) complete. Winners: \(winnerIds). Pot: $\(totalPot)")
            completion(.success(roundResult))
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Send Round Nudge
    //
    // Sends a push notification to all competition members
    // alerting them that someone wants to play.
    // Rate limited to once per 2 minutes server-side.
    // ─────────────────────────────────────────────────────────────

    func sendRoundNudge(
        competitionId: String,
        competitionName: String,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        let params: [String: Any] = [
            "competitionId":   competitionId,
            "competitionName": competitionName
        ]

        functions.httpsCallable("sendRoundNudge").call(params) { result, error in
            if let error {
                print("RoundManager: ❌ sendRoundNudge failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            let sent = (result?.data as? [String: Any])?["sent"] as? Int ?? 0
            print("RoundManager: ✅ Nudge sent to \(sent) members in competition \(competitionId)")
            completion(.success(sent))
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Models
// ─────────────────────────────────────────────────────────────

enum RoundError: LocalizedError {
    case invalidResponse
    case notEnoughPlayers
    case roundAlreadyStarted
    case alreadyInRound

    var errorDescription: String? {
        switch self {
        case .invalidResponse:    return "Unexpected response from server."
        case .notEnoughPlayers:   return "Need at least 2 players to start."
        case .roundAlreadyStarted: return "This round has already started."
        case .alreadyInRound:     return "You have already joined this round."
        }
    }
}

struct LeaveRoundResult {
    let refundAmount: Double
    let roundDeleted: Bool
}

struct RoundResult: Equatable {
    let winnerIds:       [String]
    let highScore:       Double
    let totalPot:        Double
    let platformFee:     Double
    let roundReward:     Double
    let payoutPerWinner: Double
    let results:         [SubmissionResult]
}

struct SubmissionResult: Equatable {
    let userId:   String
    let score:    Double
    let reason:   String
    let entryFee: Double
}

// ─────────────────────────────────────────────────────────────
// MARK: - Round Info (Firestore model)
// ─────────────────────────────────────────────────────────────

struct RoundInfo {
    let roundId:          String
    let competitionId:    String
    let status:           RoundStatus
    let themeName:        String
    let themeId:          String?
    let createdBy:        String
    let totalPot:         Double
    let platformFee:      Double
    let roundReward:      Double
    let winnerIds:        [String]
    let participantCount: Int
    let createdAt:        Date
    let startedAt:        Date?
    let endedAt:          Date?

    enum RoundStatus: String {
        case waiting  = "waiting"
        case judging  = "judging"
        case complete = "complete"
        case failed   = "failed"

        var isActive: Bool {
            self == .waiting || self == .judging
        }
    }

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()

        guard let competitionId    = data["competition_id"] as? String,
              let statusRaw        = data["status"]         as? String,
              let status           = RoundStatus(rawValue: statusRaw),
              let themeName        = data["theme_name"]     as? String,
              let createdBy        = data["created_by"]     as? String else {
            return nil
        }

        self.roundId          = document.documentID
        self.competitionId    = competitionId
        self.status           = status
        self.themeName        = themeName
        self.themeId          = data["theme_id"]          as? String
        self.createdBy        = createdBy
        self.totalPot         = data["total_pot"]         as? Double ?? 0.0
        self.platformFee      = data["platform_fee"]      as? Double ?? 0.0
        self.roundReward      = data["round_reward"]      as? Double ?? 0.0
        self.winnerIds        = data["winner_ids"]        as? [String] ?? []
        self.participantCount = data["participant_count"] as? Int    ?? 0
        self.createdAt        = (data["created_at"]       as? Timestamp)?.dateValue() ?? Date()
        self.startedAt        = (data["started_at"]       as? Timestamp)?.dateValue()
        self.endedAt          = (data["ended_at"]         as? Timestamp)?.dateValue()
    }

    // Memberwise init for constructing updated RoundInfo after round completes
    init(
        roundId: String, competitionId: String, status: RoundStatus,
        themeName: String, themeId: String?, createdBy: String,
        totalPot: Double, platformFee: Double, roundReward: Double,
        winnerIds: [String], participantCount: Int,
        createdAt: Date, startedAt: Date?, endedAt: Date?
    ) {
        self.roundId          = roundId
        self.competitionId    = competitionId
        self.status           = status
        self.themeName        = themeName
        self.themeId          = themeId
        self.createdBy        = createdBy
        self.totalPot         = totalPot
        self.platformFee      = platformFee
        self.roundReward      = roundReward
        self.winnerIds        = winnerIds
        self.participantCount = participantCount
        self.createdAt        = createdAt
        self.startedAt        = startedAt
        self.endedAt          = endedAt
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Round Submission (Firestore model)
// ─────────────────────────────────────────────────────────────

struct RoundSubmission: Identifiable {
    let id:          String   // userId
    let userId:      String
    let photoUrl:    String
    let entryFee:    Double
    let isFromCamera: Bool
    let aiScore:     Double?  // nil until judging complete
    let aiReason:    String?  // nil until judging complete
    let submittedAt: Date

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()

        guard let photoUrl = data["photo_url"] as? String else { return nil }

        self.id          = document.documentID
        self.userId      = document.documentID
        self.photoUrl    = photoUrl
        self.entryFee    = data["entry_fee"]    as? Double ?? 0.0
        self.aiScore     = data["ai_score"]     as? Double
        self.isFromCamera = data["is_from_camera"] as? Bool   ?? true
        self.aiReason    = data["ai_reason"]    as? String
        self.submittedAt = (data["submitted_at"] as? Timestamp)?.dateValue() ?? Date()
    }
}
