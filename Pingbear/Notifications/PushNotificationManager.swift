import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications
import SwiftUI

class PushNotificationManager: NSObject, MessagingDelegate, UNUserNotificationCenterDelegate, ObservableObject {
    static let shared = PushNotificationManager()
    
    // Don't initialize Firebase services at property declaration time
    private var _db: Firestore?
    private var db: Firestore {
        if _db == nil {
            _db = Firestore.firestore()
        }
        return _db!
    }
    
    @Published var isNotificationsAuthorized = false
    private var isSetup = false
    
    // Add token queue mechanism
    private var tokenUpdateQueue: [String: String] = [:]
    private var isProcessingQueue = false
    private var retryCount: [String: Int] = [:]
    private let maxRetries = 5

    // Tracked so FCMTokenWatcher can detect staleness, mirroring
    // VoIPPushManager.currentTokenString. Purely additive — nothing
    // else depends on this except FCMTokenWatcher and the writes below.
    private(set) var currentFCMToken: String?
    
    override init() {
        super.init()
        // Don't access Firebase services here
        
        // Check UserDefaults for any pending tokens from previous app sessions
        loadQueuedTokensFromUserDefaults()
    }
    
    func setup() {
        if isSetup { return }
        Messaging.messaging().delegate = self
        checkNotificationStatus()
        isSetup = true
    }
    
