import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import UIKit

// MARK: - FCMTokenWatcher
//
// Standalone reliability layer for the FCM token, mirroring the pattern used
// by VoIPTokenWatcher but fully independent of it — no shared state, no
// shared listener, no shared file. Safe to add without touching any VoIP code.
//
//   Layer 1 — Real-time Firestore listener
//     Detects a missing or stale fcmToken by comparing the Firestore value
//     against PushNotificationManager.currentFCMToken.
//
//   Layer 2 — Foreground resume sync
//     On every foreground entry, asks FCM for the current token and queues
//     an update if it differs from what's stored locally.
//
//   Layer 3 — Auth state gating
//     Listener attaches only when signed in, detaches on sign-out.
//
// Recovery reuses PushNotificationManager.queueTokenUpdate(userId:), which
// already has retry/backoff — no new write path is introduced here.

final class FCMTokenWatcher {

    static let shared = FCMTokenWatcher()
    private init() {}

    // MARK: - Private state

    private var listener:           ListenerRegistration?
    private var authHandle:         AuthStateDidChangeListenerHandle?
    private var foregroundObserver: NSObjectProtocol?

    // MARK: - Public API

    func start() {
        print("[FCMTokenWatcher] ▶️ start() called")

        // ── Auth state ────────────────────────────────────────────
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            if let user {
                print("[FCMTokenWatcher] 🔑 Auth state: signed in as \(user.uid)")
                self.attach(userId: user.uid)
            } else {
                print("[FCMTokenWatcher] 🔑 Auth state: signed out")
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
            guard let userId = Auth.auth().currentUser?.uid else {
                print("[FCMTokenWatcher] 🔄 Foreground: no signed-in user, skipping sync")
                return
            }
            print("[FCMTokenWatcher] 🔄 Foreground: requesting current FCM token")
            Messaging.messaging().token { token, error in
                if let error {
                    print("[FCMTokenWatcher] ❌ Foreground token fetch failed: \(error.localizedDescription)")
                    // Fall back to writing whatever known token we already
                    // have rather than leaving Firestore stale until the
                    // next snapshot/foreground cycle.
                    if let knownToken = PushNotificationManager.shared.currentFCMToken
                        ?? UserDefaults.standard.string(forKey: "pendingFCMToken_\(userId)") {
                        print("[FCMTokenWatcher] 📝 Foreground: writing known token directly instead")
                        PushNotificationManager.shared.writeTokenDirectly(knownToken, uid: userId)
                    }
                    return
                }
                guard let token else { return }
                if token != PushNotificationManager.shared.currentFCMToken {
                    print("[FCMTokenWatcher] 🔄 Foreground: token differs from local — queueing update")
                }
                PushNotificationManager.shared.queueTokenUpdate(userId: userId)
            }
        }
    }

    func stop() {
        print("[FCMTokenWatcher] ⏹ stop() called")
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

        print("[FCMTokenWatcher] 📡 Attaching Firestore listener for user \(userId)")

        listener = Firestore.firestore()
            .collection("users")
            .document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    print("[FCMTokenWatcher] ❌ Snapshot error: \(error.localizedDescription)")
                    return
                }

                guard let snapshot, snapshot.exists, let data = snapshot.data() else {
                    print("[FCMTokenWatcher] ⚠️ No usable snapshot data yet")
                    return
                }

                self.handleSnapshot(data: data, userId: userId)
            }
    }

    private func detach() {
        guard listener != nil else { return }
        listener?.remove()
        listener = nil
        print("[FCMTokenWatcher] 🔌 Listener detached")
    }

    // MARK: - Token check (Layer 1)

    private func handleSnapshot(data: [String: Any], userId: String) {
        #if targetEnvironment(simulator)
        print("[FCMTokenWatcher] 🖥 Simulator detected — FCM tokens are unreliable here, skipping")
        return
        #endif

        let firestoreToken = data["fcmToken"] as? String
        let localToken      = PushNotificationManager.shared.currentFCMToken

        print("[FCMTokenWatcher] 🔍 Token check:")
        print("  • Firestore fcmToken : \(firestoreToken ?? "nil")")
        print("  • Local token        : \(localToken ?? "nil")")

        let isMissing = firestoreToken == nil || firestoreToken?.isEmpty == true
        let isStale   = localToken != nil && !isMissing && firestoreToken != localToken

        guard isMissing || isStale else {
            print("[FCMTokenWatcher] ✅ Token OK — no action needed")
            return
        }

        print("[FCMTokenWatcher] 🚨 Token \(isMissing ? "missing" : "stale") — attempting recovery")

        // ── Step 1: write a known token directly ──────────────────
        // If we already have a token in memory or stashed in UserDefaults,
        // write it straight to Firestore without going through
        // Messaging.messaging().token() — that fetch can fail with
        // "No APNS token specified" right after sign-in or background
        // resume, leaving recovery stuck even though a perfectly good
        // token already exists locally.
        let knownToken = localToken ?? UserDefaults.standard.string(forKey: "pendingFCMToken_\(userId)")

        if let knownToken {
            print("[FCMTokenWatcher] 📝 Writing known token directly for user \(userId)")
            PushNotificationManager.shared.writeTokenDirectly(knownToken, uid: userId)
        } else {
            print("[FCMTokenWatcher] ⚠️ No known token available — falling back to fresh fetch")
        }

        // ── Step 2: also trigger a fresh fetch ────────────────────
        // Belt-and-braces: ensures the token is eventually refreshed from
        // FCM directly, even if the known token above was already rotated.
        PushNotificationManager.shared.queueTokenUpdate(userId: userId)
    }
}
