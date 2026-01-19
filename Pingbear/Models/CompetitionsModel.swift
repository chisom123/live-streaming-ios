import FirebaseAuth
import FirebaseFirestore

class Competition: ObservableObject, Identifiable {
    let id: String
    private let db = Firestore.firestore()
    
    @Published var description: String
    @Published var date: Date
    
    init(id: String, description: String, date: Date) {
        self.id = id
        self.description = description
        self.date = date
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
                self?.batchFetchCompetitions(ids: competitionIds) {
                    completion?()
                }
            } else {
                completion?()
            }
        }
    }
    
    private func batchFetchCompetitions(ids: [String], completion: @escaping () -> Void) {
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
                
                // Update competitions on main thread
                DispatchQueue.main.async {
                    for competition in competitions {
                        self?.updateOrAppendCompetition(competition)
                    }
                    completion()
                }
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
