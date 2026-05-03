import SwiftUI
import Firebase
import FirebaseMessaging
import Combine
import AVFoundation
import UserNotifications

extension AppDelegate {
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("AppDelegate received URL: \(url)")
        
        if Auth.auth().canHandle(url) {
            return true
        }
        
        if url.scheme == "socialstar" {
            DeepLinkHandler.shared.handleURL(url)
            return true
        }
        
        return false
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    var pushNotificationManager = PushNotificationManager.shared
  
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()

        let POSTHOG_API_KEY = "phc_CJVEsIrEFGVZez7JKBE2g5F0jGUDuNZkRC8e7Nx7VAK"
        let POSTHOG_HOST = "https://eu.i.posthog.com"
        
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
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        
        if let deepLink = userInfo["deepLink"] as? String,
           let url = URL(string: deepLink) {
            DeepLinkHandler.shared.handleURL(url)
        }
        
        completionHandler(.newData)
    }
}

@main
struct PingbearApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var isLoggedIn: Bool = UserDefaults.standard.bool(forKey: "isLoggedIn")
    @StateObject private var deepLinkHandler = DeepLinkHandler.shared
    @State private var selectedCompetition: Competition?
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
                    .onAppear {
                        setupApp()
                        processLoginPendingDeepLink()
                    }
                    .environment(\.didLogOut, didLogOut)
                    .onReceive(didLogOut) { _ in
                        isLoggedIn = false
                        deepLinkHandler.reset()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        CompetitionPricingCalculator.shared.reconnect()
                    }
                    .onOpenURL { url in
                        handleOpenURL(url)
                    }
                } else {
                    NavigationView {
                        WelcomeView()
                            .onAppear {
                                setupApp()
                            }
                            .environment(\.didLogOut, didLogOut)
                            .onReceive(didLogOut) { _ in
                                isLoggedIn = false
                            }
                    }
                    .accentColor(.white)
                    .onOpenURL { url in
                        handleOpenURL(url)
                    }
                }
            }
            .fullScreenCover(item: $selectedCompetition) { competition in
                NavigationStack {
                    CompDetails(competition: competition)
                }
            }
            .onChange(of: deepLinkHandler.pendingDeepLink) { _ in
                processPendingDeepLinks()
            }
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
        EntryUploadManager.shared.initialize()
    }
    
    private func processLoginPendingDeepLink() {
        if let pendingUrl = pendingLoginDeepLink {
            deepLinkHandler.handleURL(pendingUrl)
            pendingLoginDeepLink = nil
        }
    }
    
    private func handleOpenURL(_ url: URL) {
        print("PingbearApp received URL via onOpenURL: \(url)")
        
        if !isLoggedIn || Auth.auth().currentUser == nil {
            pendingLoginDeepLink = url
            return
        }
        
        ModalDismisser.dismissAllModals {
            self.selectedCompetition = nil
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.deepLinkHandler.handleURL(url)
            }
        }
    }
    
    private func processPendingDeepLinks() {
        ModalDismisser.dismissAllModals {
            self.deepLinkHandler.processPendingDeepLink { competition in
                if let competition = competition {
                    DispatchQueue.main.async {
                        self.selectedCompetition = competition
                    }
                }
            }
        }
    }
}
