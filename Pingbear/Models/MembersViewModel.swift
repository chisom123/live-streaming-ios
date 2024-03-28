import SwiftUI
import FirebaseFirestore

class MembersViewModel: ObservableObject {
    @Published var joinUsernames: [String] = []
    @Published var voteUsernames: [String] = []

    private var db = Firestore.firestore()

    func fetchUsernames(for userIds: [String], completion: @escaping ([String]) -> Void) {
        var usernames: [String] = []
        let group = DispatchGroup()

        userIds.forEach { userId in
            group.enter()
            db.collection("users").document(userId).getDocument { (document, error) in
                if let document = document, document.exists {
                    let username = document.data()?["username"] as? String ?? "Unknown"
                    usernames.append(username)
                } else {
                    print("Document does not exist")
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(usernames)
        }
    }

    func fetchMembersDetails(for competition: Competition) {
        fetchUsernames(for: competition.allow_join) { [weak self] usernames in
            self?.joinUsernames = usernames
        }
        fetchUsernames(for: competition.allow_vote) { [weak self] usernames in
            self?.voteUsernames = usernames
        }
    }
}
