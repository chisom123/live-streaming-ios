import SwiftUI
import Firebase
import FirebaseFirestore

struct Competition: Identifiable {
    let id: String
    let description: String
    let date: Date
}

class CompetitionsModel: ObservableObject {
    @Published var competitions: [Competition] = []

    init() {
        fetchCompetitions()
    }

    func fetchCompetitions() {
        let db = Firestore.firestore()

        db.collection("competitions")
            .whereField("timestamp", isGreaterThan: Timestamp(date: Calendar.current.date(byAdding: .hour, value: -24, to: Date())!))
            .order(by: "timestamp", descending: true) // Order by timestamp, newest first
            .getDocuments { [weak self] (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    var fetchedCompetitions = querySnapshot?.documents.compactMap { document -> Competition? in
                        let data = document.data()
                        guard let description = data["description"] as? String,
                              let timestamp = data["timestamp"] as? Timestamp else {
                                  return nil
                        }

                        return Competition(
                            id: document.documentID,
                            description: description,
                            date: timestamp.dateValue()
                        )
                    } ?? []
                    
                    DispatchQueue.main.async {
                        self?.competitions = fetchedCompetitions
                    }
                }
            }
    }

}
