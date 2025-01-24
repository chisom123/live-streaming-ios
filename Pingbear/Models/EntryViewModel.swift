import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct Entry: Identifiable {
    let id: String
    let photoUrl: String
    let userName: String
    let stars: Int
    let isCurrentUser: Bool
    let isSuperstar: Bool
    let creationDate: Date
    let overlayText: String?
    let overlayVerticalPosition: CGFloat
    let isFromCamera: Bool
}

struct UserEntry: Identifiable {
    let id: String
    let userName: String
    var totalStars: Int
}

class EntryViewModel: ObservableObject {
    @Published var entries: [Entry] = []
    @Published var userLeaderboard: [UserEntry] = []
    @Published var hasEntriesToVoteOn: Bool = false
    var competitionId: String
    @Published var currentIndex: Int = 0
    @Published var totalMemberCount: Int = 0
    
    private var allEntryIds: Set<String> = Set()
    private var votedEntryIds: Set<String> = Set()
    
    private let db = Firestore.firestore()
    
    enum FetchEntriesMode {
        case entryView
        case compDetailsView
    }

    init(competitionId: String, mode: FetchEntriesMode) {
        self.competitionId = competitionId
        fetchEntries(mode: mode)
        setupListeners(mode: mode)
        if mode == .compDetailsView {
            fetchMemberCount()
        }
    }
    
    deinit {
        removeListeners()
    }
    
    func setupListeners(mode: FetchEntriesMode) {
        setupEntriesListener()
        setupVotesListener()
    }

    private func setupEntriesListener() {
        let entriesPath = "competitions/\(competitionId)/entries"

        // Calculate the time 24 hours ago from now using Calendar
        guard let twentyFourHoursAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()),
              let currentUserId = Auth.auth().currentUser?.uid else {
            print("Could not compute the date 24 hours ago or get current user ID.")
            return
        }
        
        // Create query with server-side filters
        let query = db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .whereField("timestamp", isGreaterThan: Timestamp(date: twentyFourHoursAgo))
            .whereField("userId", isNotEqualTo: currentUserId)
        
