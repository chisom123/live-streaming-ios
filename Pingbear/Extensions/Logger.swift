import Foundation

// ─────────────────────────────────────────────────────────────
// MARK: - AppLogger
//
// Consistent prefixed logging across the entire call/session flow.
// Each prefix groups related events so you can grep or scan
// the console to trace exactly what happened and in what order.
//
// Prefixes:
//   [CALL]    — outgoing call flow (caller side)
//   [RING]    — incoming call flow (callee side)
//   [LIVEKIT] — LiveKit room connection
//   [AUDIO]   — audio engine / CallKit audio session
//   [SESSION] — session document and participant management
//   [ROUND]   — round lifecycle (create, join, start, results)
//   [UPLOAD]  — photo upload
//   [NAV]     — view navigation / state transitions
// ─────────────────────────────────────────────────────────────

enum AppLogger {
    static func call(_ message: String)    { print("[CALL]    \(message)") }
    static func ring(_ message: String)    { print("[RING]    \(message)") }
    static func livekit(_ message: String) { print("[LIVEKIT] \(message)") }
    static func audio(_ message: String)   { print("[AUDIO]   \(message)") }
    static func session(_ message: String) { print("[SESSION] \(message)") }
    static func round(_ message: String)   { print("[ROUND]   \(message)") }
    static func upload(_ message: String)  { print("[UPLOAD]  \(message)") }
    static func nav(_ message: String)     { print("[NAV]     \(message)") }
}
