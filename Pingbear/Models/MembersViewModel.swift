import SwiftUI
import FirebaseFirestore

class MembersViewModel: ObservableObject {
    @Published var joinUsernames: [String] = []

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
            let sortedUsernames = usernames.sorted(by: <)
            completion(sortedUsernames)
        }
    }

    func fetchMembersDetails(for competition: Competition) {
        db.collection("competitions").document(competition.id).collection("members")
            .getDocuments { [weak self] (snapshot, error) in
                if let error = error {
                    print("Error fetching member details: \(error)")
                    return
                }

                let userIds = snapshot?.documents.map { $0.documentID } ?? []
                self?.fetchUsernames(for: userIds) { usernames in
                    DispatchQueue.main.async {
                        self?.joinUsernames = usernames
                    }
                }
            }
    }
    
    func leaveCompetition(competitionId: String, userId: String) {
        let db = Firestore.firestore()

        let batch = db.batch()

        let groupMembershipRef = db.collection("groupMemberships").document(userId)
                                    .collection("competitions").whereField("competitionId", isEqualTo: competitionId)

        groupMembershipRef.getDocuments { (snapshot, error) in
            if let error = error {
                print("Error finding group membership to delete: \(error)")
                return
            }

            snapshot?.documents.forEach { document in
                batch.deleteDocument(document.reference)
            }

            let memberRef = db.collection("competitions").document(competitionId).collection("members").document(userId)

            batch.deleteDocument(memberRef)

            batch.commit { err in
                if let err = err {
                    print("Error removing user from group: \(err)")
                } else {
                    print("User successfully removed from group")
                }
            }
        }
    }
}
