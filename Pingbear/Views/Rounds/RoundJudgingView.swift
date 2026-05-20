import SwiftUI
import FirebaseAuth

// ─────────────────────────────────────────────────────────────
// MARK: - RoundJudgingView
//
// Full-screen atmosphere screen between lobby and results.
// Background is AppTheme.accent (terracotta). Three expanding
// rings radiate from a white pulsing core — like a sonar ping —
// building anticipation while Gemini scores in the background.
//
// Once completedSubmissions are populated by the ViewModel,
// a short hold plays out then results slide up automatically.
// ─────────────────────────────────────────────────────────────

struct RoundJudgingView: View {

    @ObservedObject var roundViewModel: RoundViewModel
    let competition: Competition

    @State private var hasStartedReveal: Bool = false

    // Ring animation phases — each ring starts at the same
    // size and expands outward, staggered by 1/3 of the period
    @State private var ringScale1: CGFloat = 0.5
    @State private var ringScale2: CGFloat = 0.5
    @State private var ringScale3: CGFloat = 0.5
    @State private var ringOpacity1: Double = 0.7
    @State private var ringOpacity2: Double = 0.7
    @State private var ringOpacity3: Double = 0.7

    // Core pulse
    @State private var coreScale: CGFloat = 1.0
    @State private var coreGlowScale: CGFloat = 1.0

    // Text fade-in
    @State private var contentOpacity: Double = 0.0

    // Animated dots
    @State private var dotPhase: Int = 0
    private let dotTimer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    private let ringDuration: Double = 2.8
    private let ringSize:     CGFloat = 160

    var body: some View {
        ZStack {
            // ── Full-screen accent background ──────────────────
            AppTheme.accent.ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer()

                // ── Sonar animation ───────────────────────────
                ZStack {
                    // Ring 1
                    Circle()
                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        .frame(width: ringSize, height: ringSize)
                        .scaleEffect(ringScale1)
                        .opacity(ringOpacity1)

                    // Ring 2
                    Circle()
                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        .frame(width: ringSize, height: ringSize)
                        .scaleEffect(ringScale2)
                        .opacity(ringOpacity2)

                    // Ring 3
                    Circle()
                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        .frame(width: ringSize, height: ringSize)
                        .scaleEffect(ringScale3)
                        .opacity(ringOpacity3)

                    // Glow halo behind core
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 76, height: 76)
                        .scaleEffect(coreGlowScale)

                    // Core
                    Circle()
                        .fill(.white.opacity(0.95))
                        .frame(width: 56, height: 56)
                        .scaleEffect(coreScale)
                }
                .frame(width: 300, height: 300)

                // ── Label ─────────────────────────────────────
                VStack(spacing: 10) {
                    Text("AI is judging")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    Text(roundViewModel.roundInfo?.themeName
                         ?? roundViewModel.completedRoundInfo?.themeName
                         ?? "")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))

                    // Three bouncing dots
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(.white.opacity(dotPhase == i ? 1.0 : 0.25))
                                .frame(width: 5, height: 5)
                                .scaleEffect(dotPhase == i ? 1.3 : 0.8)
                                .animation(.easeInOut(duration: 0.2), value: dotPhase)
                        }
                    }
                    .padding(.top, 4)
                }
                .opacity(contentOpacity)
                .padding(.top, 32)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(
                name: "round_judging",
                properties: [
                    AnalyticsProperty.competitionId: competition.id,
                    "theme_name": roundViewModel.roundInfo?.themeName
                        ?? roundViewModel.completedRoundInfo?.themeName
                        ?? ""
                ]
            )
            startAnimations()
            // Handle case where scores already arrived before view appeared
            if roundViewModel.completedSubmissions.count > 0 && !hasStartedReveal {
                transitionToResults()
            }
        }
        .onReceive(dotTimer) { _ in
            dotPhase = (dotPhase + 1) % 3
        }
        // ── Scores ready — transition to results ──────────────
        .onChange(of: roundViewModel.completedSubmissions.count) { count in
            if count > 0 && !hasStartedReveal {
                transitionToResults()
            }
        }
        // ── Results cover ─────────────────────────────────────
        .fullScreenCover(isPresented: Binding(
            get: { roundViewModel.showResults },
            set: { _ in }
        )) {
            resultsView
        }
        // ── Play Again: dismiss results when new round arrives
        .onChange(of: roundViewModel.roundInfo?.roundId) { newRoundId in
            if newRoundId != nil && roundViewModel.showResults {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    roundViewModel.dismissResults()
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Animations
    // ─────────────────────────────────────────────────────────────

    private func startAnimations() {
        // Fade content in
        withAnimation(.easeIn(duration: 0.5)) {
            contentOpacity = 1.0
        }

        // Core breathes
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            coreScale = 1.1
        }
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.3)) {
            coreGlowScale = 1.2
        }

        // Rings expand outward, evenly staggered across the period
        animateRing(
            delay: 0,
            scale: Binding(get: { ringScale1 }, set: { ringScale1 = $0 }),
            opacity: Binding(get: { ringOpacity1 }, set: { ringOpacity1 = $0 })
        )
        animateRing(
            delay: ringDuration / 3,
            scale: Binding(get: { ringScale2 }, set: { ringScale2 = $0 }),
            opacity: Binding(get: { ringOpacity2 }, set: { ringOpacity2 = $0 })
        )
        animateRing(
            delay: (ringDuration / 3) * 2,
            scale: Binding(get: { ringScale3 }, set: { ringScale3 = $0 }),
            opacity: Binding(get: { ringOpacity3 }, set: { ringOpacity3 = $0 })
        )
    }

    private func animateRing(delay: Double, scale: Binding<CGFloat>, opacity: Binding<Double>) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: ringDuration).repeatForever(autoreverses: false)) {
                scale.wrappedValue   = 2.2
                opacity.wrappedValue = 0.0
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Transition to Results
    //
    // Short hold lets the animation breathe before results slide up.
    // ─────────────────────────────────────────────────────────────

    private func transitionToResults() {
        guard !hasStartedReveal else { return }
        hasStartedReveal = true

        Analytics.shared.track(
            event: "judging_results_reveal",
            properties: [
                AnalyticsProperty.competitionId: competition.id,
                "submission_count": roundViewModel.completedSubmissions.count
            ]
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            roundViewModel.isRevealingScores = false
            roundViewModel.showResults       = true
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Results View
    // ─────────────────────────────────────────────────────────────

    @ViewBuilder
    private var resultsView: some View {
        if let roundInfo = roundViewModel.completedRoundInfo {
            RoundResultsView(
                roundInfo:      roundInfo,
                submissions:    roundViewModel.completedSubmissions,
                userProfiles:   roundViewModel.completedUserProfiles,
                isPlayingAgain: roundViewModel.isAwaitingNextRound,
                onPlayAgain: {
                    let themeId   = roundViewModel.lastThemeId
                    let themeName = roundViewModel.lastThemeName
                    roundViewModel.resetForNextRound()
                    if let themeName {
                        roundViewModel.createRound(themeId: themeId, themeName: themeName) { _ in }
                    }
                },
                onDismiss: {
                    roundViewModel.dismissRoundCover()
                    roundViewModel.dismissResults()
                    roundViewModel.justCompletedRound = false
                }
            )
        } else {
            Color.clear
        }
    }
}
