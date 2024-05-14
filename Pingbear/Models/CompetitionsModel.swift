import SwiftUI
import Firebase
import FirebaseFirestore
import Combine

class Competition: ObservableObject, Identifiable {
    let id: String
    
    @Published var description: String
    @Published var date: Date
    @Published var entriesNotVotedCount: Int = 0
    
    init(id: String, description: String, date: Date, entriesNotVotedCount: Int = 0) {
        self.id = id
        self.description = description
        self.date = date
        self.entriesNotVotedCount = entriesNotVotedCount
    }
}

class CompetitionsModel: ObservableObject {
    @Published var competitions: [Competition] = []
    var listeners: [ListenerRegistration] = []
    
    func setupCompetitionListeners(userId: String) {
        let db = Firestore.firestore()
        let competitionListener = db.collection("competitions").addSnapshotListener { [weak self] (querySnapshot, error) in
            guard let self = self, let snapshot = querySnapshot else {
                print("Error fetching competitions: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            snapshot.documents.forEach { document in
                let participantListener = self.checkIfUserIsParticipant(competitionId: document.documentID, userId: userId) { isParticipant in
                    if isParticipant {
                        self.fetchCompetitionDetailsAndCalculateVotes(competitionId: document.documentID, userId: userId)
                    }
                }
                self.listeners.append(participantListener)
            }
        }
        listeners.append(competitionListener)
    }
    
    func checkIfUserIsParticipant(competitionId: String, userId: String, completion: @escaping (Bool) -> Void) -> ListenerRegistration {
        let db = Firestore.firestore()
        let participantRef = db.collection("competitions").document(competitionId).collection("participants").document(userId)
        
        let listener = participantRef.addSnapshotListener { documentSnapshot, error in
            guard let documentSnapshot = documentSnapshot, error == nil else {
                print("Error listening to participant updates: \(error?.localizedDescription ?? "Unknown error")")
                completion(false)
                return
            }
            completion(documentSnapshot.exists)
        }
        
        return listener
    }

    
    func fetchCompetitionDetailsAndCalculateVotes(competitionId: String, userId: String) {
        let db = Firestore.firestore()
        db.collection("competitions").document(competitionId).getDocument { [weak self] (documentSnapshot, err) in
            guard let self = self, let documentSnapshot = documentSnapshot, let data = documentSnapshot.data() else {
                print("Error or missing data in competition document: \(err?.localizedDescription ?? "Unknown error")")
                return
            }
            let competition = Competition(
                id: documentSnapshot.documentID,
                description: data["description"] as? String ?? "No Description",
                date: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            )
            self.setupEntriesListener(competition: competition, userId: userId)
        }
    }
    
    func setupEntriesListener(competition: Competition, userId: String) {
        let db = Firestore.firestore()
        let twentyFourHoursAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let twentyFourHoursAgoTimestamp = Timestamp(date: twentyFourHoursAgo)
        
        let entriesListener = db.collection("competitions").document(competition.id).collection("entries")
            .whereField("timestamp", isGreaterThanOrEqualTo: twentyFourHoursAgoTimestamp)
            .addSnapshotListener { [weak self] (entriesSnapshot, error) in
                if let err = error {
                    print("Error getting entries: \(err)")
                    return
                }

                guard let entries = entriesSnapshot?.documents else { return }
                let entryIds = Set(entries.map { $0.documentID })
                let totalEntriesCount = entries.count

                let votesListener = db.collection("competitions").document(competition.id).collection("participants")
                  .document(userId).addSnapshotListener { (participantSnapshot, err) in
                    if let err = err {
                        print("Error getting participant details: \(err)")
                        return
                    }

                    let votedEntries = participantSnapshot?.data()?["voted_entries"] as? [String] ?? []
                    let validVotedEntries = votedEntries.filter { entryIds.contains($0) }
                    let notVotedCount = totalEntriesCount - validVotedEntries.count

                    DispatchQueue.main.async {
                        competition.entriesNotVotedCount = notVotedCount
                        self?.updateOrAppendCompetition(competition)
                    }
                }
                self?.listeners.append(votesListener)
            }
        listeners.append(entriesListener)
    }
    
    func updateOrAppendCompetition(_ competition: Competition) {
        DispatchQueue.main.async {
            if let index = self.competitions.firstIndex(where: { $0.id == competition.id }) {
                // Update existing competition
                self.competitions[index] = competition
            } else {
                // Append new competition
                self.competitions.append(competition)
            }
        }
    }

    func deactivateListeners() {
        for listener in listeners {
            listener.remove()
        }
        listeners.removeAll()
    }
}
