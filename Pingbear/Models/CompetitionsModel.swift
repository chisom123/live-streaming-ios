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
    @Published var isLoading = true
    
    var badgeCount = 0 {
        didSet {
            // Set the application icon badge number on the main thread
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = self.badgeCount
            }
        }
    }
    
    private var loadingDebounceTimer: Timer?
    
    func setupCompetitionListeners(userId: String) {
        isLoading = true
        
        let path = "groupMemberships/\(userId)/competitions"
        FirestoreListenerManager.shared.addListener(for: path) { [weak self] changes in
            guard let self = self else { return }
            
            if changes.isEmpty {
                self.debounceEndLoading()
                return
            }
            
            for change in changes {
                switch change.type {
                case .added, .modified:
                    if let competitionId = change.document.data()["competitionId"] as? String {
                        self.fetchCompetitionDetailsAndCalculateVotes(competitionId: competitionId, userId: userId) {
                            self.debounceEndLoading()
                        }
                    }
                case .removed:
                    self.removeCompetition(change.document.documentID)
                    self.debounceEndLoading()
                }
            }
        }
    }
    
    private func debounceEndLoading() {
        loadingDebounceTimer?.invalidate()
        loadingDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isLoading = false
            }
        }
    }
    
    func removeCompetition(_ competitionId: String) {
        setupCompetitionListeners(userId: Auth.auth().currentUser?.uid ?? "")
    }
    
    func fetchCompetitionDetailsAndCalculateVotes(competitionId: String, userId: String, completion: @escaping () -> Void) {
        let db = Firestore.firestore()
        db.collection("competitions").document(competitionId).getDocument { [weak self] (documentSnapshot, err) in
            guard let self = self, let documentSnapshot = documentSnapshot, let data = documentSnapshot.data() else {
                print("Error or missing data in competition document: \(err?.localizedDescription ?? "Unknown error")")
                return
            }
            let competition = Competition(
                id: documentSnapshot.documentID,
                description: data["description"] as? String ?? "No Description",
                date: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                entriesNotVotedCount: 0  // Default count
            )
            self.setupEntriesListener(competition: competition, userId: userId)
            completion()
        }
    }
    
    func setupEntriesListener(competition: Competition, userId: String) {
        let path = "competitions/\(competition.id)/entries"
        let twentyFourHoursAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        // Setup listener with FirestoreListenerManager for entries
        FirestoreListenerManager.shared.addListener(for: path) { [weak self] changes in
            guard let self = self else { return }
            
            // Filter and process entry document changes based on the timestamp
            let entryIds = changes.filter {
                guard let timestamp = $0.document.data()["timestamp"] as? Timestamp else { return false }
                return timestamp.dateValue() >= twentyFourHoursAgo
            }.map { $0.document.documentID }

            let allEntryIds = Set(entryIds)

            // Proceed to fetch votes
            self.fetchVotesAndUpdateCompetition(userId: userId, competition: competition, entryIds: allEntryIds)
        }
    }

    func fetchVotesAndUpdateCompetition(userId: String, competition: Competition, entryIds: Set<String>) {
        let votesPath = "groupMemberships/\(userId)/competitions/\(competition.id)/votes"
        FirestoreListenerManager.shared.addListener(for: votesPath) { [weak self] changes in
            let votedEntryIds = Set(changes.compactMap { $0.document.data()["entryId"] as? String })
            let notVotedEntriesCount = entryIds.subtracting(votedEntryIds).count

            DispatchQueue.main.async {
                competition.entriesNotVotedCount = notVotedEntriesCount
                self?.updateOrAppendCompetition(competition)
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
    
    func cleanupListeners() {
        for competition in competitions {
            let path = "competitions/\(competition.id)/entries"
            FirestoreListenerManager.shared.removeListener(for: path)
            let votesPath = "groupMemberships/\(Auth.auth().currentUser?.uid ?? "")/competitions/\(competition.id)/votes"
            FirestoreListenerManager.shared.removeListener(for: votesPath)
        }
        let membershipsPath = "groupMemberships/\(Auth.auth().currentUser?.uid ?? "")/competitions"
        FirestoreListenerManager.shared.removeListener(for: membershipsPath)
    }
}
