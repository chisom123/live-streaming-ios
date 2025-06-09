import FirebaseAuth
import FirebaseFirestore

class Competition: ObservableObject, Identifiable {
    let id: String
    private let db = Firestore.firestore()
    
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
    
    func setupCompetitionListeners(userId: String, completion: (() -> Void)? = nil) {
        let path = "groupMemberships/\(userId)/competitions"
        
        FirestoreListenerManager.shared.addListener(for: path) { [weak self] changes in
            var competitionIds: [String] = []
            
            // Collect all competition IDs first
            for change in changes {
                if case .added = change.type,
                   let competitionId = change.document.data()["competitionId"] as? String {
                    competitionIds.append(competitionId)
                } else if case .removed = change.type,
                          let competitionId = change.document.data()["competitionId"] as? String {
                    DispatchQueue.main.async {
                        self?.competitions.removeAll { $0.id == competitionId }
                    }
                }
            }
            
            if !competitionIds.isEmpty {
                self?.batchFetchCompetitions(ids: competitionIds, userId: userId) {
                    completion?()
                }
            } else {
                completion?()
            }
        }
    }
    
    private func batchFetchCompetitions(ids: [String], userId: String, completion: @escaping () -> Void) {
        let db = Firestore.firestore()
        
        // Fetch competitions
        db.collection("competitions")
            .whereField(FieldPath.documentID(), in: ids)
            .getDocuments { [weak self] (snapshot, error) in
                if let error = error {
                    print("Error batch fetching competitions: \(error)")
                    completion()
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion()
                    return
                }
                
                let competitions = documents.compactMap { doc -> Competition? in
                    let data = doc.data()
                    return Competition(
                        id: doc.documentID,
                        description: data["description"] as? String ?? "No Description",
                        date: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
                
                // Update competitions and fetch entry counts in parallel
                let updateGroup = DispatchGroup()
                for competition in competitions {
                    updateGroup.enter()
                    DispatchQueue.main.async {
                        self?.updateOrAppendCompetition(competition)
                        self?.refreshEntriesAndVotes(for: competition.id, userId: userId) {
                            updateGroup.leave()
                        }
                    }
                }
                
                updateGroup.notify(queue: .main) {
                    completion()
                }
            }
    }
    
    func refreshEntriesAndVotes(for competitionId: String, userId: String, completion: (() -> Void)? = nil) {
        guard let competition = competitions.first(where: { $0.id == competitionId }) else {
            completion?()
            return
        }
        
        let db = Firestore.firestore()
        
        let group = DispatchGroup()
        var entryIds: Set<String> = []
        var votedEntryIds: Set<String> = []
        
        // Fetch both entries and votes in parallel
        group.enter()
        let entriesRef = db.collection("competitions").document(competitionId).collection("entries")
        
        entriesRef.getDocuments { snapshot, error in
            defer { group.leave() }
            
            if let error = error {
                print("Error fetching entries: \(error)")
                return
            }
            
            entryIds = Set(
                snapshot?.documents
                    .filter { doc in
                        let entryUserId = doc.data()["userId"] as? String ?? ""
                        return entryUserId != userId  // Exclude entries where userId matches current user
                    }
                    .map { $0.documentID } ?? []
            )
        }
        
        group.enter()
        let votesRef = db.collection("groupMemberships").document(userId)
            .collection("competitions").document(competitionId)
            .collection("votes")
        
        votesRef.getDocuments { snapshot, error in
            defer { group.leave() }
            
            if let error = error {
                print("Error fetching votes: \(error)")
                return
            }
            
            votedEntryIds = Set(snapshot?.documents.compactMap { $0.data()["entryId"] as? String } ?? [])
        }
        
        group.notify(queue: .main) { [weak self] in
            let notVotedEntriesCount = entryIds.subtracting(votedEntryIds).count
            competition.entriesNotVotedCount = notVotedEntriesCount
            completion?()
        }
    }
    
    func updateOrAppendCompetition(_ competition: Competition) {
        if let index = competitions.firstIndex(where: { $0.id == competition.id }) {
            competitions[index] = competition
        } else {
            competitions.append(competition)
        }
    }
    
    func cleanupListeners() {
        let membershipsPath = "groupMemberships/\(Auth.auth().currentUser?.uid ?? "")/competitions"
        FirestoreListenerManager.shared.removeListener(for: membershipsPath)
    }
    
    func refreshCompetitions() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Clean up existing listeners to avoid duplicates
        cleanupListeners()
        
        // Re-setup listeners which will automatically refresh the data
        setupCompetitionListeners(userId: userId)
    }
}
