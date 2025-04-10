import SwiftUI
import Firebase
import FirebaseMessaging
import Combine
import AVFoundation
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    var pushNotificationManager = PushNotificationManager.shared
  
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()

        // Configure analytics with PostHog
        let POSTHOG_API_KEY = "phc_CJVEsIrEFGVZez7JKBE2g5F0jGUDuNZkRC8e7Nx7VAK"
        let POSTHOG_HOST = "https://eu.i.posthog.com"
        
        // Setup analytics with PostHog implementation
        let analyticsService = PostHogAnalyticsService(apiKey: POSTHOG_API_KEY, host: POSTHOG_HOST)
        Analytics.shared.configure(with: analyticsService)
        
        // Setup notification settings check
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .authorized && Auth.auth().currentUser != nil {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    
                    // Process any queued token updates if the user is already authorized
                    if let userId = Auth.auth().currentUser?.uid {
                        self.pushNotificationManager.queueTokenUpdate(userId: userId)
                    }
                }
            }
        }
        
        // Setup the notification manager
        pushNotificationManager.setup()
        
        // Process any pending tokens that might have been interrupted
        pushNotificationManager.processAnyPendingTokens()
        
        setupDefaultCameraPosition()
        
        // Setup notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(clearNotifications), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        return true
    }
    
    private func setupDefaultCameraPosition() {
        let key = "CameraPosition"
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(AVCaptureDevice.Position.front.rawValue, forKey: key)
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        pushNotificationManager.handleDeviceToken(deviceToken)
        
        // Once we have the device token, ensure we try to update the FCM token in Firestore
        if let userId = Auth.auth().currentUser?.uid {
            self.pushNotificationManager.queueTokenUpdate(userId: userId)
        }
    }
    
    @objc private func clearNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
    
    // Handle remote notifications
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        // This notification is not for Firebase Authentication.
        // Implement any other handling you might have for other notifications.
    }
}

@main
struct PingbearApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // Check UserDefaults
    @State private var isLoggedIn: Bool = UserDefaults.standard.bool(forKey: "isLoggedIn")
    
    let didLogOut = PassthroughSubject<Void, Never>()
    
    var body: some Scene {
        WindowGroup {
            if isLoggedIn && Auth.auth().currentUser != nil {
                MyCompsView()
                    .onAppear {
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = scene.windows.first {
                            window.overrideUserInterfaceStyle = .dark
                        }
                    }
                    .environment(\.didLogOut, didLogOut)
                    .onReceive(didLogOut) { _ in
                        isLoggedIn = false
                    }
            } else {
                NavigationView {
                    WelcomeView()
                        .onAppear {
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = scene.windows.first {
                                window.overrideUserInterfaceStyle = .dark
                            }
                        }
                        .environment(\.didLogOut, didLogOut)
                        .onReceive(didLogOut) { _ in
                            isLoggedIn = false
                        }
                }
                .accentColor(.white)
            }
        }
    }
}
