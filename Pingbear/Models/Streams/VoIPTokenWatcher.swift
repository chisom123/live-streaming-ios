import FirebaseAuth
import FirebaseFirestore
import UIKit

// MARK: - VoIPTokenWatcher
//
// Provides three overlapping layers of VoIP token reliability:
//
//   Layer 1 — Real-time Firestore listener
//     Fires immediately on attach and on every remote change to the user
//     document. Detects both a missing token and a stale one (by comparing
//     the Firestore value against VoIPPushManager.currentTokenString).
//
//   Layer 2 — Foreground resume sync
//     Every time the app enters the foreground, syncTokenForCurrentUser() is
//     called unconditionally. PushKit re-delivers the current token; if it
//     matches what's already in Firestore, persistToken writes the same value
//     (harmless). If it differs, the document is healed automatically.
//
//   Layer 3 — Auth state gating
//     The listener attaches only when a user is signed in and detaches the
//     moment they sign out, so no reads or writes ever happen for anonymous
//     sessions.
//
// Recovery strategy when a missing/stale token is detected:
//   Step 1 — Write the known token directly if one is available in memory
//             or UserDefaults. This handles rapid user switches where PushKit
//             rate-limits re-delivery and never fires didUpdate pushCredentials.
//   Step 2 — Also trigger a PushKit re-delivery as a belt-and-braces fallback,
//             so the token is always eventually refreshed from the source.

final class VoIPTokenWatcher {

    static let shared = VoIPTokenWatcher()
    private init() {}

    // MARK: - Private state

    private var listener:           ListenerRegistration?
    private var authHandle:         AuthStateDidChangeListenerHandle?
    private var foregroundObserver: NSObjectProtocol?

    // MARK: - Public API

    func start() {
        print("[VoIPTokenWatcher] ▶️ start() called")

        // ── Auth state ────────────────────────────────────────────
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            if let user {
                print("[VoIPTokenWatcher] 🔑 Auth state: signed in as \(user.uid)")
                self.attach(userId: user.uid)
            } else {
                print("[VoIPTokenWatcher] 🔑 Auth state: signed out")
                self.detach()
            }
        }

        // ── Foreground resume (Layer 2) ───────────────────────────
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object:  nil,
            queue:   .main
        ) { [weak self] _ in
            guard let self else { return }
            guard Auth.auth().currentUser != nil else {
                print("[VoIPTokenWatcher] 🔄 Foreground: no signed-in user, skipping sync")
                return
            }
            print("[VoIPTokenWatcher] 🔄 Foreground: requesting token sync")
            VoIPPushManager.shared.syncTokenForCurrentUser()
        }
    }

    func stop() {
        print("[VoIPTokenWatcher] ⏹ stop() called")
        detach()

        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
            authHandle = nil
        }

        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
            foregroundObserver = nil
        }
    }

    // MARK: - Listener management

    private func attach(userId: String) {
        detach()

        print("[VoIPTokenWatcher] 📡 Attaching Firestore listener for user \(userId)")

        listener = Firestore.firestore()
            .collection("users")
            .document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    print("[VoIPTokenWatcher] ❌ Snapshot error: \(error.localizedDescription)")
                    return
                }

                guard let snapshot else {
                    print("[VoIPTokenWatcher] ⚠️ Snapshot is nil — listener fired with no data")
                    return
                }

                guard snapshot.exists else {
                    print("[VoIPTokenWatcher] ⚠️ User document does not exist yet — waiting for creation")
                    return
                }

                guard let data = snapshot.data() else {
                    print("[VoIPTokenWatcher] ⚠️ Snapshot exists but data() returned nil")
                    return
                }

                print("[VoIPTokenWatcher] 📥 Snapshot received — document has \(data.keys.count) fields")
                self.handleSnapshot(data: data)
            }
    }

    private func detach() {
        guard listener != nil else { return }
        listener?.remove()
        listener = nil
        print("[VoIPTokenWatcher] 🔌 Listener detached")
    }

    // MARK: - Token check (Layer 1)

    private func handleSnapshot(data: [String: Any]) {
        #if targetEnvironment(simulator)
        print("[VoIPTokenWatcher] 🖥 Simulator detected — skipping token sync (PushKit unavailable)")
        return
        #endif

        let firestoreToken = data["voipToken"] as? String
        let localToken     = VoIPPushManager.shared.currentTokenString

        print("[VoIPTokenWatcher] 🔍 Token check:")
        print("  • Firestore voipToken : \(firestoreToken ?? "nil")")
        print("  • Local token         : \(localToken ?? "nil")")

        let isMissing = firestoreToken == nil || firestoreToken?.isEmpty == true
        let isStale   = localToken != nil && !isMissing && firestoreToken != localToken

        guard isMissing || isStale else {
            print("[VoIPTokenWatcher] ✅ Token OK — no action needed")
            return
        }

        print("[VoIPTokenWatcher] 🚨 Token \(isMissing ? "missing" : "stale") — attempting recovery")

        // ── Step 1: write a known token directly ──────────────────
        // If we already have a token in memory or stashed in UserDefaults,
        // write it straight to Firestore without waiting for PushKit.
        // This is critical after a rapid user switch: PushKit rate-limits
        // didUpdate pushCredentials so syncTokenForCurrentUser() alone may
        // not fire in time, leaving the new user's document tokenless.
        let knownToken = localToken ?? UserDefaults.standard.string(forKey: "pendingVoIPToken")

        if let knownToken, let uid = Auth.auth().currentUser?.uid {
            print("[VoIPTokenWatcher] 📝 Writing known token directly for user \(uid)")
            VoIPPushManager.shared.persistTokenDirectly(knownToken, uid: uid)
        } else {
            print("[VoIPTokenWatcher] ⚠️ No known token available — relying on PushKit re-delivery only")
        }

        // ── Step 2: also trigger PushKit re-delivery ──────────────
        // Belt-and-braces: ensures the token is always eventually
        // refreshed from the authoritative PushKit source, even if
        // the known token above was already rotated by Apple.
        VoIPPushManager.shared.syncTokenForCurrentUser()
    }
}
