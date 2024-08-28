import SwiftUI
import Firebase
import FirebaseFirestore
import PostHog

class AddFriendsModel: ObservableObject {
    
    // Function to add a friend by username
    func addFriend(byUsername username: String, completion: @escaping (Bool, Error?) -> Void) {
        
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            completion(false, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Authentication failed"]))
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("users")
        
        userRef.whereField("username", isEqualTo: username).getDocuments { (snapshot, error) in
            if let error = error {
                completion(false, error)
                return
            }
            
            guard let document = snapshot?.documents.first else {
                completion(false, NSError(domain: "", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not found"]))
                return
            }
            
            let friendID = document.documentID
            
            // Check if the user is trying to add themselves
            if friendID == currentUserID {
                completion(false, NSError(domain: "", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot add yourself as a friend"]))
                return
            }
            
            // Setup references
            let currentUserFriendsRef = userRef.document(currentUserID).collection("friends").document(friendID)
            let friendUserFriendsRef = userRef.document(friendID).collection("friends").document(currentUserID)
            
            // Prepare a batch write
            let batch = db.batch()
            
            // Add operations to the batch
            batch.setData(["uid": friendID], forDocument: currentUserFriendsRef)
            batch.setData(["uid": currentUserID], forDocument: friendUserFriendsRef)
            
            // Commit the batch
            batch.commit { error in
                if let error = error {
                    completion(false, error)
                    return
                }
                completion(true, nil)
                PostHogSDK.shared.capture("Friend Added")
                
                self.sendFriendAddedNotification(currentUserID: currentUserID, to: friendID)
            }
        }
    }
    
    private func sendFriendAddedNotification(currentUserID: String, to friendID: String) {
        let db = Firestore.firestore()
        let userRef = db.collection("users")
        
        // Fetch both the friend's and current user's data
        let group = DispatchGroup()
        var friendToken: String?
        var currentUsername: String?
        
        group.enter()
        userRef.document(friendID).getDocument { (document, error) in
            defer { group.leave() }
            if let error = error {
                print("Error fetching friend user: \(error)")
                return
            }
            friendToken = document?.data()?["fcmToken"] as? String
        }
        
        group.enter()
        userRef.document(currentUserID).getDocument { (document, error) in
            defer { group.leave() }
            if let error = error {
                print("Error fetching current user: \(error)")
                return
            }
            currentUsername = document?.data()?["username"] as? String
        }
        
        group.notify(queue: .main) { [weak self] in
            let notificationSender = PushNotificationSender()
            
            guard let self = self else { return }
            
            guard let token = friendToken else {
                print("FCM token not found for user \(friendID)")
                return
            }
            
            guard let username = currentUsername else {
                print("Current user's username not found")
                return
            }
            
            let title = "New Friend Added"
            let body = "\(username) added you as a friend"
            
            notificationSender.sendPushNotification(to: token, title: title, body: body)
        }
    }
}
