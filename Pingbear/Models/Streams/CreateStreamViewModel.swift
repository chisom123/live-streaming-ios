import SwiftUI
import FirebaseAuth
import FirebaseFunctions
import Combine
import FirebaseFirestore

// MARK: - CreateStreamViewModel
@MainActor
class CreateStreamViewModel: ObservableObject {

    @Published var selectedFriendIds:  Set<String> = []
    @Published var friendsSearchText:  String      = ""
    @Published var isSending                       = false
    @Published var isLoadingFriends                = false
    @Published var errorMessage:       String?     = nil
    @Published var friends:            [FriendContact] = []

    private let functions = Functions.functions()
    private let db        = Firestore.firestore()

    // MARK: - Filtered list

    var filteredFriends: [FriendContact] {
        guard !friendsSearchText.isEmpty else { return friends }
        return friends.filter {
            $0.name.localizedCaseInsensitiveContains(friendsSearchText) ||
            $0.username.localizedCaseInsensitiveContains(friendsSearchText)
        }
    }

    var hasNoSearchResults: Bool {
        !friendsSearchText.isEmpty && filteredFriends.isEmpty
    }

    var totalSelected: Int { selectedFriendIds.count }
    var canCreate:     Bool { totalSelected > 0 && !isSending }

    // MARK: - Refresh friends

    func refreshFriends() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoadingFriends = true

        db.collection("users").document(uid).collection("friends").getDocuments { [weak self] snap, _ in
            guard let self else { return }
            let ids = snap?.documents.map(\.documentID) ?? []

            guard !ids.isEmpty else {
                self.friends          = []
                self.isLoadingFriends = false
                return
            }

            let chunks = stride(from: 0, to: ids.count, by: 30).map {
                Array(ids[$0..<min($0 + 30, ids.count)])
            }
            var fetched: [FriendContact] = []
            let group = DispatchGroup()

            for chunk in chunks {
                group.enter()
                self.db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments { snap, _ in
                        defer { group.leave() }
                        let batch = snap?.documents.compactMap { doc -> FriendContact? in
                            let data = doc.data()
                            guard let name = data["name"] as? String else { return nil }
                            return FriendContact(
                                id:                doc.documentID,
                                name:              name,
                                username:          data["username"] as? String ?? "",
                                profilePictureUrl: data["profilePictureUrl"] as? String
                            )
                        } ?? []
                        fetched.append(contentsOf: batch)
                    }
            }

            group.notify(queue: .main) {
                self.friends          = fetched.sorted { $0.name < $1.name }
                self.isLoadingFriends = false
            }
        }
    }

    // MARK: - Create stream

    func createStream() async -> (streamId: String, token: String?, url: String?)? {
        guard canCreate else { return nil }
        isSending = true
        defer { isSending = false }

        let payload: [String: Any] = [
            "onAppInvitedIds":    Array(selectedFriendIds),
            "offAppPhoneHashes":  [],
            "offAppInviteeNames": [:]
        ]

        do {
            let result = try await functions.httpsCallable("createStream").call(payload)
            guard let data     = result.data as? [String: Any],
                  let streamId = data["streamId"] as? String
            else { throw NSError(domain: "Stream", code: -1) }

            let token = data["token"]      as? String
            let url   = data["livekitUrl"] as? String

            Analytics.shared.trackStreamCreated(
                streamId:     streamId,
                invitedCount: selectedFriendIds.count
            )
            return (streamId: streamId, token: token, url: url)
        } catch {
            errorMessage = error.localizedDescription
            Analytics.shared.trackError(message: error.localizedDescription,
                                        properties: ["context": "create_stream"])
            return nil
        }
    }

    // MARK: - Toggle

    func toggleFriend(_ id: String) {
        if selectedFriendIds.contains(id) {
            selectedFriendIds.remove(id)
        } else {
            selectedFriendIds.insert(id)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}
