import FirebaseFirestore
import FirebaseAuth

struct MemberUser: Identifiable {
    let id: String
    let username: String
    let profileurl: String?
    var isAdded: Bool = false
    var justAdded: Bool = false
}

class MembersViewModel: ObservableObject {
    @Published var members: [MemberUser] = []
    @Published var currentUserId: String = ""
    @Published var isLoading = false
    @Published var error: Error?
    
    private var db = Firestore.firestore()
    private var myFriendsModel = MyFriendsModel()

    func fetchMembersDetails(for competition: Competition) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        self.currentUserId = currentUserId
        self.isLoading = true
        self.error = nil
        
        myFriendsModel.fetchFriends { [weak self] in
            self?.fetchCompetitionMembers(for: competition)
        }
    }

    private func fetchCompetitionMembers(for competition: Competition) {
        db.collection("competitions").document(competition.id).collection("members")
            .getDocuments { [weak self] (snapshot, error) in
                if let error = error {
                    self?.handleError(error)
                    return
                }

                let userIds = snapshot?.documents.map { $0.documentID } ?? []
                self?.fetchUserDetails(for: userIds)
            }
    }

    private func fetchUserDetails(for userIds: [String]) {
        let group = DispatchGroup()
        var tempMembers: [MemberUser] = []

        for userId in userIds {
            group.enter()
            db.collection("users").document(userId).getDocument { [weak self] (document, error) in
                defer { group.leave() }
                
                if let error = error {
                    self?.handleError(error)
                    return
                }
                
                if let document = document, document.exists,
                   let data = document.data(),
                   let username = data["username"] as? String {
                    
                    let profileurl = data["profilePictureUrl"] as? String
                    let isAdded = self?.myFriendsModel.friends.contains(where: { $0.id == userId }) ?? false
                    let member = MemberUser(id: userId, username: username, profileurl: profileurl, isAdded: isAdded, justAdded: false)
                    tempMembers.append(member)
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
            self?.members = tempMembers.sorted(by: { $0.username < $1.username })
        }
    }

    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.error = error
            print("Error: \(error.localizedDescription)")
        }
    }

    func addFriend(member: MemberUser, completion: @escaping (Bool, Error?) -> Void) {
        let addFriendsModel = AddFriendsModel()
        addFriendsModel.addFriend(byUsername: member.username) { [weak self] success, error in
            if success {
                if let index = self?.members.firstIndex(where: { $0.id == member.id }) {
                    self?.members[index].isAdded = true
                    self?.members[index].justAdded = true
                }
                self?.myFriendsModel.fetchFriends()
                completion(true, nil)
                Analytics.shared.track(event: "friend_added", properties: ["source": "members_view"])
            } else {
                completion(false, error)
            }
        }
    }

    func leaveCompetition(competitionId: String, userId: String) {
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

            let memberRef = self.db.collection("competitions").document(competitionId).collection("members").document(userId)

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
