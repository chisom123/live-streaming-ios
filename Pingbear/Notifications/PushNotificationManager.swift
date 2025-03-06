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
    
    override init() {
        super.init()
        // Don't access Firebase services here
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
                    // We'll update FCM token in Firestore only if permissions are granted
                    // The token will be available after registration completes
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
    
    // Handle device token - keeping your existing implementation
    func handleDeviceToken(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        updateFCMTokenInFirestore()
    }
    
    // Update FCM token in Firestore
    func updateFCMTokenInFirestore() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Check notification permission first
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            // Only proceed if notifications are authorized
            guard settings.authorizationStatus == .authorized else {
                print("Notifications not authorized - not updating FCM token")
                return
            }
            
            // Check for APNS token
            if Messaging.messaging().apnsToken == nil {
                print("APNS token not available yet - will retry when token is received")
                return
            }
            
            // Get and store FCM token
            Messaging.messaging().token { token, error in
                if let error = error {
                    print("Error fetching FCM token: \(error)")
                    return
                }
                
                if let token = token {
                    self.db.collection("users").document(userId).updateData([
                        "fcmToken": token
                    ]) { error in
                        if let error = error {
                            print("Error updating FCM token: \(error)")
                        } else {
                            print("FCM token updated successfully")
                        }
                    }
                }
            }
        }
    }
    
    // Keep your existing MessagingDelegate method
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        _ = fcmToken
        
        // Additional code for photo sharing notifications
        if let token = fcmToken, Auth.auth().currentUser != nil {
            updateFCMTokenInFirestore()
        }
    }
}