        FirestoreListenerManager.shared.addQueryListener(for: query, path: entriesPath) { [weak self] changes in
            let newEntryIds = Set(changes
                .filter { $0.type == .added }
                .map { $0.document.documentID })
            
            self?.allEntryIds.formUnion(newEntryIds)
            self?.updateVoteStatus()
        }
    }

    private func setupVotesListener() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("No current user ID found for votes listener setup.")
            return
        }

        let votesPath = "groupMemberships/\(currentUserId)/competitions/\(competitionId)/votes"
        FirestoreListenerManager.shared.addListener(for: votesPath) { [weak self] changes in
            let ids = changes.compactMap { $0.document.data()["entryId"] as? String }
            self?.votedEntryIds = Set(ids)
            self?.updateVoteStatus()
        }
    }

    private func updateVoteStatus() {
        DispatchQueue.main.async {
            let hasEntries = !self.allEntryIds.isEmpty
            let hasUnvotedEntries = !self.allEntryIds.subtracting(self.votedEntryIds).isEmpty
            self.hasEntriesToVoteOn = hasEntries && hasUnvotedEntries
        }
    }

    func removeListeners() {
        // Create an array of paths for which listeners need to be removed
        let paths = [
            "competitions/\(competitionId)/entries",
            getVotesPath()
        ]

        // Remove each listener
        paths.forEach { path in
            FirestoreListenerManager.shared.removeListener(for: path)
        }
    }

    private func getVotesPath() -> String {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            fatalError("No current user ID found.")
        }
        return "groupMemberships/\(currentUserId)/competitions/\(competitionId)/votes"
    }
    
    func fetchEntries(mode: FetchEntriesMode, completion: (() -> Void)? = nil) {
        guard let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) else {
            print("Error calculating date 24 hours ago")
            completion?()
            return
        }
        
        let collection = db.collection("competitions").document(competitionId).collection("entries")
        let query = collection.whereField("timestamp", isGreaterThan: Timestamp(date: twentyFourHoursAgo))
        
        if mode == .entryView {
            fetchEntryViewEntries(query: query, completion: completion)
        } else {
            fetchCompDetailsViewEntries(query: query, completion: completion)
        }
    }

    private func fetchEntryViewEntries(query: Query, completion: (() -> Void)? = nil) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: No current user ID found.")
            completion?()
            return
        }
        
        query.getDocuments { [weak self] (snapshot, error) in
            guard let self = self else {
                completion?()
                return
            }
            if let error = error {
                print("Error getting entries: \(error)")
                completion?()
                return
            }

            // Fetch the list of voted entries
            let votesCollection = db.collection("groupMemberships").document(currentUserId)
                                   .collection("competitions").document(self.competitionId)
                                   .collection("votes")
            
            votesCollection.getDocuments { (votesSnapshot, error) in
                if let error = error {
                    print("Error getting votes info: \(error)")
                    completion?()
                    return
                }
                // Collect all entry IDs the current user has voted on
                let votedEntries = votesSnapshot?.documents.map { $0.documentID } ?? []
                self.processEntries(snapshot: snapshot, excludeCurrentAndVoted: true, currentUserId: currentUserId, votedEntries: votedEntries, completion: completion)
            }
        }
    }

    private func fetchCompDetailsViewEntries(query: Query, completion: (() -> Void)? = nil) {
        let currentUserId = Auth.auth().currentUser?.uid
        
        query.getDocuments { [weak self] (snapshot, error) in
            guard let self = self else {
                completion?()
                return
            }
            if let error = error {
                print("Error getting entries: \(error)")
                completion?()
                return
            }
            self.processEntries(snapshot: snapshot, excludeCurrentAndVoted: false, currentUserId: currentUserId, completion: completion)
        }
    }

    private func processEntries(snapshot: QuerySnapshot?, excludeCurrentAndVoted: Bool, currentUserId: String?, votedEntries: [String] = [], completion: (() -> Void)? = nil) {
        guard let documents = snapshot?.documents else {
            DispatchQueue.main.async {
                self.entries = []
                self.userLeaderboard = []
                completion?()
            }
            return
        }
        
        // Get unique userIds from all entries
        let uniqueUserIds = Set(documents.compactMap { $0.data()["userId"] as? String })
        
        let group = DispatchGroup()
        var userNames: [String: String] = [:]
        var localEntries = [Entry]()
        var userStarsDict = [String: UserEntry]()

        // Fetch usernames for all unique users in one batch
        if !uniqueUserIds.isEmpty {
            group.enter()
            let userQuery = db.collection("users").whereField(FieldPath.documentID(), in: Array(uniqueUserIds))
            userQuery.getDocuments { (snapshot, error) in
                defer { group.leave() }
                
                if let error = error {
                    print("Error fetching user documents: \(error)")
                    return
                }
                
                snapshot?.documents.forEach { document in
                    if let username = document.data()["username"] as? String {
                        userNames[document.documentID] = username
                    }
                }
            }
        }

        group.notify(queue: .global()) {
            // Process entries after we have all usernames
            for document in documents {
                let userId = document.data()["userId"] as? String ?? ""
                let documentId = document.documentID
                
                if (userId == currentUserId && excludeCurrentAndVoted) || (excludeCurrentAndVoted && votedEntries.contains(documentId)) {
                    continue
                }
                
                let imageUrl = document.data()["imageUrl"] as? String ?? ""
                let stars = document.data()["stars"] as? Int ?? 0
                let isSuperstar = document.data()["superstar"] as? Bool ?? false
                let timestamp = document.data()["timestamp"] as? Timestamp
                let creationDate = timestamp?.dateValue() ?? Date()
                let overlayText = document.data()["overlayText"] as? String
                let overlayVerticalPosition = document.data()["overlayVerticalPosition"] as? CGFloat ?? 0.5
                let isFromCamera = document.data()["isFromCamera"] as? Bool ?? true
                let isCurrentUser = userId == currentUserId
                let userName = isCurrentUser ? "Me" : (userNames[userId] ?? "Unknown")
                
                let entry = Entry(id: documentId,
                                  photoUrl: imageUrl,
                                  userName: userName,
                                  stars: stars,
                                  isCurrentUser: isCurrentUser,
                                  isSuperstar: isSuperstar,
                                  creationDate: creationDate,
                                  overlayText: overlayText,
                                  overlayVerticalPosition: overlayVerticalPosition,
                                  isFromCamera: isFromCamera)
                
                localEntries.append(entry)
                
                if let userEntry = userStarsDict[userId] {
                    userStarsDict[userId]?.totalStars += stars
                } else {
                    userStarsDict[userId] = UserEntry(id: userId, userName: userName, totalStars: stars)
                }
            }
            
            group.notify(queue: .main) {
                self.entries = localEntries.sorted { $0.stars > $1.stars }
                self.userLeaderboard = userStarsDict.values.sorted { $0.totalStars > $1.totalStars }
                completion?()
            }
        }
    }

    func updateStarRating(for entryId: String, with stars: Int) {

        // Fetching the current Firebase user's ID
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: No authenticated user found.")
            return
        }
        
        let entryRef = db.collection("competitions").document(competitionId).collection("entries").document(entryId)
        let voteRef = db.collection("groupMemberships").document(currentUserId)
                         .collection("competitions").document(competitionId)
                         .collection("votes").document(entryId)
        
        let batch = db.batch()

        // Fetch the entry to determine if it is a superstar
        entryRef.getDocument { [weak self] (document, error) in
            if let error = error {
                print("Error fetching entry: \(error)")
                return
            }
            
            guard let document = document, let data = document.data() else {
                print("Entry data not found")
                return
            }
            
            let ownerId = data["userId"] as? String ?? ""
            let isSuperstar = data["superstar"] as? Bool ?? false
            let starIncrement = isSuperstar ? stars + 1 : stars
            
            // Add operations to the batch
            batch.setData(["entryId": entryId], forDocument: voteRef, merge: true)
            batch.updateData(["stars": FieldValue.increment(Int64(starIncrement))], forDocument: entryRef)

            // Commit the batch
            batch.commit { err in
                if let err = err {
                    print("Batch commit failed: \(err)")
                } else {
                    print("Batch commit succeeded!")
                }
            }
        }
    }
    
    func fetchMemberCount() {
        db.collection("competitions")
            .document(competitionId)
            .collection("members")
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching member count: \(error)")
                    return
                }
                
                DispatchQueue.main.async {
                    self?.totalMemberCount = snapshot?.documents.count ?? 0
                }
            }
    }
}
