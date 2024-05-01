import SwiftUI
import FirebaseMessaging
import Foundation
import PostHog

class PushNotificationSender: ObservableObject {
    func sendPushNotification(to token: String, title: String, body: String) {
        let projectID = "pingbear-96b4c" // Replace with your actual project ID
        let urlString = "https://fcm.googleapis.com/v1/projects/\(projectID)/messages:send"
        guard let url = URL(string: urlString) else { return }
        
        let message: [String: Any] = [
            "message": [
                "token": token,
                "notification": [
                    "title": title,
                    "body": body
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: message, options: [])
        request.setValue("application/json; UTF-8", forHTTPHeaderField: "Content-Type")
        
        // Fetching an access token using Google's Authentication libraries
        // This part needs to be implemented according to your server setup
        let accessToken = fetchAccessToken()  // Implement this function based on your authentication setup
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error sending push notification: \(error?.localizedDescription ?? "No data")")
                return
            }
            PostHogSDK.shared.capture("Push notification sent")
        }
        task.resume()
    }
    
    private func fetchAccessToken() -> String {
        // Implement token generation or retrieval logic here
        // For example, using Google's Application Default Credentials (ADC)
        return "ya29.c.c0AY_VpZjfIKU_dH_s90UssoBC9rYFpGJPNasUuRI7tSfbJDXmIGUNaJPY0JihJIuHA2Jzr1GKCdIc7fl8pkh0f0Rl0wjetOQz_ozoDABeNOGVeN-KPwAFzidsZlc-H8JniMca2vdef7Ob9A0oIgdBIsJ5FFj3l2yENJhurX0z49lABsfybIYW0SZXKDN1Z5be5OhE1sJ6NTFah_VvbTgLsfJGcgoFK2P7x3DiWr_0WEuBBraENJcjaVbMYTaIGGGdGP7O90feXEbSmpsV0CzYPffp_blQE-yiyeJaJIc5d21SaorpN3UTias4ytAdheGppnJ-fXBpB1B8uNXBCzq4upxdGzd65-lTEz4qLXMzNA7eiqzUE4NbnSYE384DjXBt3s94dSYjoXRwv_eF9o1uk_YieV1q28h7R1zYJg_x84I3l_zVo0IYBgYgM64SkphgqukvW1V7q399ssQWyowza4oxZc_h1V07XzBWl5OBbhmr0MtySqjWsQjo3rjdrBjj9uM4_uomlM8ruRfu4kmrj9ReZdVqbmJdBnQXO_BZtc5gcl8r7jnUmXphSd7u72QweeiSdBI0Yv2kiSRbOUJV_-3zf5RRcph-ZvsiQtlQcURF10z_JjR04YxnqFoscVMXndp-egYO8l9X5RscYFOe8-5ni4cYes66I5tebjSImM3UqWY3lYIWsla9mIhy-m8VaXi43iOgRgk86F0wy9v_J2y6p9s2Yv9hRWbrjX6w_pq2oFho3FWkM-5OcO-eFhhyloBFyJqph5kbWwF4_7-xU19vramg7wI33Sp9fclOynSofsU1w3JSmqupZI0v2rdX-MxUu-tvwtfxnY50agF4uue8-j_-Ja-Xq1qoVh--e_4OyuXnzy0-coi8zltpwUSgo-jZ9fnj99vkp6qh2xg4Ygkfo2dQx38i5Q3vWqQdxMjm2Zlmry0noIf3-gx_-5Fd7r6f-YrR0RMzZtpZppbWezSIb_-klwdYWj2UdX2wgQdVU7FR1vk-VBm"  // Replace with actual token fetching logic
    }
}
