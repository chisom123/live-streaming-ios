import SwiftUI
import Firebase
import FirebaseFirestore
import Combine
import UserNotifications

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
    
    var badgeCount = 0 {
        didSet {
            // Set the application icon badge number on the main thread
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = self.badgeCount
            }
        }
    }
    
    func setupCompetitionListeners(userId: String) {
        let db = Firestore.firestore()
        db.collection("groupMemberships").document(userId).collection("competitions")
            .getDocuments { [weak self] (snapshot, error) in
                guard let self = self else {
                    print("Self is nil")
                    return
                }
                
                if let error = error {
                    print("Error fetching group memberships: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("No snapshot data available")
                    return
                }
                
                // Process each document to fetch details
                snapshot.documents.forEach { document in
                    if let competitionId = document.data()["competitionId"] as? String {
                        self.fetchCompetitionDetailsAndCalculateVotes(competitionId: competitionId, userId: userId)
                    }
                }
            }
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
        let entriesRef = db.collection("competitions").document(competition.id).collection("entries")
        let twentyFourHoursAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let twentyFourHoursAgoTimestamp = Timestamp(date: twentyFourHoursAgo)
        
        entriesRef.whereField("timestamp", isGreaterThanOrEqualTo: twentyFourHoursAgoTimestamp)
            .getDocuments { [weak self] (snapshot, error) in
                guard let self = self, let snapshot = snapshot else {
                    print("Error fetching entries: \(error?.localizedDescription ?? "no error provided")")
                    return
                }
                let allEntryIds = Set(snapshot.documents.map { $0.documentID })

                // Fetch all votes by this user for this competition
                let votesRef = db.collection("groupMemberships").document(userId)
                    .collection("competitions").document(competition.id)
                    .collection("votes")

                votesRef.getDocuments { (voteSnapshot, voteError) in
                    guard let votedDocuments = voteSnapshot?.documents else {
                        print("Error fetching votes: \(voteError?.localizedDescription ?? "no error provided")")
                        return
                    }
                    let votedEntryIds = Set(votedDocuments.map { $0.data()["entryId"] as? String ?? "" })
                    let notVotedEntriesCount = allEntryIds.subtracting(votedEntryIds).count

                    DispatchQueue.main.async {
                        competition.entriesNotVotedCount = notVotedEntriesCount
                        self.updateOrAppendCompetition(competition)
                    }
                }
            }
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
            self.recalculateBadgeCount()
        }
    }

    func recalculateBadgeCount() {
        badgeCount = competitions.reduce(0) { $0 + $1.entriesNotVotedCount }
    }
}
