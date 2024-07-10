import SwiftUI
import Firebase
import FirebaseFirestore

struct Entry: Identifiable {
    let id: String
    let videoUrl: String
    let userName: String
    let stars: Int
    let isCurrentUser: Bool
    let isSuperstar: Bool
    let creationDate: Date
}

struct UserEntry: Identifiable {
    let id: String
    let userName: String
    var totalStars: Int
}

class EntryViewModel: ObservableObject {
    @Published var entries: [Entry] = []
    @Published var userLeaderboard: [UserEntry] = []
    @Published var hasEntriesToVoteOn: Bool = true
    var competitionId: String
    @Published var currentIndex: Int = 0
    private var notificationSender = PushNotificationSender()
    
    private var entriesListener: ListenerRegistration?
    private var votesListener: ListenerRegistration?
    private var leaderboardListener: ListenerRegistration?
    
    private var allEntryIds: Set<String> = Set()
    private var votedEntryIds: Set<String> = Set()
    
    private var debounceWorkItems: [String: DispatchWorkItem] = [:]
    
    enum FetchEntriesMode {
        case entryView
        case compDetailsView
    }

    init(competitionId: String, mode: FetchEntriesMode) {
        self.competitionId = competitionId
        fetchEntries(mode: mode)
        setupListeners(mode: mode)
    }
    
    deinit {
        removeListeners()
    }
    
    func setupListeners(mode: FetchEntriesMode) {
        setupEntriesListener()
        setupVotesListener()
    }

    private func setupDebouncedListener(path: String, process: @escaping () -> Void) {
        removeDebouncedListener(path: path)
        
        let workItem = DispatchWorkItem(block: process)
        debounceWorkItems[path] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    private func removeDebouncedListener(path: String) {
        debounceWorkItems[path]?.cancel()
        debounceWorkItems.removeValue(forKey: path)
    }

    private func setupEntriesListener() {
        let db = Firestore.firestore()
        let entriesPath = "competitions/\(competitionId)/entries"

        // Calculate the time 24 hours ago from now using Calendar
        guard let twentyFourHoursAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else {
            print("Could not compute the date 24 hours ago.")
            return
        }

        // Set up the listener with a timestamp filter
        entriesListener = db.collection(entriesPath)
                             .whereField("timestamp", isGreaterThan: twentyFourHoursAgo)
                             .addSnapshotListener { [weak self] snapshot, error in
                                 guard let self = self, let snapshot = snapshot, error == nil else {
                                     print("Error listening for entry updates: \(error?.localizedDescription ?? "Unknown error")")
                                     return
                                 }

                                 self.setupDebouncedListener(path: entriesPath) {
                                     let ids = snapshot.documents.map { $0.documentID }
                                     self.allEntryIds = Set(ids)
                                     self.updateVoteStatus()
                                 }
                             }
    }

    private func setupVotesListener() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("No current user ID found for votes listener setup.")
            return
        }

