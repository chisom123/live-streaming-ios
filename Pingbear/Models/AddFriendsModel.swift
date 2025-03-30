import FirebaseAuth
import FirebaseFirestore

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
                Analytics.shared.track(event: "friend_added")
            }
        }
    }
}
