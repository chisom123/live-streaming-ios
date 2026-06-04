import SwiftUI
import FirebaseAuth
import FirebaseFunctions
import PhotosUI

// ─────────────────────────────────────────────────────────────
// MARK: - Demo Round Result
//
// Returned by startDemoRound Cloud Function.
// Passed between views so no re-fetching needed.
// ─────────────────────────────────────────────────────────────

struct DemoRoundResult {
    let userScore:       Double
    let botScore:        Double
    let userReason:      String
    let botReason:       String
    let userWon:         Bool
    let isTie:           Bool
    let winnings:        Double
    let winningsLocked:  Bool
    let totalPot:        Double
    let platformFee:     Double
    let roundReward:     Double
    let botName:         String
    let botPhotoUrl:     String
    let userPhotoUrl:    String

    init?(data: [String: Any]) {
        guard
            let userScore   = data["userScore"]   as? Double,
            let botScore    = data["botScore"]     as? Double,
            let userReason  = data["userReason"]   as? String,
            let botReason   = data["botReason"]    as? String,
            let userWon     = data["userWon"]      as? Bool,
            let isTie       = data["isTie"]        as? Bool,
            let winnings    = data["winnings"]     as? Double,
            let totalPot    = data["totalPot"]     as? Double,
            let platformFee = data["platformFee"]  as? Double,
            let roundReward = data["roundReward"]  as? Double,
            let botName     = data["botName"]      as? String,
            let botPhotoUrl = data["botPhotoUrl"]  as? String,
            let userPhotoUrl = data["userPhotoUrl"] as? String
        else { return nil }

        self.userScore        = userScore
        self.botScore         = botScore
        self.userReason       = userReason
        self.botReason        = botReason
        self.userWon          = userWon
        self.isTie            = isTie
        self.winnings         = winnings
        self.winningsLocked   = data["winningsLocked"] as? Bool ?? false
        self.totalPot         = totalPot
        self.platformFee      = platformFee
        self.roundReward      = roundReward
        self.botName          = botName
        self.botPhotoUrl      = botPhotoUrl
        self.userPhotoUrl     = userPhotoUrl
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Demo Flow Step
// ─────────────────────────────────────────────────────────────

enum DemoFlowStep {
    case intro
    case lobby
    case entryFee(UIImage)
    case judging(demoRoundId: String, botPhotoUrl: String, entryFee: Double)
    case results(DemoRoundResult)
    case complete
}

// ─────────────────────────────────────────────────────────────
// MARK: - DemoFlowCoordinator
//
// Owns all demo state. Injected as @StateObject into
// DemoFlowView which renders the correct screen per step.
// All Cloud Function calls live here — views are pure UI.
// ─────────────────────────────────────────────────────────────

@MainActor
final class DemoFlowCoordinator: ObservableObject {

    @Published var step: DemoFlowStep       = .intro
    @Published var isLoading                = false
    @Published var errorMessage: String?    = nil

    // Set during lobby → used when creating the demo round
    @Published var selectedImage: UIImage?  = nil
    @Published var uploadProgress: Double   = 0

    private let functions = Functions.functions()

    // ── Navigation ────────────────────────────────────────────

    func proceedFromIntro() {
        Analytics.shared.track(event: "demo_intro_continued")
        step = .lobby
    }

    func onPhotoSelected(_ image: UIImage) {
        Analytics.shared.track(event: "demo_photo_selected")
        selectedImage = image
    }

    func proceedFromLobby() {
        guard let image = selectedImage else { return }
        Analytics.shared.track(event: "demo_lobby_continued")
        step = .entryFee(image)
    }

    // ── Create Demo Round ─────────────────────────────────────
    //
    // Called when user confirms entry fee.
    // 1. Uploads photo to Storage
    // 2. Calls createDemoRound Cloud Function
    // 3. Transitions to judging

    func createDemoRound(image: UIImage, entryFee: Double) {
        guard !isLoading else { return }
        errorMessage = nil
        isLoading    = true
        uploadProgress = 0

        Analytics.shared.track(event: "demo_entry_fee_confirmed", properties: [
            "entry_fee": entryFee
        ])

        Task {
            do {
                // Upload photo — reuse the same upload manager as real rounds
                // Use a placeholder sessionId for storage path
                let photoUrl = try await RoundUploadManager.shared.upload(
                    image:      image,
                    sessionId:  "demo_\(Auth.auth().currentUser?.uid ?? "unknown")",
                    onProgress: { [weak self] progress in
                        self?.uploadProgress = progress
                    }
                )

                // Call createDemoRound
                let result = try await functions.httpsCallable("createDemoRound").call([
                    "userPhotoUrl": photoUrl,
                    "entryFee":     entryFee
                ])

                guard let data       = result.data as? [String: Any],
                      let demoRoundId = data["demoRoundId"]  as? String,
                      let botPhotoUrl = data["botPhotoUrl"]  as? String
                else {
                    throw NSError(domain: "DemoFlow", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
                }

                isLoading = false
                step = .judging(
                    demoRoundId: demoRoundId,
                    botPhotoUrl: botPhotoUrl,
                    entryFee:    entryFee
                )

                Analytics.shared.track(event: "demo_round_created", properties: [
                    "demo_round_id": demoRoundId,
                    "entry_fee":     entryFee
                ])

            } catch {
                isLoading      = false
                errorMessage   = error.localizedDescription
                uploadProgress = 0
                Analytics.shared.track(event: "demo_round_create_failed", properties: [
                    "error": error.localizedDescription
                ])
            }
        }
    }

    // ── Start Demo Round ──────────────────────────────────────
    //
    // Called by DemoJudgingView after the animation has run.
    // Fetches scores and result from Cloud Function.

    func startDemoRound(demoRoundId: String) {
        Analytics.shared.track(event: "demo_judging_started", properties: [
            "demo_round_id": demoRoundId
        ])

        Task {
            do {
                let result = try await functions.httpsCallable("startDemoRound").call([
                    "demoRoundId": demoRoundId
                ])

                guard
                    let data         = result.data as? [String: Any],
                    let demoResult   = DemoRoundResult(data: data)
                else {
                    throw NSError(domain: "DemoFlow", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid result from server"])
                }

                step = .results(demoResult)

                Analytics.shared.track(event: "demo_round_completed", properties: [
                    "demo_round_id": demoRoundId,
                    "user_won":      demoResult.userWon,
                    "is_tie":        demoResult.isTie,
                    "user_score":    demoResult.userScore,
                    "bot_score":     demoResult.botScore,
                    "winnings":      demoResult.winnings,
                    "entry_fee":     demoResult.totalPot / 2
                ])

            } catch {
                // On failure show results with fallback — don't strand user on judging screen
                Analytics.shared.track(event: "demo_round_start_failed", properties: [
                    "demo_round_id": demoRoundId,
                    "error":         error.localizedDescription
                ])
                // Surface error on judging screen briefly then allow retry
                errorMessage = error.localizedDescription
            }
        }
    }

    // ── Complete ──────────────────────────────────────────────

    func proceedFromResults() {
        Analytics.shared.track(event: "demo_results_continued")
        step = .complete
    }

    func completeDemo() {
        Analytics.shared.track(event: "demo_flow_completed")
        step = .complete
    }

    // ── Go to home ────────────────────────────────────────────

    func goToHome() {
        Analytics.shared.track(event: "demo_go_to_home")
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        UserDefaults.standard.set(true, forKey: "isFriendActivated")
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .authStateDidChange, object: nil)
    }
}


// ─────────────────────────────────────────────────────────────
// MARK: - DemoFlowView
//
// Root view. Renders correct screen based on coordinator step.
// Injected as a fullScreenCover from WelcomeBonusView.
// ─────────────────────────────────────────────────────────────

struct DemoFlowView: View {

    @StateObject private var coordinator = DemoFlowCoordinator()

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            switch coordinator.step {
            case .intro:
                DemoIntroView(coordinator: coordinator)
                    .transition(.opacity)

            case .lobby:
                DemoLobbyView(coordinator: coordinator)
                    .transition(.opacity)

            case .entryFee(let image):
                DemoEntryFeeView(coordinator: coordinator, image: image)
                    .transition(.move(edge: .bottom))

            case .judging(let demoRoundId, let botPhotoUrl, let entryFee):
                DemoJudgingView(
                    coordinator:  coordinator,
                    demoRoundId:  demoRoundId,
                    botPhotoUrl:  botPhotoUrl,
                    entryFee:     entryFee
                )
                .transition(.opacity)
                .ignoresSafeArea()

            case .results(let result):
                DemoResultsView(coordinator: coordinator, result: result)
                    .transition(.opacity)

            case .complete:
                DemoCompleteView(coordinator: coordinator)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: stepKey)
    }

    private var stepKey: String {
        switch coordinator.step {
        case .intro:    return "intro"
        case .lobby:    return "lobby"
        case .entryFee: return "entryFee"
        case .judging:  return "judging"
        case .results:  return "results"
        case .complete: return "complete"
        }
    }
}
