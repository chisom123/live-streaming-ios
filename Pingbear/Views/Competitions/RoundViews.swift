import SwiftUI
import FirebaseAuth
import CoreHaptics

// ─────────────────────────────────────────────────────────────
// MARK: - RoundResultsView
//
// Shown when a round completes. Receives data directly --
// no ViewModel dependency, no Firestore reads.
// Driven by RoundFlowStep.results in SessionViewModel.
//
// isCreatingRound: while true, the Play Again button shows a
// spinner and the view stays visible. Only dismisses to lobby
// once the new round is confirmed ready -- no stale state flash.
// ─────────────────────────────────────────────────────────────

struct RoundResultsView: View {

    let round: Round
    let submissions: [Submission]
    let userProfiles: [String: UserProfile]
    let isCreatingRound: Bool
    let onPlayAgain: () -> Void
    let onDismiss: () -> Void

    private let currentUserId = Auth.auth().currentUser?.uid ?? ""

    private var sortedSubmissions: [Submission] {
        submissions.sorted { ($0.aiScore ?? 0) > ($1.aiScore ?? 0) }
    }

    private var winners: [Submission] {
        guard let topScore = sortedSubmissions.first?.aiScore else { return [] }
        return sortedSubmissions.filter { $0.aiScore == topScore }
    }

    private var isTie: Bool { winners.count > 1 }

    private var currentUserIsWinner: Bool {
        round.winnerIds.contains(currentUserId)
    }

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                winnerBanner

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(sortedSubmissions.enumerated()), id: \.element.id) { index, submission in
                            VStack(spacing: 0) {
                                resultCard(submission: submission, rank: index + 1)
                                if index < sortedSubmissions.count - 1 {
                                    Divider()
                                        .background(AppTheme.divider)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Play Again button -- spinner while new round is being created
                Button(action: {
                    if !isCreatingRound { onPlayAgain() }
                }) {
                    HStack(spacing: 8) {
                        if isCreatingRound {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.85)
                            Text("Setting up next round...")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("Continue")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, 8)
                    .background(isCreatingRound ? AppTheme.disabledBackground : AppTheme.accent)
                    .cornerRadius(200)
                }
                .disabled(isCreatingRound)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .animation(.easeInOut(duration: 0.2), value: isCreatingRound)
            }
            .padding(.top, 24)
        }
        .navigationBarHidden(true)
        .onAppear {
            Analytics.shared.trackScreen(
                name: "round_results",
                properties: [
                    "is_winner":         currentUserIsWinner,
                    "is_tie":            isTie,
                    "participant_count": submissions.count,
                    "round_reward":      round.roundReward
                ]
            )
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Winner Banner
    // ─────────────────────────────────────────────────────────

    private var winnerBanner: some View {
        VStack(spacing: 15) {

            if currentUserIsWinner {
                Text(isTie ? "You tied for the win!" : "You won!")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(AppTheme.primaryText)
            } else {
                let winnerName = winners.first.flatMap { userProfiles[$0.userId]?.name } ?? "Someone"
                Text(isTie ? "It's a tie!" : "\(winnerName) wins!")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(AppTheme.primaryText)
            }

            if round.roundReward > 0 {
                Text("+$\(String(format: "%.2f", round.roundReward / Double(winners.count)))")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.green)
                    .cornerRadius(200)
            }

            if round.roundReward > 0 {
                Text("Platform fee (10%)")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Result Card
    // ─────────────────────────────────────────────────────────

    private func resultCard(submission: Submission, rank: Int) -> some View {
        let profile  = userProfiles[submission.userId]
        let isWinner = round.winnerIds.contains(submission.userId)
        let score    = submission.aiScore ?? 0.0

        return HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(isWinner ? AppTheme.gold : AppTheme.secondaryText)
                .frame(width: 24)

            HStack(spacing: 12) {
                AsyncImage(url: URL(string: submission.photoUrl)) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(AppTheme.pageBackground)
                            .overlay(ProgressView())
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Rectangle()
                            .fill(AppTheme.pageBackground)
                            .overlay(Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(AppTheme.secondaryText))
                    @unknown default:
                        Rectangle().fill(AppTheme.pageBackground)
                    }
                }
                .frame(width: 80, height: 100)
                .clipped()
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 6) {
                    Text(profile?.name ?? "...")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)

                    if let reason = submission.aiReason {
                        Text(reason)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                Text(String(format: "%.1f", score))
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(isWinner ? AppTheme.gold : AppTheme.primaryText)
                    .frame(width: 48)
            }
            .padding(14)
        }
    }
}

