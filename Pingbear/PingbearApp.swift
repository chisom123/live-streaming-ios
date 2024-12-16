import SwiftUI
import Firebase
import Combine
import PostHog
import AVFoundation

class AppDelegate: NSObject, UIApplicationDelegate {
    
    var pushNotificationManager: PushNotificationManager?
  
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()

        let POSTHOG_API_KEY = "phc_TiMANSKNXenX3AKMp8mt9emsGH3W1hPJBM9Rc7AQCzZ"
        let POSTHOG_HOST = "https://eu.posthog.com"

        let config = PostHogConfig(apiKey: POSTHOG_API_KEY, host: POSTHOG_HOST)
        PostHogSDK.shared.setup(config)
        
        setupDefaultCameraPosition()
        
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
        pushNotificationManager?.handleDeviceToken(deviceToken)
    }
    
    @objc private func clearNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
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
    @StateObject private var authStateManager = AuthStateManager()
    let didLogOut = PassthroughSubject<Void, Never>()
    
    var body: some Scene {
        WindowGroup {
            if authStateManager.isLoggedIn {
                ContentView()
                    .onAppear {
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = scene.windows.first {
                            window.overrideUserInterfaceStyle = .light
                        }
                    }
                    .environment(\.didLogOut, didLogOut)
            } else {
                NavigationView {
                    PhoneEntryView()
                        .onAppear {
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = scene.windows.first {
                                window.overrideUserInterfaceStyle = .light
                            }
                        }
                        .environment(\.didLogOut, didLogOut)
                }
                .accentColor(.black)
            }
        }
    }
}

class AuthStateManager: ObservableObject {
    @Published var isLoggedIn: Bool
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        self.isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn") && Auth.auth().currentUser != nil
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            DispatchQueue.main.async {
                let isLoggedIn = user != nil
                UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn")
                self?.isLoggedIn = isLoggedIn
            }
        }
    }
    
    func signOut() {
        FirestoreListenerManager.shared.removeAllListeners()
        PostHogSDK.shared.capture("Sign Out")
        
        do {
            try Auth.auth().signOut()
            UserDefaults.standard.set(false, forKey: "isLoggedIn")
            self.isLoggedIn = false
            PostHogSDK.shared.reset()
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
