import SwiftUI
import Firebase
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
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

class AuthenticationState: ObservableObject {
    @Published var isAuthenticated = false

    init() {
        Auth.auth().addStateDidChangeListener { auth, user in
            if let _ = user {
                self.isAuthenticated = true
            } else {
                self.isAuthenticated = false
            }
        }
    }
}

@main
struct PingbearApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authState = AuthenticationState()

    var body: some Scene {
        WindowGroup {
            if authState.isAuthenticated {
                HomeView() // Show your home view if user is authenticated
            } else {
                LandingView() // Show your login/verification view if user is not authenticated
            }
        }
    }
}
