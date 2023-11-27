import SwiftUI
import Firebase
import FirebaseFirestore

struct Competition: Identifiable {
    let id: String
    let description: String
    let date: Date
    var entriesNotVotedCount: Int = 0 // New property to indicate the number of entries not yet voted on
}

class CompetitionsModel: ObservableObject {
    @Published var competitions: [Competition] = []

    func fetchCompetitions() {
        let db = Firestore.firestore()
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No user logged in")
            return
        }

        db.collection("competitions")
            .whereField("timestamp", isGreaterThan: Timestamp(date: Calendar.current.date(byAdding: .hour, value: -24, to: Date())!))
            .order(by: "timestamp", descending: true)
            .getDocuments { [weak self] (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    var temporaryCompetitions: [Competition] = []
                    let group = DispatchGroup()

                    querySnapshot?.documents.forEach { document in
                        group.enter()
                        let competitionId = document.documentID
                        let data = document.data()
                        guard let description = data["description"] as? String,
                              let timestamp = data["timestamp"] as? Timestamp else {
                            group.leave()
                            return
                        }

                        var competition = Competition(
                            id: competitionId,
                            description: description,
                            date: timestamp.dateValue()
                        )

                        // Fetch total entries for the competition
                        db.collection("competitions").document(competitionId).collection("entries")
                          .getDocuments { (entriesSnapshot, err) in
                              if let entriesSnapshot = entriesSnapshot {
                                  let entries = entriesSnapshot.documents
                                  let totalEntriesCount = entries.count
                                  let userEntriesCount = entries.filter { $0.data()["userId"] as? String == userId }.count

                                  // Fetch voted entries for the user in this competition
                                  let participantRef = db.collection("competitions").document(competitionId).collection("participants").document(userId)
                                  participantRef.getDocument { (participantSnapshot, err) in
                                      let votedEntries = participantSnapshot?.data()?["voted_entries"] as? [String] ?? []
                                      let notVotedCount = totalEntriesCount - votedEntries.count - userEntriesCount

                                      competition.entriesNotVotedCount = notVotedCount
                                      temporaryCompetitions.append(competition)
                                      group.leave()
                                  }
                              } else {
                                  group.leave()
                              }
                          }
                    }

                    group.notify(queue: .main) {
                        self?.competitions = temporaryCompetitions.sorted { $0.date > $1.date }
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

        guard let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) else {
            print("Error calculating date")
            return
        }

        db.collection("competitions")
            .whereField("timestamp", isGreaterThan: Timestamp(date: twentyFourHoursAgo))
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
                            if let err = err {
                                print("Error getting participant data: \(err)")
                                group.leave()
                                return
                            }

                            if let participantSnapshot = participantSnapshot, participantSnapshot.exists {
                                let data = document.data()
                                guard let description = data["description"] as? String,
                                      let timestamp = data["timestamp"] as? Timestamp else {
                                          group.leave()
                                          return
                                }

                                var competition = Competition(
                                    id: competitionId,
                                    description: description,
                                    date: timestamp.dateValue()
                                )

                                self?.fetchCompetitionEntries(competitionId: competitionId, userId: userId, db: db) { entriesInfo in
                                    competition.entriesNotVotedCount = entriesInfo.notVotedCount
                                    temporaryCompetitions.append(competition)
                                    group.leave()
                                }
                            } else {
                                group.leave()
                            }
                        }
                }

                group.notify(queue: .main) { // When all async tasks are completed
                    self?.competitions = temporaryCompetitions.sorted { $0.date > $1.date } // Sort in descending order
                }
            }
    }

    // Separated function to fetch competition entries
    private func fetchCompetitionEntries(competitionId: String, userId: String, db: Firestore, completion: @escaping (EntriesInfo) -> Void) {
        db.collection("competitions").document(competitionId).collection("entries")
            .getDocuments { (entriesSnapshot, err) in
                if let err = err {
                    print("Error getting entries: \(err)")
                    completion(EntriesInfo(notVotedCount: 0))
                    return
                }

                guard let entriesSnapshot = entriesSnapshot else {
                    completion(EntriesInfo(notVotedCount: 0))
                    return
                }

                let entries = entriesSnapshot.documents
                let totalEntriesCount = entries.count
                let userEntriesCount = entries.filter { $0.data()["userId"] as? String == userId }.count

                let participantRef = db.collection("competitions").document(competitionId).collection("participants").document(userId)
                participantRef.getDocument { (participantSnapshot, err) in
                    if let err = err {
                        print("Error getting participant document: \(err)")
                        completion(EntriesInfo(notVotedCount: 0))
                        return
                    }

                    let votedEntries = participantSnapshot?.data()?["voted_entries"] as? [String] ?? []
                    let notVotedCount = totalEntriesCount - votedEntries.count - userEntriesCount

                    completion(EntriesInfo(notVotedCount: notVotedCount))
                }
            }
    }

    struct EntriesInfo {
        let notVotedCount: Int
    }

}
