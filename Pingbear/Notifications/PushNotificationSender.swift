import SwiftUI
import FirebaseMessaging
import Foundation

/// Response structure from token endpoint
struct TokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int?
}

/// Error types specific to push notifications
enum PushNotificationError: Error {
    case invalidURL
    case networkError(Error)
    case authenticationError
    case decodingError
    case invalidToken
    case serverError(Int)
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL for FCM request"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .authenticationError:
            return "Failed to authenticate with FCM"
        case .decodingError:
            return "Failed to decode server response"
        case .invalidToken:
            return "Invalid or expired FCM token"
        case .serverError(let code):
            return "Server returned error code: \(code)"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}

/// Manages sending of push notifications
class PushNotificationSender: ObservableObject {
    // MARK: - Properties
    
    private let projectID: String
    private let tokenEndpoint: String
    
    @Published var isLoading: Bool = false
    @Published var lastError: PushNotificationError?
    
    // MARK: - Initialization
    
    /// Initialize with configuration
    /// - Parameters:
    ///   - projectID: Firebase project ID
    ///   - tokenEndpoint: Endpoint to fetch access token
    init(projectID: String = "pingbear-96b4c",
         tokenEndpoint: String = "https://us-central1-pingbear-96b4c.cloudfunctions.net/getAccessToken") {
        self.projectID = projectID
        self.tokenEndpoint = tokenEndpoint
    }
    
    // MARK: - Public Methods
    
    /// Send a push notification to a specific device token
    /// - Parameters:
    ///   - token: The FCM device token
    ///   - title: Notification title
    ///   - body: Notification body text
    ///   - completion: Completion handler with success/failure
    func sendPushNotification(
        to token: String,
        title: String,
        body: String,
        completion: ((Result<Void, PushNotificationError>) -> Void)? = nil
    ) {
        isLoading = true
        lastError = nil
        
        // Validate token
        guard !token.isEmpty else {
            isLoading = false
            lastError = .invalidToken
            completion?(.failure(.invalidToken))
            return
        }
        
        // SIMPLIFIED: Always fetch a fresh token for every notification
        fetchAccessToken { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let accessToken):
                self.postNotification(to: token, title: title, body: body, accessToken: accessToken, completion: completion)
            case .failure(let error):
                self.isLoading = false
                self.lastError = error
                completion?(.failure(error))
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Post the notification to FCM
    private func postNotification(
        to token: String,
        title: String,
        body: String,
        accessToken: String,
        completion: ((Result<Void, PushNotificationError>) -> Void)?
    ) {
        let urlString = "https://fcm.googleapis.com/v1/projects/\(projectID)/messages:send"
        guard let url = URL(string: urlString) else {
            isLoading = false
            lastError = .invalidURL
            completion?(.failure(.invalidURL))
            return
        }
        
        // Message payload
        let messageDict: [String: Any] = [
            "message": [
                "token": token,
                "notification": [
                    "title": title,
                    "body": body
                ],
                "apns": [
                    "payload": [
                        "aps": [
                            "sound": "default",
                            "badge": 1
                        ]
                    ]
                ]
            ]
        ]
        
        // Create and configure request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: messageDict)
        } catch {
            isLoading = false
            lastError = .decodingError
            completion?(.failure(.decodingError))
            return
        }
        
        // Make the request
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                // Handle network error
                if let error = error {
                    self.lastError = .networkError(error)
                    completion?(.failure(.networkError(error)))
                    return
                }
                
                // Check HTTP status code
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode != 200 {
                        let serverError = PushNotificationError.serverError(httpResponse.statusCode)
                        self.lastError = serverError
                        completion?(.failure(serverError))
                        
                        // Log the response body for debugging
                        if let data = data, let responseString = String(data: data, encoding: .utf8) {
                            print("FCM Error Response: \(responseString)")
                        }
                        return
                    }
                }
                
                // Log analytics event for successful notification
                Analytics.shared.track(
                    event: "push_notification_sent",
                    properties: [
                        "success": true,
                        "has_data": data != nil
                    ]
                )
                
                completion?(.success(()))
            }
        }
        task.resume()
    }
    
    /// Fetch a fresh access token
    private func fetchAccessToken(completion: @escaping (Result<String, PushNotificationError>) -> Void) {
        guard let url = URL(string: tokenEndpoint) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add Firebase Auth token if available
        if let authToken = UserDefaults.standard.string(forKey: "firebase_auth_token") {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error)))
                }
                return
            }
            
            // Check HTTP status
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                DispatchQueue.main.async {
                    if httpResponse.statusCode == 401 {
                        completion(.failure(.authenticationError))
                    } else {
                        completion(.failure(.serverError(httpResponse.statusCode)))
                    }
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(.unknown))
                }
                return
            }
            
            do {
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                
                DispatchQueue.main.async {
                    // Just return the token without caching
                    completion(.success(tokenResponse.accessToken))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.decodingError))
                }
            }
        }.resume()
    }
}