// RoundJudgingView

struct RoundJudgingView: View {

    private let colors: [Color] = [
        Color(hex: "#FF6B6B"),
        Color(hex: "#FFD93D"),
        Color(hex: "#6BCB77"),
        Color(hex: "#4D96FF"),
        Color(hex: "#FF922B"),
        Color(hex: "#CC5DE8"),
    ]

    @State private var colorIndex: Int          = 0
    @State private var rotation: Double         = 0
    @State private var currentBeatTask: DispatchWorkItem? = nil
    @State private var engine: CHHapticEngine?  = nil

    var body: some View {
        ZStack {
            colors[colorIndex]
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: colorIndex)

            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(.white.opacity(0.6), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 64, height: 64)
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "round_judging")
            startEngine()
            startCycling()
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
        .onDisappear {
            currentBeatTask?.cancel()
            currentBeatTask = nil
            engine?.stop()
            engine = nil
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Engine
    // ─────────────────────────────────────────────────────────

    private func startEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            engine?.isAutoShutdownEnabled = false
            try engine?.start()
        } catch {
            print("[RoundJudgingView] Haptic engine failed: \(error)")
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Cycling
    // ─────────────────────────────────────────────────────────

    private func startCycling() {
        fireNextBeat()
    }

    private func fireNextBeat() {
        colorIndex = (colorIndex + 1) % colors.count

        firePunch(pattern: beatPattern(for: colorIndex))

        // Rapid double hit every 4th beat
        if colorIndex % 4 == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                firePunch(pattern: .light)
            }
        }

        // Rapid triple hit every 7th beat
        if colorIndex % 7 == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { firePunch(pattern: .light) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { firePunch(pattern: .light) }
        }

        let interval = Double.random(in: 0.5...1.1)
        let task = DispatchWorkItem { fireNextBeat() }
        currentBeatTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: task)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Patterns
    // ─────────────────────────────────────────────────────────

    private enum BeatPattern { case punch, thud, sharp, rumble, light }

    private func beatPattern(for index: Int) -> BeatPattern {
        switch index % 5 {
        case 0: return .punch
        case 1: return .thud
        case 2: return .sharp
        case 3: return .rumble
        case 4: return .light
        default: return .punch
        }
    }

    private func firePunch(pattern: BeatPattern = .punch) {
        guard let engine, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            let events: [CHHapticEvent]

            switch pattern {
            case .punch:
                events = [
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
                    ], relativeTime: 0),
                    CHHapticEvent(eventType: .hapticContinuous, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
                    ], relativeTime: 0, duration: 0.15),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8),
                    ], relativeTime: 0.12),
                ]

            case .thud:
                events = [
                    CHHapticEvent(eventType: .hapticContinuous, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.0),
                    ], relativeTime: 0, duration: 0.3),
                ]

            case .sharp:
                events = [
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
                    ], relativeTime: 0),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
                    ], relativeTime: 0.08),
                ]

            case .rumble:
                events = [
                    CHHapticEvent(eventType: .hapticContinuous, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1),
                    ], relativeTime: 0, duration: 0.4),
                ]

            case .light:
                events = [
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8),
                    ], relativeTime: 0),
                ]
            }

            let hapticPattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: hapticPattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[RoundJudgingView] Haptic pattern failed: \(error)")
        }
    }
}