        let db = Firestore.firestore()
        let votesPath = "groupMemberships/\(currentUserId)/competitions/\(competitionId)/votes"
        votesListener = db.collection(votesPath).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let snapshot = snapshot, error == nil else {
                print("Error listening for votes updates: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            self.setupDebouncedListener(path: votesPath) {
                let ids = snapshot.documents.compactMap { $0.data()["entryId"] as? String }
                self.votedEntryIds = Set(ids)
                self.updateVoteStatus()
            }
        }
    }

    private func updateVoteStatus() {
        DispatchQueue.main.async {
            self.hasEntriesToVoteOn = !self.allEntryIds.subtracting(self.votedEntryIds).isEmpty
        }
    }

    func removeListeners() {
        entriesListener?.remove()
        votesListener?.remove()
        leaderboardListener?.remove()
        
        // Remove all debouncing work items
        debounceWorkItems.forEach { key, workItem in
            workItem.cancel()  // Cancel each work item
        }
        debounceWorkItems.removeAll()  // Clear the dictionary
    }
    
    func fetchEntries(mode: FetchEntriesMode) {
        let db = Firestore.firestore()
        guard let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) else {
            print("Error calculating date 24 hours ago")
            return
        }
        
        let collection = db.collection("competitions").document(competitionId).collection("entries")
        let query = collection.whereField("timestamp", isGreaterThan: Timestamp(date: twentyFourHoursAgo))
        
        if mode == .entryView {
            fetchEntryViewEntries(query: query)
        } else {
            fetchCompDetailsViewEntries(query: query)
        }
    }

    private func fetchEntryViewEntries(query: Query) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: No current user ID found.")
            return
        }
        
        query.getDocuments { [weak self] (snapshot, error) in
            guard let self = self else { return }
            if let error = error {
                print("Error getting entries: \(error)")
                return
            }

            // Fetch the list of voted entries
            let votesCollection = Firestore.firestore().collection("groupMemberships").document(currentUserId)
                                   .collection("competitions").document(self.competitionId)
                                   .collection("votes")
            
            votesCollection.getDocuments { (votesSnapshot, error) in
                if let error = error {
                    print("Error getting votes info: \(error)")
                    return
                }
                // Collect all entry IDs the current user has voted on
                let votedEntries = votesSnapshot?.documents.map { $0.documentID } ?? []
                self.processEntries(snapshot: snapshot, excludeCurrentAndVoted: true, currentUserId: currentUserId, votedEntries: votedEntries)
            }
        }
    }

    private func fetchCompDetailsViewEntries(query: Query) {
        let currentUserId = Auth.auth().currentUser?.uid
        let queryIdentifier = "LeaderboardQuery-\(competitionId)"
        
        leaderboardListener = query.addSnapshotListener { [weak self] (snapshot, error) in
            guard let self = self else { return }
            if let error = error {
                print("Error getting entries: \(error)")
                return
            }
            self.setupDebouncedListener(path: queryIdentifier) {
                self.processEntries(snapshot: snapshot, excludeCurrentAndVoted: false, currentUserId: currentUserId)
            }
        }
    }


    private func processEntries(snapshot: QuerySnapshot?, excludeCurrentAndVoted: Bool, currentUserId: String?, votedEntries: [String] = []) {
        guard let documents = snapshot?.documents else { return }
        let group = DispatchGroup()
        var localEntries = [Entry]()
        var userStarsDict = [String: UserEntry]()

        for document in documents {
            let userId = document.data()["userId"] as? String ?? ""
            let documentId = document.documentID
            if excludeCurrentAndVoted && (votedEntries.contains(documentId)) {
                continue // Skip current user's entries and already voted entries
            }

            group.enter()
            let videoUrl = document.data()["videoUrl"] as? String ?? ""
            let stars = document.data()["stars"] as? Int ?? 0
            let isSuperstar = document.data()["superstar"] as? Bool ?? false
            let timestamp = document.data()["timestamp"] as? Timestamp
            let creationDate = timestamp?.dateValue() ?? Date()

            Firestore.firestore().collection("users").document(userId).getDocument { (userSnapshot, error) in
                defer { group.leave() }
                if let error = error {
                    print("Error getting user: \(error)")
                    return
                }
                let userName = userSnapshot?.data()?["username"] as? String ?? "Unknown"
                let isCurrentUser = userId == currentUserId
                let entry = Entry(id: documentId, videoUrl: videoUrl, userName: isCurrentUser ? "Me" : userName, stars: stars, isCurrentUser: isCurrentUser, isSuperstar: isSuperstar, creationDate: creationDate)
                
                localEntries.append(entry)
                
                if let userEntry = userStarsDict[userId] {
                    userStarsDict[userId]?.totalStars += stars
                } else {
                    userStarsDict[userId] = UserEntry(id: userId, userName: isCurrentUser ? "Me" : userName, totalStars: stars)
                }
            }
        }

        group.notify(queue: .main) {
            self.entries = localEntries.sorted { $0.stars > $1.stars }
            self.userLeaderboard = userStarsDict.values.sorted { $0.totalStars > $1.totalStars }
        }
    }

    func updateStarRating(for entryId: String, with stars: Int) {
        let db = Firestore.firestore()

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
                    self?.fetchFCMTokenAndSendNotification(to: ownerId, forEntryId: entryId, withNewStars: starIncrement)
                }
            }
        }
    }
    
    func fetchFCMTokenAndSendNotification(to userId: String, forEntryId entryId: String, withNewStars starIncrement: Int) {
        let db = Firestore.firestore()
        
        let usersRef = Firestore.firestore().collection("users").document(userId)
        usersRef.getDocument { (document, error) in
            if let error = error {
                print("Error fetching user: \(error)")
                return
            }
            guard let token = document?.data()?["fcmToken"] as? String else {
                print("FCM token not found for user \(userId)")
                return
            }
            
            let compRef = db.collection("competitions").document(self.competitionId)
            
            compRef.getDocument { [weak self] (document, error) in
                if let error = error {
                    print("Error fetching competition: \(error)")
                    return
                }
                
                guard let document = document, let data = document.data() else {
                    print("Competition data not found")
                    return
                }
                
                let description = data["description"] as? String ?? ""
                
                let title = description
                let body = "+\(starIncrement) stars ⭐"
                if starIncrement >= 4 {
                    self?.notificationSender.sendPushNotification(to: token, title: title, body: body)
                }
            }
        }
    }
}
