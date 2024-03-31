import SwiftUI
import Firebase
import FirebaseFirestore
import Combine

class Competition: ObservableObject, Identifiable {
    let id: String
    
    @Published var description: String
    @Published var date: Date
    @Published var entriesNotVotedCount: Int = 0
    @Published var username: String = "" // Add this line
    @Published var allow_join: [String] = []
    @Published var allow_vote: [String] = []
    @Published var userId: String // Add this line

    init(id: String, description: String, date: Date, entriesNotVotedCount: Int = 0, username: String = "", allow_join: [String] = [], allow_vote: [String] = [], userId: String) {
        self.id = id
        self.description = description
        self.date = date
        self.entriesNotVotedCount = entriesNotVotedCount
        self.username = username
        self.allow_join = allow_join
        self.allow_vote = allow_vote
        self.userId = userId // Initialize userId
    }
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
                              let timestamp = data["timestamp"] as? Timestamp,
                              let creatorUserId = data["userID"] as? String else { // Assuming 'userId' is the field for the competition creator
                            group.leave()
                            return
                        }
                        
                        let allowJoin = data["allow_join"] as? [String] ?? []
                        let allowVote = data["allow_vote"] as? [String] ?? []

                        // Fetch the username for the competition creator
                        db.collection("users").document(creatorUserId).getDocument { (userDoc, err) in
                            var username = "Unknown" // Default username if not found or error
                            if let userDoc = userDoc, let userData = userDoc.data(), let fetchedUsername = userData["username"] as? String {
                                username = fetchedUsername
                            }

                            var competition = Competition(
                                id: competitionId,
                                description: description,
                                date: timestamp.dateValue(),
                                username: username,
                                allow_join: allowJoin,
                                allow_vote: allowVote,
                                userId: creatorUserId
                            )
                            
                            let twentyFourHoursAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date())
                            let twentyFourHoursAgoTimestamp = Timestamp(date: twentyFourHoursAgo!)

                            // Fetch total entries for the competition
                            db.collection("competitions").document(competitionId).collection("entries")
                                .whereField("timestamp", isGreaterThanOrEqualTo: twentyFourHoursAgoTimestamp)
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
                    let creatorUserId = document.data()["userID"] as? String ?? "" // Assuming 'userId' is the field for the competition creator

                    // Fetch the username for the competition creator
                    db.collection("users").document(creatorUserId).getDocument { (userDoc, err) in
                        var username = "Unknown" // Default username if not found or error
                        if let userDoc = userDoc, let userData = userDoc.data(), let fetchedUsername = userData["username"] as? String {
                            username = fetchedUsername
                        }

                        // Proceed with fetching competition details
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
                                    
                                    let allowJoin = data["allow_join"] as? [String] ?? []
                                    let allowVote = data["allow_vote"] as? [String] ?? []

                                    var competition = Competition(
                                        id: competitionId,
                                        description: description,
                                        date: timestamp.dateValue(),
                                        username: username,
                                        allow_join: allowJoin,
                                        allow_vote: allowVote,
                                        userId: creatorUserId
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
                }

                group.notify(queue: .main) { // When all async tasks are completed
                    self?.competitions = temporaryCompetitions.sorted { $0.date > $1.date } // Sort in descending order
                }
            }
    }

    // Separated function to fetch competition entries
    private func fetchCompetitionEntries(competitionId: String, userId: String, db: Firestore, completion: @escaping (EntriesInfo) -> Void) {
        let twentyFourHoursAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        let twentyFourHoursAgoTimestamp = Timestamp(date: twentyFourHoursAgo!)
        
        db.collection("competitions").document(competitionId).collection("entries")
            .whereField("timestamp", isGreaterThanOrEqualTo: twentyFourHoursAgoTimestamp)
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
