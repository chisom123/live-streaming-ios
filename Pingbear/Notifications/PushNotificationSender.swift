import SwiftUI
import FirebaseMessaging
import Foundation
import PostHog

struct TokenResponse: Codable {
    var accessToken: String
}

class PushNotificationSender: ObservableObject {
    func sendPushNotification(to token: String, title: String, body: String) {
        PostHogSDK.shared.capture("Notification Send Attempt", properties: ["token": token])
        fetchAccessToken { result in
            switch result {
            case .success(let accessToken):
                self.postNotification(to: token, title: title, body: body, accessToken: accessToken)
            case .failure(let error):
                print("Failed to fetch access token: \(error.localizedDescription)")
            }
        }
    }

    private func postNotification(to token: String, title: String, body: String, accessToken: String) {
        let projectID = "pingbear-96b4c"  // Replace with your actual project ID
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
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error sending push notification: \(error?.localizedDescription ?? "No data")")
                return
            }
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                PostHogSDK.shared.capture("Notification Sent", properties: ["status": "success"])
            } else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                PostHogSDK.shared.capture("Notification Send Error", properties: ["status": "failed", "statusCode": statusCode])
            }
        }
        task.resume()
    }
    
    func fetchAccessToken(completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://getaccesstoken-4lnpddia6q-uc.a.run.app") else {
            print("Invalid URL")
            completion(.failure(NSError(domain: "URLInvalidError", code: 1, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            if let data = data {
                if let decodedResponse = try? JSONDecoder().decode(TokenResponse.self, from: data) {
                    DispatchQueue.main.async {
                        completion(.success(decodedResponse.accessToken))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "JSONDecodingError", code: 2, userInfo: nil)))
                    }
                }
            }
        }.resume()
    }
}
