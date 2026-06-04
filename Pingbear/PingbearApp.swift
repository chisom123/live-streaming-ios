import SwiftUI
import Firebase
import FirebaseMessaging
import Combine
import AVFoundation
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    private let callKitManager = CallKitManager.shared
    var pushNotificationManager = PushNotificationManager.shared

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // ── Always first — CallKit needs Firebase immediately ─────
        FirebaseApp.configure()
        CallKitManager.shared.configure()

        // ── If launched by a VoIP push, skip all heavy setup ─────
        let launchedForVoIP = launchOptions?[.remoteNotification] != nil
        guard !launchedForVoIP else {
            print("AppDelegate: 📞 Launched for VoIP push — skipping heavy setup")
            return true
        }

        // ── Normal launch setup ───────────────────────────────────
        let POSTHOG_API_KEY = "phc_CJVEsIrEFGVZez7JKBE2g5F0jGUDuNZkRC8e7Nx7VAK"
        let POSTHOG_HOST    = "https://eu.i.posthog.com"

        let analyticsService = PostHogAnalyticsService(apiKey: POSTHOG_API_KEY, host: POSTHOG_HOST)
        Analytics.shared.configure(with: analyticsService)

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
        setupDefaultCameraPosition()

        UNUserNotificationCenter.current().delegate = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearNotifications),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        // Audio session is managed entirely by CallKitManager + LiveKit.
        // Do not configure AVAudioSession here — it fights with CallKit.

        return true
    }

    private func setupDefaultCameraPosition() {
        let key = "CameraPosition"
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(AVCaptureDevice.Position.front.rawValue, forKey: key)
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        pushNotificationManager.handleDeviceToken(deviceToken)
        if let userId = Auth.auth().currentUser?.uid {
            self.pushNotificationManager.queueTokenUpdate(userId: userId)
        }
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

@main
struct PingbearApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var isLoggedIn: Bool = UserDefaults.standard.bool(forKey: "isLoggedIn")
    @State private var pendingLoginDeepLink: URL?
    @State private var selectedTab: Int = 0

    @StateObject private var callManager = VoiceCallManager.shared

    let didLogOut = PassthroughSubject<Void, Never>()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLoggedIn && Auth.auth().currentUser != nil {
                    NavigationStack {
                        MainTabView(selectedTab: $selectedTab)
                            .navigationBarHidden(true)
                    }
                    .onAppear {
                        setupApp()
                    }
                    .environment(\.didLogOut, didLogOut)
                    .onReceive(didLogOut) { _ in
                        isLoggedIn = false
                        callManager.leaveCall()
                    }

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
            window.overrideUserInterfaceStyle = .dark
        }
        AttributionManager.shared.checkAndRecord()
    }
}
