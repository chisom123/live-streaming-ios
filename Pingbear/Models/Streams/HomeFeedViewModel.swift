import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - StreamIDItem
struct StreamIDItem: Identifiable {
    let id:    String
    let token: String?
    let url:   String?
}

// MARK: - HomeFeedViewModel
@MainActor
class HomeFeedViewModel: ObservableObject {

    @Published var liveStreams:  [StreamModel] = []
    @Published var isLoading     = false
    @Published var errorMessage: String?       = nil

    private let db            = Firestore.firestore()
    private var listener:       ListenerRegistration?
    private let currentUserId = Auth.auth().currentUser?.uid ?? ""

    func startListening() {
        guard !currentUserId.isEmpty else { return }
        isLoading = true
        listener = db.collection("streams")
            .whereField("invited_user_ids", arrayContains: currentUserId)
            .whereField("status", isEqualTo: "live")
            .addSnapshotListener { [weak self] snap, error in
                guard let self else { return }
                self.isLoading = false
                if let error { self.errorMessage = error.localizedDescription; return }
                self.liveStreams = snap?.documents.compactMap { StreamModel.from($0) } ?? []
                self.liveStreams.sort { ($0.startedAt ?? .distantPast) < ($1.startedAt ?? .distantPast) }
            }
    }

    func stopListening() { listener?.remove(); listener = nil }
}
