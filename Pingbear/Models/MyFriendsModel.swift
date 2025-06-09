import FirebaseAuth
import FirebaseFirestore

class AppUser: Identifiable {
    var id: String
    var name: String
    var profileImageUrl: String?

    init(id: String, name: String, profileImageUrl: String? = nil) {
        self.id = id
        self.name = name
        self.profileImageUrl = profileImageUrl
    }
}

class MyFriendsModel: ObservableObject {
    @Published var friends: [AppUser] = []

    func fetchFriends(completion: (() -> Void)? = nil) {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Authentication failed - unable to fetch current user ID")
            completion?()
            return
        }
        
        let db = Firestore.firestore()
        let friendsRef = db.collection("users").document(currentUserID).collection("friends")
        
        friendsRef.getDocuments { [weak self] (snapshot, error) in
            if let error = error {
                print("Error fetching friends: \(error)")
                completion?()
                return
            }
            let friendIDs = snapshot?.documents.compactMap { $0.documentID } ?? []
            self?.fetchUserDetails(friendIDs: friendIDs) {
                completion?()
            }
        }
    }

    private func fetchUserDetails(friendIDs: [String], completion: @escaping () -> Void) {
        guard !friendIDs.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.friends = []
            }
            completion()
            return
        }
        
        let db = Firestore.firestore()
        let usersRef = db.collection("users")
        var users = [AppUser]()
        
        let group = DispatchGroup()
        
        for friendID in friendIDs {
            group.enter()
            usersRef.document(friendID).getDocument { (document, error) in
                defer { group.leave() }
                if let document = document, document.exists,
                   let data = document.data(),
                   let name = data["username"] as? String {

                    let profileImageUrl = data["profilePictureUrl"] as? String
                    let user = AppUser(id: friendID, name: name, profileImageUrl: profileImageUrl)
                    users.append(user)
                } else if let error = error {
                    print("Error fetching user details: \(error)")
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.friends = users.sorted(by: { $0.name < $1.name })
            completion()
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
                    Analytics.shared.track(event: "friend_removed")
                }
            }
        }
    }
}
