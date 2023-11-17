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

    func fetchUserCompetitions() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No user logged in")
            return
        }

        let db = Firestore.firestore()
        var temporaryCompetitions: [Competition] = [] // Temporary storage for competitions

        db.collection("competitions")
            .getDocuments { [weak self] (querySnapshot, err) in
                if let err = err {
                    print("Error getting competitions: \(err)")
                    return
                }

                guard let documents = querySnapshot?.documents else {
                    return
                }

                let group = DispatchGroup() // Use a dispatch group to track async tasks

                for document in documents {
                    group.enter() // Enter the group for each async task

                    let competitionId = document.documentID

                    document.reference.collection("participants")
                        .document(userId)
                        .getDocument { (participantSnapshot, err) in
                            defer { group.leave() } // Leave the group after each async task

                            if let participantSnapshot = participantSnapshot, participantSnapshot.exists {
                                let data = document.data()
                                guard let description = data["description"] as? String,
                                      let timestamp = data["timestamp"] as? Timestamp else {
                                          return
                                }

                                let competition = Competition(
                                    id: competitionId,
                                    description: description,
                                    date: timestamp.dateValue()
                                )

                                temporaryCompetitions.append(competition)
                            }
                        }
                }

                group.notify(queue: .main) { // When all async tasks are completed
                    self?.competitions = temporaryCompetitions.sorted { $0.date > $1.date } // Sort in descending order
                }
            }
    }


}
