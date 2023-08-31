import SwiftUI
import Firebase

class AppDelegate: NSObject, UIApplicationDelegate {
  
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        APICaller.shared.setup()
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

@main
struct PingbearApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            LandingView()
                .onAppear {
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = scene.windows.first {
                        window.overrideUserInterfaceStyle = .light
                    }
                }
        }
    }
}
