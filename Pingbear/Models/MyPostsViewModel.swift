import Foundation
import Firebase
import FirebaseFirestore

class MyPostsViewModel: ObservableObject {
    @Published var entries: [Entry] = []
    private let db = Firestore.firestore()
    private let competitionId: String
    
    init(competitionId: String) {
        self.competitionId = competitionId
    }
    
    func refreshEntries() {
        fetchUserEntries { _ in }
    }
    
    func fetchUserEntries(completion: @escaping (Bool) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        fetchEntriesForCompetition(competitionId: competitionId, userId: currentUserId) { [weak self] entries in
            DispatchQueue.main.async {
                self?.entries = entries.sorted(by: { $0.creationDate > $1.creationDate })
                completion(true)
            }
        }
    }
    
    private func fetchEntriesForCompetition(competitionId: String, userId: String, completion: @escaping ([Entry]) -> Void) {
        guard let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) else {
            print("Error calculating date 24 hours ago")
            completion([])
            return
        }
        
        db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .whereField("userId", isEqualTo: userId)
            .whereField("timestamp", isGreaterThan: Timestamp(date: twentyFourHoursAgo))
            .getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error fetching entries: \(error)")
                    completion([])
                    return
                }
                
                let entries = snapshot?.documents.compactMap { document -> Entry? in
                    let data = document.data()
                    guard let photoUrl = data["imageUrl"] as? String,
                          let timestamp = data["timestamp"] as? Timestamp else {
                        return nil
                    }
                    
                    let stars = data["stars"] as? Int ?? 0 // Make stars optional and default to 0
                    
                    return Entry(
                        id: document.documentID,
                        photoUrl: photoUrl,
                        userName: "Me",
                        stars: stars,
                        isCurrentUser: true,
                        isSuperstar: data["superstar"] as? Bool ?? false,
                        creationDate: timestamp.dateValue(),
                        overlayText: data["overlayText"] as? String,
                        overlayVerticalPosition: data["overlayVerticalPosition"] as? CGFloat ?? 0.5,
                        isFromCamera: data["isFromCamera"] as? Bool ?? true
                    )
                } ?? []
                
                completion(entries)
            }
    }
}
