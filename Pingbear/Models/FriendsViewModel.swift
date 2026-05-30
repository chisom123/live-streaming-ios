import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

// ─────────────────────────────────────────────────────────────
// MARK: - FriendsViewModel
//
// Owns the friends list shown on the home screen.
// Also handles session creation and call initiation
// when the user selects friends and taps Call.
// ─────────────────────────────────────────────────────────────

class FriendsViewModel: ObservableObject {

    @Published var friends: [Friend] = []
    @Published var isLoading = false
    @Published var isStartingCall = false
    @Published var errorMessage: String? = nil

    private let db        = Firestore.firestore()
    private let functions = Functions.functions()
    private let currentUserId = Auth.auth().currentUser?.uid ?? ""

    // ─────────────────────────────────────────────────────────
    // MARK: - Fetch Friends
    // ─────────────────────────────────────────────────────────

    func fetchFriends() {
        guard !currentUserId.isEmpty else { return }
        isLoading = true

        db.collection("users").document(currentUserId)
            .collection("friends")
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = error.localizedDescription
                    }
                    return
                }

                let friendIds = snapshot?.documents.map(\.documentID) ?? []
                self.fetchFriendDetails(ids: friendIds)
            }
    }

    private func fetchFriendDetails(ids: [String]) {
        guard !ids.isEmpty else {
            DispatchQueue.main.async {
                self.friends   = []
                self.isLoading = false
            }
            return
        }

        let chunks = stride(from: 0, to: ids.count, by: 30).map {
            Array(ids[$0..<min($0 + 30, ids.count)])
        }

        var fetched: [Friend] = []
        let group = DispatchGroup()

        for chunk in chunks {
            group.enter()
            db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments { snapshot, _ in
                    defer { group.leave() }
                    guard let docs = snapshot?.documents else { return }

                    let friends = docs.compactMap { doc -> Friend? in
                        let data = doc.data()
                        guard let name = data["name"] as? String else { return nil }
                        return Friend(
                            id:                doc.documentID,
                            name:              name,
                            username:          data["username"] as? String ?? "",
                            profilePictureUrl: data["profilePictureUrl"] as? String
                        )
                    }
                    fetched.append(contentsOf: friends)
                }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.friends   = fetched.sorted { $0.name < $1.name }
            self.isLoading = false
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Start Call
    //
    // 1. Create session in Firestore
    // 2. Send CallKit VoIP invites to selected friends
    // 3. Return sessionId so the caller can join LiveKit room
    //
    // completion receives the sessionId on success, nil on failure.
    // ─────────────────────────────────────────────────────────

    func startCall(
        friendIds: [String],
        completion: @escaping (String?) -> Void
    ) {
        guard !isStartingCall else { return }
        isStartingCall = true

        // Step 1 — create session, passing friendIds so invited_ids is stored
        functions.httpsCallable("createSession").call(["friendIds": friendIds]) { [weak self] result, error in
            guard let self else { return }

            if let error {
                DispatchQueue.main.async {
                    self.isStartingCall = false
                    self.errorMessage   = error.localizedDescription
                    completion(nil)
                }
                return
            }

            guard let sessionId = (result?.data as? [String: Any])?["session_id"] as? String else {
                DispatchQueue.main.async {
                    self.isStartingCall = false
                    self.errorMessage   = "Failed to create session"
                    completion(nil)
                }
                return
            }

            // Step 2 — send CallKit invites to selected friends
            let inviteParams: [String: Any] = [
                "sessionId": sessionId,
                "friendIds": friendIds
            ]

            self.functions.httpsCallable("sendCallInvite").call(inviteParams) { _, error in
                if let error {
                    print("FriendsViewModel: sendCallInvite error (non-fatal): \(error)")
                    // Non-fatal — session exists, call can proceed
                }
            }

            // Step 3 — return sessionId to caller
            DispatchQueue.main.async {
                self.isStartingCall = false
                completion(sessionId)
            }
        }
    }
}
