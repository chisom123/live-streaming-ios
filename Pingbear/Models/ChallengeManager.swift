import Foundation
import FirebaseFirestore
import FirebaseAuth

// ─────────────────────────────────────────────────────────────
// MARK: - Challenge Trigger
//
// Add new cases here as new challenge types are introduced.
// Each case maps to a completionTrigger string stored on
// the challenge_templates document in Firestore.
// ─────────────────────────────────────────────────────────────

enum ChallengeTrigger: String {
    case raceWon = "race_won"
    // Add more triggers here as challenge types expand
}

// ─────────────────────────────────────────────────────────────
// MARK: - Challenge Model
// ─────────────────────────────────────────────────────────────

struct UserChallenge {
    let userId: String
    let templateId: String
    let title: String
    let description: String
    let completionTrigger: String
    let targetValue: Double
    var currentValue: Double
    var status: String
    let acceptedAt: Date?
    let completedAt: Date?
    let createdAt: Date?

    var isActive: Bool {
        status == "accepted"
    }

    var isCompleted: Bool {
        status == "completed"
    }

    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(1.0, currentValue / targetValue)
    }

    // Formatted progress for display e.g. "$1.50 / $2.00"
    var progressText: String {
        "$\(String(format: "%.2f", currentValue)) / $\(String(format: "%.2f", targetValue))"
    }

    init?(from data: [String: Any]) {
        guard
            let userId           = data["userId"]            as? String,
            let templateId       = data["templateId"]        as? String,
            let title            = data["title"]             as? String,
            let description      = data["description"]       as? String,
            let trigger          = data["completionTrigger"] as? String,
            let status           = data["status"]            as? String
        else { return nil }

        self.userId            = userId
        self.templateId        = templateId
        self.title             = title
        self.description       = description
        self.completionTrigger = trigger
        self.status            = status

        // targetValue and currentValue are dollar amounts stored as numbers
        self.targetValue  = data["targetValue"]  as? Double ?? Double(data["targetValue"]  as? Int ?? 0)
        self.currentValue = data["currentValue"] as? Double ?? Double(data["currentValue"] as? Int ?? 0)

        self.acceptedAt  = (data["acceptedAt"]  as? Timestamp)?.dateValue()
        self.completedAt = (data["completedAt"] as? Timestamp)?.dateValue()
        self.createdAt   = (data["createdAt"]   as? Timestamp)?.dateValue()
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - ChallengeManager
// ─────────────────────────────────────────────────────────────

class ChallengeManager {
    static let shared = ChallengeManager()
    private let db = Firestore.firestore()

    // In-memory cache so handleEvent doesn't need a Firestore
    // read on every race win check
    private var cachedChallenge: UserChallenge?
    private var isCacheLoaded = false

    private init() {}

    // ─────────────────────────────────────────────────────────
    // MARK: - Load Active Challenge
    //
    // Call from MyCompsView.onAppear to populate the banner.
    // Caches the result so subsequent handleEvent calls are cheap.
    // ─────────────────────────────────────────────────────────

    func loadActiveChallenge(completion: @escaping (UserChallenge?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }

        db.collection("user_challenges").document(userId).getDocument { [weak self] document, error in
            guard let self = self else { return }

            if let error = error {
                print("ChallengeManager: Error loading challenge: \(error)")
                completion(nil)
                return
            }

            guard let data = document?.data(),
                  let challenge = UserChallenge(from: data) else {
                self.cachedChallenge = nil
                self.isCacheLoaded = true
                completion(nil)
                return
            }

            guard challenge.isActive else {
                self.cachedChallenge = nil
                self.isCacheLoaded = true
                completion(nil)
                return
            }

            self.cachedChallenge = challenge
            self.isCacheLoaded = true
            completion(challenge)
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Handle Race Win
    //
    // Called from closeRaces (server-side) via the challenge
    // completion logic there. This Swift method is called
    // from the app when we want to refresh the challenge state
    // after a race closes — e.g. on MyCompsView appear or
    // after receiving a push notification that a race ended.
    //
    // The actual completion logic lives server-side in
    // closeRaces which has access to totalWinnings and can
    // atomically update both the user doc and user_challenges.
    // ─────────────────────────────────────────────────────────

    func refreshChallengeState() {
        // Clear cache so next loadActiveChallenge gets fresh data
        cachedChallenge = nil
        isCacheLoaded = false
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Clear Cache
    //
    // Call on sign out so a different user doesn't see
    // stale challenge data.
    // ─────────────────────────────────────────────────────────

    func clearCache() {
        cachedChallenge = nil
        isCacheLoaded = false
    }
}
