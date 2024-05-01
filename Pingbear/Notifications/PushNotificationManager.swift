import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseMessaging

class PushNotificationManager: NSObject, ObservableObject, MessagingDelegate, UNUserNotificationCenterDelegate {
    @Published var userID: String?
    private var db: Firestore

    override init() {
        self.db = Firestore.firestore()
        super.init()
        Messaging.messaging().delegate = self
        registerForPushNotifications()
    }
    
    func handleDeviceToken(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func setupWithUserID(_ userID: String) {
        self.userID = userID
        registerForPushNotifications()
    }
    
    private func registerMessagingDelegate() {
        Messaging.messaging().delegate = self
    }

    func registerForPushNotifications() {
        guard let userID = userID else {
            print("User ID not set. Cannot register for notifications.")
            return
        }

        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
                print("Permission granted: \(granted)")
                guard granted else { return }
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } else {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    // Implementation of messaging:didReceiveRegistrationToken:
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else {
            print("Firebase registration token received is nil")
            return
        }
        print("Firebase registration token: \(fcmToken)")
        self.updateFirestorePushToken(fcmToken)
    }

    private func updateFirestorePushToken(_ token: String) {
        guard let userID = userID else {
            print("User ID not set. Cannot update Firestore token.")
            return
        }
        let usersRef = db.collection("users").document(userID)
        
        // Fetch the current token from Firestore
        usersRef.getDocument { (document, error) in
            if let error = error {
                print("Error fetching document: \(error)")
                return
            }
            if let document = document, document.exists {
                if let currentToken = document.get("fcmToken") as? String, currentToken == token {
                    // If the token is the same, do not perform any update
                    print("Token is the same, no need to update.")
                    return
                }
            }
            // If no token or token is different, update Firestore with the new token
            self.setFirestoreToken(token, usersRef: usersRef)
        }
    }

    private func setFirestoreToken(_ token: String, usersRef: DocumentReference) {
        usersRef.setData(["fcmToken": token], merge: true) { error in
            if let error = error {
                print("Error setting document: \(error)")
            } else {
                print("Document successfully updated with new token.")
            }
        }
    }
}
