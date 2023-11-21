import SwiftUI
import Firebase
import FirebaseFirestore

struct Entry: Identifiable {
    let id: String
    let imageUrl: String
    let userName: String // Add userName
    let stars: Int
    let isEntryUserSubscribed: Bool  // Add this line
}

class EntryViewModel: ObservableObject {
    @Published var entries: [Entry] = []
    var competitionId: String // Add a property to store the competition ID
    @Published var currentIndex: Int = 0
    @Published var isUserSubscribed: Bool = false


    init(competitionId: String) {
        self.competitionId = competitionId
        fetchEntries()
        fetchUserSubscriptionStatus() // Fetch subscription status when initializing
    }
    
    func fetchEntries() {
        let db = Firestore.firestore()
        db.collection("competitions").document(competitionId).collection("entries").getDocuments { [weak self] (snapshot, error) in
            guard let self = self else { return }
            if let error = error {
                print("Error getting entries: \(error)")
                return
            }

            let group = DispatchGroup()

            if let documents = snapshot?.documents {
                for document in documents {
                    group.enter()
                    let userId = document.data()["userId"] as? String ?? ""
                    let imageUrl = document.data()["imageUrl"] as? String ?? ""
                    let stars = document.data()["stars"] as? Int ?? 0

                    // Fetch the user name based on userId
                    db.collection("users").document(userId).getDocument { (userSnapshot, error) in
                        defer { group.leave() }
                        if let error = error {
                            print("Error getting user: \(error)")
                            return
                        }

                        let userName = userSnapshot?.data()?["name"] as? String ?? "Unknown"
                        let isSubscribed = userSnapshot?.data()?["subscribed"] as? Bool ?? false

                        // Create Entry instance with subscription status
                        let entry = Entry(id: document.documentID, imageUrl: imageUrl, userName: userName, stars: stars, isEntryUserSubscribed: isSubscribed)
                        self.entries.append(entry)
                    }
                }
            }

            // Wait for all user names to be fetched
            group.notify(queue: .main) {
                self.entries.sort { $0.stars > $1.stars } // Sort the entries by stars
            }
        }
    }

    func fetchUserSubscriptionStatus() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No user logged in")
            return
        }

        Firestore.firestore().collection("users").document(userId).getDocument { [weak self] document, error in
            if let document = document, document.exists {
                self?.isUserSubscribed = document.get("subscribed") as? Bool ?? false
            }
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
        
        let starIncrement = (stars <= 4) ? stars : 8

        // Increment the 'stars' field by the new rating
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
                         // Document does not exist, create a new one with the user ID and the voted entry
                         participantRef.setData(["userId": currentUserId, "voted_entries": [entryId]]) { error in
                             if let error = error {
                                 print("Error adding participant: \(error)")
                             } else {
                                 print("Participant added successfully.")
                             }
                         }
                     }
                 }
                
            }
        }
    }


}
