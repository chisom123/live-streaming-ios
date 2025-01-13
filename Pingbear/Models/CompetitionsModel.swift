import FirebaseAuth
import FirebaseFirestore

class Competition: ObservableObject, Identifiable {
    let id: String
    private let db = Firestore.firestore()
    
    @Published var description: String
    @Published var date: Date
    @Published var entriesNotVotedCount: Int = 0
    @Published var isEvent: Bool = false
    @Published var isUserVerified: Bool = false
    
    init(id: String, description: String, date: Date, entriesNotVotedCount: Int = 0, isEvent: Bool = false) {
        self.id = id
        self.description = description
        self.date = date
        self.entriesNotVotedCount = entriesNotVotedCount
        self.isEvent = isEvent
    }
}

extension Competition {
    var hasStarted: Bool {
        guard let event = self as? Event else { return true }
        return Date() >= event.startDateTime
    }
    
    func checkVerificationStatus() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("competitions")
            .document(id)
            .collection("members")
            .document(userId)
            .getDocument { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isUserVerified = snapshot?.exists ?? false
                }
            }
    }
    
    func markUserAsVerified(userId: String) {
        db.collection("competitions")
            .document(id)
            .collection("members")
            .document(userId)
            .setData(["userId": userId])
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
        let group = DispatchGroup()
        
        // Variables to store results from parallel queries
        var eventIds = Set<String>()
        var competitionDocs: [QueryDocumentSnapshot]?
        
        // Fetch events in parallel
        group.enter()
        db.collection("events")
            .whereField(FieldPath.documentID(), in: ids)
            .getDocuments { (eventSnapshot, error) in
                defer { group.leave() }
                if let error = error {
                    print("Error fetching events: \(error)")
                    return
                }
                eventIds = Set(eventSnapshot?.documents.map { $0.documentID } ?? [])
            }
        
        // Fetch competitions in parallel
        group.enter()
        db.collection("competitions")
            .whereField(FieldPath.documentID(), in: ids)
            .getDocuments { [weak self] (snapshot, error) in
                defer { group.leave() }
                if let error = error {
                    print("Error batch fetching competitions: \(error)")
                    return
                }
                competitionDocs = snapshot?.documents
            }
        
        // Process results after both queries complete
        group.notify(queue: .global()) { [weak self] in
            guard let documents = competitionDocs else {
                completion()
                return
            }
            
            let competitions = documents.compactMap { doc -> Competition? in
                let data = doc.data()
                return Competition(
                    id: doc.documentID,
                    description: data["description"] as? String ?? "No Description",
                    date: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                    isEvent: eventIds.contains(doc.documentID)
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
        let twentyFourHoursAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        
        let group = DispatchGroup()
        var entryIds: Set<String> = []
        var votedEntryIds: Set<String> = []
        
        // Fetch both entries and votes in parallel
        group.enter()
        let entriesRef = db.collection("competitions").document(competitionId).collection("entries")
            .whereField("timestamp", isGreaterThan: Timestamp(date: twentyFourHoursAgo))
        
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
}
