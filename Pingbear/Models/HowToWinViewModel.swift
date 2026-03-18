import Foundation
import FirebaseAuth
import FirebaseFirestore

class HowToWinViewModel: ObservableObject {
    @Published var displayName: String = ""
    @Published var profilePictureUrl: String? = nil
    @Published var totalStars: Int = 0

    func load() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()

        db.collection("users").document(userId).getDocument { [weak self] document, error in
            guard let self = self, let data = document?.data() else { return }

            DispatchQueue.main.async {
                self.displayName = data["name"] as? String ?? data["username"] as? String ?? ""
                self.profilePictureUrl = data["profilePictureUrl"] as? String
            }

            guard let potId = data["active_pot_id"] as? String, !potId.isEmpty else { return }

            db.collection("global_pots")
                .document(potId)
                .collection("participants")
                .whereField("user_id", isEqualTo: userId)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self,
                          let document = snapshot?.documents.first else { return }

                    DispatchQueue.main.async {
                        self.totalStars = document.data()["total_stars"] as? Int ?? 0
                    }
                }
        }
    }
}
