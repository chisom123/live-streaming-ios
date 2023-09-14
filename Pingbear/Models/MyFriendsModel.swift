import SwiftUI
import Firebase
import FirebaseFirestore
import Flurry_iOS_SDK

class MyFriendsModel: ObservableObject {
    @Published var friends: [AppUser] = []

    func fetchFriends() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Failed to get current user ID")
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(currentUserID).collection("friends").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error getting friends: \(error)")
                return
            }
            let friendIDs = snapshot?.documents.compactMap { $0.documentID } ?? []
            self.fetchUserDetails(friendIDs: friendIDs)
        }
    }

    // This function is from your HomeViewModel, with slight changes
    private func fetchUserDetails(friendIDs: [String]) {
        let db = Firestore.firestore()

        // Use DispatchGroup to manage asynchronous operations
        let group = DispatchGroup()
        for friendID in friendIDs {
            group.enter()
            let docRef = db.collection("users").document(friendID)
            
            docRef.getDocument { (document, error) in
                defer { group.leave() }
                if let error = error {
                    print("Error getting friend's details: \(error)")
                    return
                }
                guard let doc = document, doc.exists, let data = doc.data() else { return }

                let friendPhoneNumber = data["phoneNumber"] as? String
                let friendName = data["name"] as? String
                let friendIcon = data["icon"] as? String
                    
                // Removed the lastMessageTimestamp part
                let user = AppUser(id: friendID, name: friendName ?? "", phoneNumber: friendPhoneNumber ?? "", icon: friendIcon)
                
                DispatchQueue.main.async {
                    if let index = self.friends.firstIndex(where: { $0.id == friendID }) {
                        self.friends[index] = user
                    } else {
                        self.friends.append(user)
                    }
                }
            }
        }

        group.notify(queue: .main) {
            self.friends.sort(by: { $0.name < $1.name })
        }
    }

    func removeFriend(id: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Failed to get current user ID")
            return
        }

        let db = Firestore.firestore()

        // 1. Remove the friend from the current user's friends collection
        db.collection("users").document(currentUserID).collection("friends").document(id).delete { error in
            if let error = error {
                print("Error removing friend from current user's friends collection: \(error)")
            } else {
                self.friends.removeAll { $0.id == id }

                // 2. Remove the current user from the friend's friends collection
                db.collection("users").document(id).collection("friends").document(currentUserID).delete { error in
                    if let error = error {
                        print("Error removing current user from friend's friends collection: \(error)")
                    } else {
                        print("Successfully removed the mutual friend relationship")
                    }
                }
            }
        }
    }

}
