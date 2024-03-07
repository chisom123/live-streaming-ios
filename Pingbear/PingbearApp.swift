import SwiftUI
import Firebase
import Combine
import Flurry_iOS_SDK
import PostHog

class AppDelegate: NSObject, UIApplicationDelegate {
  
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()

        let POSTHOG_API_KEY = "phc_CWa3tntbLhQKIPoZ8CFX5Ydg1l3Kt6GVyO7ztgANLX8"
        let POSTHOG_HOST = "https://eu.posthog.com"

        let config = PostHogConfig(apiKey: POSTHOG_API_KEY, host: POSTHOG_HOST)
        PostHogSDK.shared.setup(config)
        
        let builder = FlurrySessionBuilder.init()
           builder.build(crashReportingEnabled: true)
           builder.build(logLevel: .all)
        Flurry.startSession(apiKey: "WMHP655MSWY769SJRTYF", sessionBuilder: builder)
        
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
    @StateObject private var sharedViewModel = SharedViewModel()
    
    let didLogOut = PassthroughSubject<Void, Never>()
    
    var body: some Scene {
        WindowGroup {
            if isLoggedIn && Auth.auth().currentUser != nil {
                if sharedViewModel.shouldNavigateToCompetitionsView {
                    ContentView()
                        .environmentObject(sharedViewModel)
                        .onAppear {
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = scene.windows.first {
                                window.overrideUserInterfaceStyle = .light
                            }
                            sharedViewModel.shouldNavigateToCompetitionsView = false
                        }
                        .environment(\.didLogOut, didLogOut)
                        .onReceive(didLogOut) { _ in
                            isLoggedIn = false
                        }
                } else {
                    ContentView()
                        .environmentObject(sharedViewModel)
                        .onAppear {
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = scene.windows.first {
                                window.overrideUserInterfaceStyle = .light
                            }
                            sharedViewModel.shouldNavigateToCompetitionsView = false
                        }
                        .environment(\.didLogOut, didLogOut)
                        .onReceive(didLogOut) { _ in
                            isLoggedIn = false
                        }
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
