import SwiftUI
import Firebase
import FirebaseFirestore

class AddFriendsModel: ObservableObject {
    
    // Function to add a friend by phone number
    func addFriend(byPhoneNumber phoneNumber: String, completion: @escaping (Bool, Error?) -> Void) {
        
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Failed to get current user ID")
            completion(false, nil)
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").whereField("phoneNumber", isEqualTo: phoneNumber).getDocuments { (snapshot, error) in
            if let error = error {
                print("Error getting documents: \(error)")
                completion(false, error)
                return
            }
            
            guard let document = snapshot?.documents.first else {
                print("No user found with this phone number.")
                completion(false, nil)
                return
            }
            
            let friendID = document.documentID
            // Add this user to the current user's friends list
            db.collection("users").document(currentUserID).collection("friends").document(friendID).setData(["uid": friendID]) { (error) in
                if let error = error {
                    completion(false, error)
                    return
                }
                
                // Add the current user to this user's friends list
                db.collection("users").document(friendID).collection("friends").document(currentUserID).setData(["uid": currentUserID]) { (error) in
                    if let error = error {
                        completion(false, error)
                        return
                    }
                    completion(true, nil)
                }
            }
        }
    }
}
