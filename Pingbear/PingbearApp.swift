import SwiftUI
import Firebase
import Combine

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
                HomeView() // This assumes you have a HomeView struct for the home page.
                    .onAppear {
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = scene.windows.first {
                            window.overrideUserInterfaceStyle = .light
                        }
                    }
                    .environment(\.didLogOut, didLogOut)
                    .onReceive(didLogOut) { _ in
                        isLoggedIn = false
                    }
            } else {
                LandingView()
                    .onAppear {
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = scene.windows.first {
                            window.overrideUserInterfaceStyle = .light
                        }
                    }
                    .environment(\.didLogOut, didLogOut)
                    .onReceive(didLogOut) { _ in
                        isLoggedIn = false
                    }
            }
        }
    }
}
