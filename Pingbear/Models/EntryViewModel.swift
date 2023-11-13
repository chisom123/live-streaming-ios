import SwiftUI
import Firebase
import FirebaseFirestore

struct Entry: Identifiable {
    let id: String
    let imageUrl: String
}

class EntryViewModel: ObservableObject {
    @Published var entries: [Entry] = []
    var competitionId: String // Add a property to store the competition ID
    @Published var currentIndex: Int = 0

    init(competitionId: String) {
        self.competitionId = competitionId
        fetchEntries()
    }

    func fetchEntries() {
        let db = Firestore.firestore()
        db.collection("competitions").document(competitionId).collection("entries").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error getting entries: \(error)")
                return
            }

            if let documents = snapshot?.documents {
                self.entries = documents.map { document in
                    // Assuming each entry document has an 'imageUrl' field
                    let imageUrl = document.data()["imageUrl"] as? String ?? ""
                    return Entry(id: document.documentID, imageUrl: imageUrl)
                }
            }
        }
    }
}
