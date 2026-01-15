import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct Entry: Identifiable {
    let id: String
    let photoUrl: String
    let userName: String
    let stars: Int
    let userProfilePictureUrl: String?
    let isCurrentUser: Bool
    let userId: String
    let isSuperstar: Bool
    let creationDate: Date
    let overlayText: String?
    let overlayVerticalPosition: CGFloat
    let isFromCamera: Bool
    let themeId: String?
    let themeName: String?
    
    // Add these parlay properties
    let parlayStatus: String?
    let parlayPredictions: [String: Any]?
    let parlayPayout: Int?
    let parlayStake: Int?
    
    init(id: String, photoUrl: String, userName: String, stars: Int, userProfilePictureUrl: String?,
         isCurrentUser: Bool, userId: String, isSuperstar: Bool, creationDate: Date, overlayText: String?,
         overlayVerticalPosition: CGFloat, isFromCamera: Bool, themeId: String? = nil, themeName: String? = nil,
         parlayStatus: String? = nil, parlayPredictions: [String: Any]? = nil,
         parlayPayout: Int? = nil, parlayStake: Int? = nil) {
        
        self.id = id
        self.photoUrl = photoUrl
        self.userName = userName
        self.stars = stars
        self.userProfilePictureUrl = userProfilePictureUrl
        self.isCurrentUser = isCurrentUser
        self.userId = userId
        self.isSuperstar = isSuperstar
        self.creationDate = creationDate
        self.overlayText = overlayText
        self.overlayVerticalPosition = overlayVerticalPosition
        self.isFromCamera = isFromCamera
        self.themeId = themeId
        self.themeName = themeName
        self.parlayStatus = parlayStatus
        self.parlayPredictions = parlayPredictions
        self.parlayPayout = parlayPayout
        self.parlayStake = parlayStake
    }
}

struct UserEntry: Identifiable {
    let id: String
    let userName: String
    let profilePictureUrl: String?
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
    private var mode: FetchEntriesMode
    
    private let db = Firestore.firestore()
    
    enum FetchEntriesMode {
        case entryView
        case compDetailsView
    }

    init(competitionId: String, mode: FetchEntriesMode) {
        self.competitionId = competitionId
        self.mode = mode
        fetchEntries(mode: mode)
        
        // Only setup listeners for CompDetails view
        if mode == .compDetailsView {
            setupListeners()
            fetchMemberCount()
        }
    }
    
    deinit {
        if mode == .compDetailsView {
            removeListeners()
        }
    }
    
    func setupListeners() {
        guard mode == .compDetailsView else { return }
        
        // Remove existing listeners first to avoid duplicates
        removeListeners()
        
        // Then setup fresh listeners
        setupEntriesListener()
        setupVotesListener()
    }

    private func setupEntriesListener() {
        let entriesPath = "competitions/\(competitionId)/entries"

        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Could not get current user ID.")
            return
        }
        
