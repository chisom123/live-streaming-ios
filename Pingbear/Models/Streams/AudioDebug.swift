import Foundation
import UIKit
import AVFAudio

// MARK: - AudioDebug
//
// Drop-in audio session tracer. Logs, with millisecond timestamps:
//
//   • Audio session interruptions (began / ended, and whether iOS says
//     playback should resume) — the prime suspect for "audio randomly
//     stops mid-stream".
//   • Route changes (speaker ↔ receiver ↔ bluetooth) with the reason.
//   • Media services reset (rare, but kills all audio until restart).
//   • App lifecycle (didBecomeActive / willResignActive / background /
//     foreground) — needed to see the ordering vs. LiveKit connect and
//     the CallKit call end on locked-device cold launches.
//   • Protected data availability — a proxy for "was the device still
//     locked at this point".
//
// Reading the output: every line is prefixed [AudioDebug HH:mm:ss.SSS]
// so you can reconstruct the exact ordering of CallKit events, app
// lifecycle, LiveKit connection, and session state changes.

final class AudioDebug {

    static let shared = AudioDebug()
    private init() {}

    private var started = false
    private var observers: [NSObjectProtocol] = []

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    // MARK: - Logging primitives

    static func log(_ tag: String, _ message: String = "") {
        print("[AudioDebug \(timeFormatter.string(from: Date()))] \(tag)\(message.isEmpty ? "" : " — \(message)")")
    }

    /// Dumps the full current audio session + app state under a tag.
    /// Call this at any point of interest.
    static func dump(_ tag: String) {
        let s = AVAudioSession.sharedInstance()

        let route = s.currentRoute.outputs
            .map { "\($0.portType.rawValue)(\($0.portName))" }
            .joined(separator: ", ")

        var appState = "n/a (not main thread)"
        var protectedData = "n/a"
        if Thread.isMainThread {
            switch UIApplication.shared.applicationState {
            case .active:     appState = "active"
            case .inactive:   appState = "inactive"
            case .background: appState = "background"
            @unknown default: appState = "unknown"
            }
            protectedData = UIApplication.shared.isProtectedDataAvailable
                ? "available (unlocked)"
                : "UNAVAILABLE (locked)"
        }

        log(tag, """

            ├─ category:          \(s.category.rawValue)
            ├─ mode:              \(s.mode.rawValue)
            ├─ options:           \(s.categoryOptions.rawValue)
            ├─ outputs:           \(route.isEmpty ? "NONE" : route)
            ├─ otherAudioPlaying: \(s.isOtherAudioPlaying)
            ├─ outputVolume:      \(s.outputVolume)
            ├─ appState:          \(appState)
            └─ protectedData:     \(protectedData)
            """)
    }

    // MARK: - Start observing

    func start() {
        guard !started else { return }
        started = true
        Self.log("start()", "audio tracing enabled")

        let nc = NotificationCenter.default

        // ── Interruptions — the prime suspect ─────────────────────
        observers.append(nc.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object:  nil, queue: .main
        ) { note in
            guard let info = note.userInfo,
                  let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeRaw)
            else {
                Self.log("⚡️ INTERRUPTION", "malformed userInfo")
                return
            }

            switch type {
            case .began:
                var reason = ""
                if #available(iOS 14.5, *),
                   let rRaw = info[AVAudioSessionInterruptionReasonKey] as? UInt,
                   let r = AVAudioSession.InterruptionReason(rawValue: rRaw) {
                    reason = " reason=\(r.rawValue)"
                }
                Self.log("⚡️ INTERRUPTION BEGAN", "something took the audio session\(reason)")
                Self.dump("state at interruption-began")

            case .ended:
                let optsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let shouldResume = AVAudioSession.InterruptionOptions(rawValue: optsRaw)
                    .contains(.shouldResume)
                Self.log("⚡️ INTERRUPTION ENDED", "shouldResume=\(shouldResume) — if audio is dead after this line, nothing resumed the session")
                Self.dump("state at interruption-ended")

            @unknown default:
                Self.log("⚡️ INTERRUPTION", "unknown type \(typeRaw)")
            }
        })

        // ── Route changes ─────────────────────────────────────────
        observers.append(nc.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object:  nil, queue: .main
        ) { note in
            let reasonRaw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw)
            let reasonName: String
            switch reason {
            case .newDeviceAvailable:            reasonName = "newDeviceAvailable"
            case .oldDeviceUnavailable:          reasonName = "oldDeviceUnavailable"
            case .categoryChange:                reasonName = "categoryChange"
            case .override:                      reasonName = "override"
            case .wakeFromSleep:                 reasonName = "wakeFromSleep"
            case .noSuitableRouteForCategory:    reasonName = "noSuitableRouteForCategory"
            case .routeConfigurationChange:      reasonName = "routeConfigurationChange"
            default:                             reasonName = "unknown(\(reasonRaw))"
            }
            let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
                .map { $0.portType.rawValue }.joined(separator: ", ")
            Self.log("🔀 ROUTE CHANGE", "reason=\(reasonName) nowOutputs=[\(outputs)]")
        })

        // ── Media services reset ──────────────────────────────────
        observers.append(nc.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object:  nil, queue: .main
        ) { _ in
            Self.log("💥 MEDIA SERVICES RESET", "all audio objects are now invalid — audio engine must be fully rebuilt")
        })

        // ── App lifecycle ─────────────────────────────────────────
        let lifecycle: [(Notification.Name, String)] = [
            (UIApplication.didBecomeActiveNotification,    "🟢 didBecomeActive"),
            (UIApplication.willResignActiveNotification,   "🟡 willResignActive"),
            (UIApplication.didEnterBackgroundNotification, "🔴 didEnterBackground"),
            (UIApplication.willEnterForegroundNotification,"🔵 willEnterForeground"),
            (UIApplication.protectedDataDidBecomeAvailableNotification, "🔓 protectedDataAvailable (device unlocked)")
        ]
        for (name, label) in lifecycle {
            observers.append(nc.addObserver(forName: name, object: nil, queue: .main) { _ in
                Self.log(label)
            })
        }
    }
}
