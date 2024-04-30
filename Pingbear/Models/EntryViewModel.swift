import SwiftUI
import Firebase
import FirebaseFirestore

struct Entry: Identifiable {
    let id: String
    let imageUrl: String
    let userName: String
    let stars: Int
    let isCurrentUser: Bool
    let isSuperstar: Bool
    let creationDate: Date
}

class EntryViewModel: ObservableObject {
    @Published var entries: [Entry] = []
    var competitionId: String
    @Published var currentIndex: Int = 0
    var listeners: [ListenerRegistration] = []
    
    enum FetchEntriesMode {
        case entryView
        case compDetailsView
    }

    init(competitionId: String, mode: FetchEntriesMode) {
        self.competitionId = competitionId
        fetchEntries(mode: mode)
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
        let currentUserId = Auth.auth().currentUser?.uid
        
        let entryViewListener = query.addSnapshotListener { [weak self] (snapshot, error) in
            guard let self = self else { return }
            if let error = error {
                print("Error getting entries: \(error)")
                return
            }

            // Fetch the list of voted entries
            Firestore.firestore().collection("competitions").document(self.competitionId).collection("participants").document(currentUserId ?? "").getDocument { (participantSnapshot, error) in
                if let error = error {
                    print("Error getting participant info: \(error)")
                    return
                }
                let votedEntries = participantSnapshot?.data()?["voted_entries"] as? [String] ?? []
                self.processEntries(snapshot: snapshot, excludeCurrentAndVoted: true, currentUserId: currentUserId, votedEntries: votedEntries)
            }
        }
        listeners.append(entryViewListener)
    }

    private func fetchCompDetailsViewEntries(query: Query) {
        let currentUserId = Auth.auth().currentUser?.uid
        
        let compViewListener = query.addSnapshotListener { [weak self] (snapshot, error) in
            guard let self = self else { return }
            if let error = error {
                print("Error getting entries: \(error)")
                return
            }
            self.processEntries(snapshot: snapshot, excludeCurrentAndVoted: false, currentUserId: currentUserId)
        }
        
        listeners.append(compViewListener)
    }


    private func processEntries(snapshot: QuerySnapshot?, excludeCurrentAndVoted: Bool, currentUserId: String?, votedEntries: [String] = []) {
        guard let documents = snapshot?.documents else { return }
        let group = DispatchGroup()
        var localEntries = [Entry]()

        for document in documents {
            let userId = document.data()["userId"] as? String ?? ""
            let documentId = document.documentID
            if excludeCurrentAndVoted && (userId == currentUserId || votedEntries.contains(documentId)) {
                continue // Skip current user's entries and already voted entries
            }

            group.enter()
            let imageUrl = document.data()["imageUrl"] as? String ?? ""
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
                let entry = Entry(id: documentId, imageUrl: imageUrl, userName: userName, stars: stars, isCurrentUser: isCurrentUser, isSuperstar: isSuperstar, creationDate: creationDate)
                localEntries.append(entry)
            }
        }

        group.notify(queue: .main) {
            self.entries = localEntries.sorted { $0.stars > $1.stars }
        }
    }

    func updateStarRating(for entryId: String, with stars: Int) {
        let db = Firestore.firestore()
        let entryRef = db.collection("competitions").document(competitionId).collection("entries").document(entryId)

        // Fetching the current Firebase user's ID
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: No authenticated user found.")
            return
        }

        let participantRef = db.collection("competitions").document(competitionId).collection("participants").document(currentUserId)
        
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
            
            let isSuperstar = data["superstar"] as? Bool ?? false
            let starIncrement = isSuperstar ? stars * 2 : stars
            
            // Increment the 'stars' field by the new rating, adjusted for superstar status
            entryRef.updateData(["stars": FieldValue.increment(Int64(starIncrement))]) { error in
                if let error = error {
                    print("Error updating star rating: \(error)")
                } else {
                    print("Star rating updated successfully.")
                    
                    // Check if the participant document exists
                    participantRef.getDocument { (document, error) in
                        if let document = document, document.exists {
                            // Document exists, update the 'voted_entries' array
                            participantRef.updateData(["voted_entries": FieldValue.arrayUnion([entryId])]) { error in
                                if let error = error {
                                    print("Error updating voted entries: \(error)")
                                } else {
                                    print("Voted entries updated successfully.")
                                }
                            }
                        } else {
                            print("User not a participant")
                        }
                    }
                }
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