        let query = db.collection("competitions")
            .document(competitionId)
            .collection("entries")
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
        let paths = [
            "competitions/\(competitionId)/entries",
            getVotesPath()
        ]

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
        if mode == .entryView {
            fetchFullEntriesForVoting(completion: completion)
        } else {
            fetchLeaderboardData(completion: completion)
        }
    }

    // Optimized method for CompDetailsView - only fetches what's needed for leaderboard
    private func fetchLeaderboardData(completion: (() -> Void)? = nil) {
        let currentUserId = Auth.auth().currentUser?.uid
        
        // Only fetch userId and stars fields - no need for full entry data
        db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .getDocuments { [weak self] (snapshot, error) in
                guard let self = self else {
                    completion?()
                    return
                }
                
                if let error = error {
                    print("Error getting entries: \(error)")
                    completion?()
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    DispatchQueue.main.async {
                        self.userLeaderboard = []
                        completion?()
                    }
                    return
                }
                
                // Extract unique userIds and aggregate stars
                var userStarsDict = [String: (stars: Int, isCurrentUser: Bool)]()
                
                for document in documents {
                    let userId = document.data()["userId"] as? String ?? ""
                    let stars = document.data()["stars"] as? Int ?? 0
                    let isCurrentUser = userId == currentUserId
                    
                    if let existing = userStarsDict[userId] {
                        userStarsDict[userId] = (stars: existing.stars + stars, isCurrentUser: isCurrentUser)
                    } else {
                        userStarsDict[userId] = (stars: stars, isCurrentUser: isCurrentUser)
                    }
                }
                
                // Fetch user data only for userIds we need
                let uniqueUserIds = Array(userStarsDict.keys)
                
                if uniqueUserIds.isEmpty {
                    DispatchQueue.main.async {
                        self.userLeaderboard = []
                        completion?()
                    }
                    return
                }
                
                // Batch fetch user data
                self.db.collection("users")
                    .whereField(FieldPath.documentID(), in: Array(uniqueUserIds))
                    .getDocuments { (userSnapshot, error) in
                        if let error = error {
                            print("Error fetching user documents: \(error)")
                            completion?()
                            return
                        }
                        
                        var userEntries = [UserEntry]()
                        
                        userSnapshot?.documents.forEach { document in
                            let userId = document.documentID
                            let data = document.data()
                            let name = data["name"] as? String ?? "Unknown"
                            let profilePictureUrl = data["profilePictureUrl"] as? String
                            
                            if let userStats = userStarsDict[userId] {
                                let displayName = userStats.isCurrentUser ? "Me" : name
                                userEntries.append(UserEntry(
                                    id: userId,
                                    userName: displayName,
                                    profilePictureUrl: profilePictureUrl,
                                    totalStars: userStats.stars
                                ))
                            }
                        }
                        
                        DispatchQueue.main.async {
                            self.userLeaderboard = userEntries.sorted { $0.totalStars > $1.totalStars }
                            // Don't populate entries array for CompDetails
                            if self.mode == .compDetailsView {
                                self.entries = []
                            }
                            completion?()
                        }
                    }
            }
    }

    // Full fetch for EntryView - gets all entry details needed for voting
    private func fetchFullEntriesForVoting(completion: (() -> Void)? = nil) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: No current user ID found.")
            completion?()
            return
        }
        
        let query = db.collection("competitions")
            .document(competitionId)
            .collection("entries")
        
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

            // Fetch voted entries
            let votesCollection = db.collection("groupMemberships")
                .document(currentUserId)
                .collection("competitions")
                .document(self.competitionId)
                .collection("votes")
            
            votesCollection.getDocuments { (votesSnapshot, error) in
                if let error = error {
                    print("Error getting votes info: \(error)")
                    completion?()
                    return
                }
                
                let votedEntries = votesSnapshot?.documents.map { $0.documentID } ?? []
                self.processEntriesForVoting(
                    snapshot: snapshot,
                    currentUserId: currentUserId,
                    votedEntries: votedEntries,
                    completion: completion
                )
            }
        }
    }

    // Process entries for voting (EntryView)
    private func processEntriesForVoting(snapshot: QuerySnapshot?, currentUserId: String, votedEntries: [String], completion: (() -> Void)? = nil) {
        guard let documents = snapshot?.documents else {
            DispatchQueue.main.async {
                self.entries = []
                completion?()
            }
            return
        }
        
        // Filter out current user's entries and voted entries
        let eligibleDocuments = documents.filter { document in
            let userId = document.data()["userId"] as? String ?? ""
            let documentId = document.documentID
            return userId != currentUserId && !votedEntries.contains(documentId)
        }
        
        // Get unique userIds
        let uniqueUserIds = Set(eligibleDocuments.compactMap { $0.data()["userId"] as? String })
        
        if uniqueUserIds.isEmpty {
            DispatchQueue.main.async {
                self.entries = []
                completion?()
            }
            return
        }
        
        // Batch fetch user data
        db.collection("users")
            .whereField(FieldPath.documentID(), in: Array(uniqueUserIds))
            .getDocuments { [weak self] (userSnapshot, error) in
                guard let self = self else {
                    completion?()
                    return
                }
                
                if let error = error {
                    print("Error fetching user documents: \(error)")
                    completion?()
                    return
                }
                
                var userNames: [String: String] = [:]
                var userProfilePictures: [String: String] = [:]
                
                userSnapshot?.documents.forEach { document in
                    let data = document.data()
                    if let name = data["name"] as? String {
                        userNames[document.documentID] = name
                    }
                    if let profilePictureUrl = data["profilePictureUrl"] as? String {
                        userProfilePictures[document.documentID] = profilePictureUrl
                    }
                }
                
                // Build entries array with all details needed for voting
                var localEntries = [Entry]()
                
                for document in eligibleDocuments {
                    let data = document.data()
                    let userId = data["userId"] as? String ?? ""
                    let documentId = document.documentID
                    
                    let imageUrl = data["imageUrl"] as? String ?? ""
                    let stars = data["stars"] as? Int ?? 0
                    let isSuperstar = data["superstar"] as? Bool ?? false
                    let timestamp = data["timestamp"] as? Timestamp
                    let creationDate = timestamp?.dateValue() ?? Date()
                    let overlayText = data["overlayText"] as? String
                    let overlayVerticalPosition = data["overlayVerticalPosition"] as? CGFloat ?? 0.5
                    let isFromCamera = data["isFromCamera"] as? Bool ?? true
                    let userName = userNames[userId] ?? "Unknown"
                    let profilePictureUrl = userProfilePictures[userId]
                    let themeId = data["themeId"] as? String
                    let themeName = data["themeName"] as? String
                    let parlayStatus = data["parlayStatus"] as? String
                    let parlayPredictions = data["predictions"] as? [String: Any]
                    let parlayPayout = data["potentialPayout"] as? Int
                    let parlayStake = data["entryCost"] as? Int
                    
                    let entry = Entry(
                        id: documentId,
                        photoUrl: imageUrl,
                        userName: userName,
                        stars: stars,
                        userProfilePictureUrl: profilePictureUrl,
                        isCurrentUser: false, // Already filtered out current user
                        userId: userId,
                        isSuperstar: isSuperstar,
                        creationDate: creationDate,
                        overlayText: overlayText,
                        overlayVerticalPosition: overlayVerticalPosition,
                        isFromCamera: isFromCamera,
                        themeId: themeId,
                        themeName: themeName,
                        parlayStatus: parlayStatus,
                        parlayPredictions: parlayPredictions,
                        parlayPayout: parlayPayout,
                        parlayStake: parlayStake
                    )
                    
                    localEntries.append(entry)
                }
                
                DispatchQueue.main.async {
                    self.entries = localEntries.sorted { $0.creationDate < $1.creationDate }
                    // Don't populate userLeaderboard for EntryView
                    if self.mode == .entryView {
                        self.userLeaderboard = []
                    }
                    completion?()
                }
            }
    }

    func updateStarRating(for entryId: String, with stars: Int) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: No authenticated user found.")
            return
        }
        
        let entryRef = db.collection("competitions").document(competitionId).collection("entries").document(entryId)
        let voteRef = db.collection("groupMemberships").document(currentUserId)
                         .collection("competitions").document(competitionId)
                         .collection("votes").document(entryId)
        
        let interactionRef = db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .document(entryId)
            .collection("interactions")
            .document(currentUserId)

        let batch = db.batch()

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
            let starIncrement = stars
            
            batch.setData(["entryId": entryId], forDocument: voteRef, merge: true)
            batch.updateData(["stars": FieldValue.increment(Int64(starIncrement))], forDocument: entryRef)
            batch.setData(["rating": stars, "userId": currentUserId], forDocument: interactionRef, merge: true)

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
    
    func refreshVoteStatus() {
        guard mode == .compDetailsView,
              let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Only fetch the votes, not all entries
        let votesPath = "groupMemberships/\(currentUserId)/competitions/\(competitionId)/votes"
        
        db.collection(votesPath)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error refreshing vote status: \(error)")
                    return
                }
                
                let votedIds = snapshot?.documents.map { $0.documentID } ?? []
                
                DispatchQueue.main.async {
                    self.votedEntryIds = Set(votedIds)
                    self.updateVoteStatus()
                }
            }
    }

}
