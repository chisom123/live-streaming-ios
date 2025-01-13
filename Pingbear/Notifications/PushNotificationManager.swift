import FirebaseMessaging

class PushNotificationManager: NSObject, MessagingDelegate, UNUserNotificationCenterDelegate {
    override init() {
        super.init()
        Messaging.messaging().delegate = self
    }
    
    func handleDeviceToken(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        _ = fcmToken
    }
}
