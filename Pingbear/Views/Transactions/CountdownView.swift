import SwiftUI
import CoreHaptics

// ─────────────────────────────────────────────────────────────
// MARK: - CountdownView
// Full-screen 3-2-1 countdown shown after the payer unlocks an
// offer. Drives escalating haptic punches on each beat, then
// calls onComplete so OfferDetailView can swap in the video.
// ─────────────────────────────────────────────────────────────

struct CountdownView: View {

    let onComplete: () -> Void

    @State private var count:     Int             = 3
    @State private var scale:     CGFloat         = 1.0
    @State private var opacity:   Double          = 1.0
    @State private var engine:    CHHapticEngine? = nil
    @State private var countTask: DispatchWorkItem? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Text("\(count)")
                .font(.system(size: 160, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            startEngine()
            runCountdown()
        }
        .onDisappear {
            countTask?.cancel()
            countTask = nil
            engine?.stop()
            engine = nil
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Countdown logic
    // ─────────────────────────────────────────────────────────

    private func runCountdown() {
        fireCountBeat()
    }

    private func fireCountBeat() {
        scale   = 1.4
        opacity = 1.0

        withAnimation(.easeOut(duration: 0.35)) {
            scale = 1.0
        }
        withAnimation(.easeIn(duration: 0.25).delay(0.65)) {
            opacity = 0.0
        }

        firePunch(count: count)

        let task = DispatchWorkItem {
            if count > 1 {
                count -= 1
                scale   = 1.4
                opacity = 1.0
                fireCountBeat()
            } else {
                engine?.stop()
                engine = nil
                onComplete()
            }
        }
        countTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: task)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Haptics
    // ─────────────────────────────────────────────────────────

    private func startEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            engine?.isAutoShutdownEnabled = false
            try engine?.start()
        } catch {
            print("[CountdownView] Haptic engine failed: \(error)")
        }
    }

    private func firePunch(count: Int) {
        guard let engine, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            let events: [CHHapticEvent]

            switch count {
            case 3:
                events = [
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
                    ], relativeTime: 0),
                    CHHapticEvent(eventType: .hapticContinuous, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
                    ], relativeTime: 0, duration: 0.2),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
                    ], relativeTime: 0.15),
                ]

            case 2:
                events = [
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8),
                    ], relativeTime: 0),
                    CHHapticEvent(eventType: .hapticContinuous, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.0),
                    ], relativeTime: 0, duration: 0.35),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9),
                    ], relativeTime: 0.2),
                ]

            default: // 1 — biggest punch
                events = [
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
                    ], relativeTime: 0),
                    CHHapticEvent(eventType: .hapticContinuous, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1),
                    ], relativeTime: 0, duration: 0.5),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
                    ], relativeTime: 0.18),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
                    ], relativeTime: 0.32),
                ]
            }

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player  = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[CountdownView] Haptic pattern failed: \(error)")
        }
    }
}
