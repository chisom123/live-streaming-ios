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
            
            // Check if the friendship already exists
            let currentUserFriendsRef = userRef.document(currentUserID).collection("friends").document(friendID)
            let friendUserFriendsRef = userRef.document(friendID).collection("friends").document(currentUserID)
            
            db.runTransaction({ (transaction, errorPointer) -> Any? in
                let currentUserFriendDocument: DocumentSnapshot
                let friendUserFriendDocument: DocumentSnapshot
                do {
                    try currentUserFriendDocument = transaction.getDocument(currentUserFriendsRef)
                    try friendUserFriendDocument = transaction.getDocument(friendUserFriendsRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                if currentUserFriendDocument.exists && friendUserFriendDocument.exists {
                    return nil  // Already friends
                }
                
                transaction.setData(["uid": friendID], forDocument: currentUserFriendsRef)
                transaction.setData(["uid": currentUserID], forDocument: friendUserFriendsRef)
                return nil
            }) { (object, error) in
                if let error = error {
                    completion(false, error)
                    return
                }
                completion(true, nil)
                PostHogSDK.shared.capture("Friend Added")
            }
        }
    }
}
