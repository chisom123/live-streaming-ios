import SwiftUI
import Firebase
import FirebaseFirestore

class AppUser: Identifiable {
    var id: String
    var name: String
    var phoneNumber: String

    init(id: String, name: String, phoneNumber: String) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
    }
}

class MyFriendsModel: ObservableObject {
    @Published var friends: [AppUser] = []

    func fetchFriends() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Authentication failed - unable to fetch current user ID")
            return
        }
        
        let db = Firestore.firestore()
        let friendsRef = db.collection("users").document(currentUserID).collection("friends")
        
        friendsRef.getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching friends: \(error)")
                return
            }
            let friendIDs = snapshot?.documents.compactMap { $0.documentID } ?? []
            self.fetchUserDetails(friendIDs: friendIDs)
        }
    }

    private func fetchUserDetails(friendIDs: [String]) {
        guard !friendIDs.isEmpty else { return }
        
        let db = Firestore.firestore()
        let usersRef = db.collection("users")
        var users = [AppUser]()
        
        let group = DispatchGroup()
        
        for friendID in friendIDs {
            group.enter()
            usersRef.document(friendID).getDocument { (document, error) in
                defer { group.leave() }
                if let document = document, document.exists,
                   let name = document.data()?["username"] as? String,
                   let phoneNumber = document.data()?["phoneNumber"] as? String {
                    let user = AppUser(id: friendID, name: name, phoneNumber: phoneNumber)
                    users.append(user)
                } else if let error = error {
                    print("Error fetching user details: \(error)")
                }
            }
        }
        
        group.notify(queue: .main) {
            self.friends = users.sorted(by: { $0.name < $1.name })
        }
    }

    func removeFriend(id: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Authentication failed - unable to fetch current user ID")
            return
        }

        let db = Firestore.firestore()
        let currentUserRef = db.collection("users").document(currentUserID).collection("friends").document(id)
        let friendRef = db.collection("users").document(id).collection("friends").document(currentUserID)

        let batch = db.batch()
        batch.deleteDocument(currentUserRef)
        batch.deleteDocument(friendRef)

        batch.commit { error in
            if let error = error {
                print("Error removing friendship: \(error)")
            } else {
                DispatchQueue.main.async {
                    self.friends.removeAll { $0.id == id }
                    print("Successfully removed the mutual friend relationship")
                }
            }
        }
    }


}