    // Request notification permission
    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isNotificationsAuthorized = granted
                if granted {
                    // Register for remote notifications if permission is granted
                    UIApplication.shared.registerForRemoteNotifications()
                    
                    // Queue a token update to ensure it happens regardless of view lifecycle
                    if let userId = Auth.auth().currentUser?.uid {
                        self.queueTokenUpdate(userId: userId)
                    }
                }
                completion(granted)
            }
        }
    }
    
    // Check current notification status
    func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isNotificationsAuthorized = settings.authorizationStatus == .authorized
                if self.isNotificationsAuthorized {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    // Handle device token
    func handleDeviceToken(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        
        // If we get a device token, make sure FCM token gets updated
        if let userId = Auth.auth().currentUser?.uid {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.queueTokenUpdate(userId: userId)
            }
        }
    }
    
    // Load any queued tokens from UserDefaults
    private func loadQueuedTokensFromUserDefaults() {
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.starts(with: "pendingFCMToken_") }
        
        for key in keys {
            if let token = defaults.string(forKey: key) {
                let userId = String(key.dropFirst("pendingFCMToken_".count))
                tokenUpdateQueue[userId] = token
                print("Loaded queued token for user \(userId) from UserDefaults")
            }
        }
    }
    
    // Queue token updates to make them more resilient
    func queueTokenUpdate(userId: String) {
        // Get FCM token
        Messaging.messaging().token { [weak self] token, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching FCM token: \(error)")
                return
            }
            
            if let token = token {
                print("Queueing FCM token update for user \(userId)")
                
                // Queue the token update
                self.tokenUpdateQueue[userId] = token
                
                // Store in UserDefaults as backup
                UserDefaults.standard.set(token, forKey: "pendingFCMToken_\(userId)")
                
                // Start queue processing if not already running
                if !self.isProcessingQueue {
                    self.processTokenUpdateQueue()
                }
            }
        }
    }
    
    // Process token update queue with retry logic
    func processTokenUpdateQueue() {
        guard !isProcessingQueue, !tokenUpdateQueue.isEmpty else { return }
        
        isProcessingQueue = true
        
        let userId = tokenUpdateQueue.keys.first!
        let token = tokenUpdateQueue[userId]!
        
        print("Processing FCM token update for user \(userId)")
        
        db.collection("users").document(userId).updateData([
            "fcmToken": token
        ]) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error updating FCM token: \(error)")
                
                // Increment retry count
                let currentRetries = self.retryCount[userId] ?? 0
                self.retryCount[userId] = currentRetries + 1
                
                // Only retry up to max retries
                if currentRetries < self.maxRetries {
                    // Exponential backoff for retries
                    let delay = pow(2.0, Double(currentRetries)) * 1.0
                    
                    print("Will retry FCM token update for user \(userId) in \(delay) seconds (attempt \(currentRetries + 1))")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.isProcessingQueue = false
                        self.processTokenUpdateQueue()
                    }
                } else {
                    print("Max retries reached for FCM token update for user \(userId)")
                    
                    // Keep the token in UserDefaults but remove from active queue
                    self.tokenUpdateQueue.removeValue(forKey: userId)
                    self.retryCount.removeValue(forKey: userId)
                    
                    // Continue with next item
                    self.isProcessingQueue = false
                    if !self.tokenUpdateQueue.isEmpty {
                        self.processTokenUpdateQueue()
                    }
                }
            } else {
                print("FCM token updated successfully for user \(userId)")

                // Keep currentFCMToken in sync so FCMTokenWatcher can
                // correctly evaluate staleness against Firestore.
                self.currentFCMToken = token

                // Remove from queue and UserDefaults
                self.tokenUpdateQueue.removeValue(forKey: userId)
                self.retryCount.removeValue(forKey: userId)
                UserDefaults.standard.removeObject(forKey: "pendingFCMToken_\(userId)")
                
                // Continue processing if there are more items
                DispatchQueue.main.async {
                    self.isProcessingQueue = false
                    if !self.tokenUpdateQueue.isEmpty {
                        self.processTokenUpdateQueue()
                    }
                }
            }
        }
    }
    
    // Method to process any pending tokens at app startup
    func processAnyPendingTokens() {
        if !tokenUpdateQueue.isEmpty {
            print("Processing \(tokenUpdateQueue.count) pending FCM token updates")
            processTokenUpdateQueue()
        }
    }
    
    // Update FCM token in Firestore (previous implementation - now uses queue)
    func updateFCMTokenInFirestore() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Check notification permission first
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            // Only proceed if notifications are authorized
            guard settings.authorizationStatus == .authorized else {
                print("Notifications not authorized - not updating FCM token")
                return
            }
            
            // Queue token update instead of handling directly
            self.queueTokenUpdate(userId: userId)
        }
    }

    /// Writes a known token directly to Firestore without going through
    /// Messaging.messaging().token(). Needed because that fetch can fail
    /// with "No APNS token specified" if APNS hasn't (re-)registered yet —
    /// in that case we still have a perfectly good token in memory and
    /// should just persist it, mirroring VoIPPushManager.persistTokenDirectly().
    func writeTokenDirectly(_ token: String, uid: String) {
        print("[PushNotificationManager] 📝 writeTokenDirectly() called for user \(uid)")
        currentFCMToken = token
        db.collection("users").document(uid).updateData(["fcmToken": token]) { [weak self] error in
            guard let self else { return }
            if let error {
                print("[PushNotificationManager] ❌ writeTokenDirectly failed: \(error.localizedDescription) — stashing for retry")
                UserDefaults.standard.set(token, forKey: "pendingFCMToken_\(uid)")
                self.tokenUpdateQueue[uid] = token
                if !self.isProcessingQueue {
                    self.processTokenUpdateQueue()
                }
            } else {
                print("[PushNotificationManager] ✅ fcmToken written directly for \(uid)")
                UserDefaults.standard.removeObject(forKey: "pendingFCMToken_\(uid)")
            }
        }
    }

    /// Deletes fcmToken from Firestore and clears local/queued state. Call on
    /// sign-out so a logged-out device is never sent pushes meant for it.
    /// Mirrors VoIPPushManager.clearToken() but is fully independent of it.
    func clearToken() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[PushNotificationManager] clearToken() — no current user, nothing to clear")
            return
        }
        print("[PushNotificationManager] 🗑 Clearing fcmToken for user \(uid)")
        db.collection("users").document(uid).updateData(["fcmToken": FieldValue.delete()])
        UserDefaults.standard.removeObject(forKey: "pendingFCMToken_\(uid)")
        tokenUpdateQueue.removeValue(forKey: uid)
        retryCount.removeValue(forKey: uid)
        currentFCMToken = nil
    }
    
    // Keep your existing MessagingDelegate method
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        
        // Additional code for photo sharing notifications
        if let token = fcmToken, let userId = Auth.auth().currentUser?.uid {
            // Keep currentFCMToken in sync for FCMTokenWatcher's staleness check.
            currentFCMToken = token

            // Use the queue system for token updates
            tokenUpdateQueue[userId] = token
            UserDefaults.standard.set(token, forKey: "pendingFCMToken_\(userId)")
            
            if !isProcessingQueue {
                processTokenUpdateQueue()
            }
        }
    }
}
