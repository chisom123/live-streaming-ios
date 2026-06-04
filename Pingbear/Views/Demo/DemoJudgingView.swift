import SwiftUI
import CoreHaptics

struct DemoJudgingView: View {

    @ObservedObject var coordinator: DemoFlowCoordinator
    let demoRoundId: String
    let botPhotoUrl: String
    let entryFee:    Double

    private let colors: [Color] = [
        Color(hex: "#FF6B6B"),
        Color(hex: "#FFD93D"),
        Color(hex: "#6BCB77"),
        Color(hex: "#4D96FF"),
        Color(hex: "#FF922B"),
        Color(hex: "#CC5DE8"),
    ]

    @State private var colorIndex:       Int    = 0
    @State private var rotation:         Double = 0
    @State private var currentBeatTask:  DispatchWorkItem? = nil
    @State private var engine:           CHHapticEngine?   = nil
    @State private var hasStarted                          = false

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

            // ── Error overlay ──────────────────────────────────
            if let error = coordinator.errorMessage {
                VStack(spacing: 16) {
                    Spacer()
                    VStack(spacing: 12) {
                        Text("Something went wrong")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button(action: {
                            coordinator.errorMessage = nil
                            Analytics.shared.trackTap(
                                elementId: "demo_judging_retry",
                                screenName: "demo_judging"
                            )
                            coordinator.startDemoRound(demoRoundId: demoRoundId)
                        }) {
                            Text("Try Again")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(200)
                        }
                    }
                    .padding(24)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(16)
                    .padding(.horizontal, 40)
                    Spacer()
                }
            }
        }
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true

            Analytics.shared.trackScreen(name: "demo_judging", properties: [
                "demo_round_id": demoRoundId,
                "entry_fee":     entryFee
            ])

            startEngine()
            startCycling()

            // Delay so parent transition finishes before repeating animation starts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }

            coordinator.startDemoRound(demoRoundId: demoRoundId)
        }
        .onDisappear {
            currentBeatTask?.cancel()
            currentBeatTask = nil
            engine?.stop()
            engine = nil
        }
    }

    // ── Haptic engine ─────────────────────────────────────────

    private func startEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            engine?.isAutoShutdownEnabled = false
            try engine?.start()
        } catch {
            print("[DemoJudgingView] Haptic engine failed: \(error)")
        }
    }

    // ── Colour cycling ────────────────────────────────────────

    private func startCycling() {
        fireNextBeat()
    }

    private func fireNextBeat() {
        colorIndex = (colorIndex + 1) % colors.count
        firePunch(pattern: beatPattern(for: colorIndex))

        if colorIndex % 4 == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                firePunch(pattern: .light)
            }
        }
        if colorIndex % 7 == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { firePunch(pattern: .light) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { firePunch(pattern: .light) }
        }

        let interval = Double.random(in: 0.5...1.1)
        let task = DispatchWorkItem { fireNextBeat() }
        currentBeatTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: task)
    }

    // ── Haptic patterns ───────────────────────────────────────

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
            print("[DemoJudgingView] Haptic pattern failed: \(error)")
        }
    }
}
