import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseMessaging
import Combine
import AVFoundation
import UserNotifications

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var pushNotificationManager = PushNotificationManager.shared

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // ── Always first ──────────────────────────────────────────
        FirebaseApp.configure()

        // ── Analytics ─────────────────────────────────────────────
        let POSTHOG_API_KEY = "phc_CJVEsIrEFGVZez7JKBE2g5F0jGUDuNZkRC8e7Nx7VAK"
        let POSTHOG_HOST    = "https://eu.i.posthog.com"
        let analyticsService = PostHogAnalyticsService(apiKey: POSTHOG_API_KEY, host: POSTHOG_HOST)
        Analytics.shared.configure(with: analyticsService)

        // ── VoIP / CallKit ────────────────────────────────────────
        // Must be called before any UI loads — PushKit can fire
        // didReceiveIncomingPush even when the app is fully killed.
        VoIPPushManager.shared.start()
        VoIPPushManager.shared.onAcceptCall = { callInfo in
            NavigationCoordinator.shared.openStream(
                streamId:     callInfo.streamId,
                streamerId:   callInfo.streamerId,
                streamerName: callInfo.streamerName
            )
        }

        // ── VoIP token watcher ────────────────────────────────────
        // Three-layer reliability system for keeping voipToken accurate:
        //   1. Real-time Firestore listener detects missing or stale tokens.
        //   2. Foreground-resume sync catches rotations that happened while
        //      the app was suspended.
        //   3. Retry logic in persistToken handles transient write failures.
        // All three layers are self-managing after this single start() call.
        VoIPTokenWatcher.shared.start()

        // ── Regular FCM push setup ────────────────────────────────
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .authorized && Auth.auth().currentUser != nil {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    if let userId = Auth.auth().currentUser?.uid {
                        self.pushNotificationManager.queueTokenUpdate(userId: userId)
                    }
                }
            }
        }

        pushNotificationManager.setup()
        pushNotificationManager.processAnyPendingTokens()

        UNUserNotificationCenter.current().delegate = self

        // ── Clear badge on foreground ─────────────────────────────
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearNotifications),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        // ── VoIP token: clear on sign-out ─────────────────────────
        // VoIPTokenWatcher owns sign-in recovery (missing/stale detection
        // and foreground syncs). This observer handles only the sign-out
        // case — clearing the token so a logged-out device is never rung.
        NotificationCenter.default.addObserver(
            forName: .AuthStateDidChange,
            object:  nil,
            queue:   .main
        ) { _ in
            if Auth.auth().currentUser == nil {
                VoIPPushManager.shared.clearToken()
            }
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        pushNotificationManager.handleDeviceToken(deviceToken)
        guard let userId = Auth.auth().currentUser?.uid else {
            print("[PushDebug] Device token received but no current user")
            return
        }
        print("[PushDebug] Device token received for user: \(userId)")
        pushNotificationManager.queueTokenUpdate(userId: userId)
    }

    @objc private func clearNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        completionHandler(.newData)
    }
}

// MARK: - PingbearApp

@main
struct PingbearApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var coordinator = NavigationCoordinator.shared

    @State private var isLoggedIn: Bool = UserDefaults.standard.bool(forKey: "isLoggedIn")
    @State private var pendingLoginDeepLink: URL?
    @State private var selectedTab: Int = 0

    let didLogOut = PassthroughSubject<Void, Never>()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLoggedIn && Auth.auth().currentUser != nil {
                    NavigationStack {
                        MainTabView(selectedTab: $selectedTab)
                            .navigationBarHidden(true)
                    }
                    .onAppear { setupApp() }
                    .environment(\.didLogOut, didLogOut)
                    .environmentObject(coordinator)
                    .onReceive(didLogOut) { _ in isLoggedIn = false }

                } else {
                    NavigationView {
                        WelcomeView()
                            .onAppear { setupApp() }
                            .environment(\.didLogOut, didLogOut)
                            .onReceive(didLogOut) { _ in isLoggedIn = false }
                    }
                    .accentColor(.white)
                }
            }
            .background(AppTheme.pageBackground)
            .onReceive(NotificationCenter.default.publisher(for: .authStateDidChange)) { _ in
                isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
            }
        }
    }

    private func setupApp() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            window.overrideUserInterfaceStyle = .light
        }
    }
}

// MARK: - NavigationCoordinator

final class NavigationCoordinator: ObservableObject {

    static let shared = NavigationCoordinator()

    @Published var pendingVoIPStream: VoIPStreamTarget? = nil

    private init() {}

    func openStream(streamId: String, streamerId: String, streamerName: String) {
        DispatchQueue.main.async {
            self.pendingVoIPStream = VoIPStreamTarget(
                streamId:     streamId,
                streamerId:   streamerId,
                streamerName: streamerName
            )
        }
    }
}

// MARK: - VoIPStreamTarget

struct VoIPStreamTarget: Identifiable, Equatable {
    var id:           String { streamId }
    let streamId:     String
    let streamerId:   String
    let streamerName: String
}
