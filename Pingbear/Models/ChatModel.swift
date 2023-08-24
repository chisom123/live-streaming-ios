import SwiftUI
import Firebase
import FirebaseFirestoreSwift

struct Message: Equatable, Identifiable {
    var id: String?
    var senderID: String
    var timestamp: Timestamp
    var content: String

    init?(from dictionary: [String: Any]) {
        guard let senderID = dictionary["senderID"] as? String,
              let timestamp = dictionary["timestamp"] as? Timestamp,
              let content = dictionary["content"] as? String else {
            return nil
        }
        self.senderID = senderID
        self.timestamp = timestamp
        self.content = content
    }
}

class ChatModel: ObservableObject {
    @Published var messages: [Message] = []
    private let db = Firestore.firestore()
    
    func sendMessage(to recipient: AppUser, content: String) {
        guard let user = Auth.auth().currentUser else { return }

        let documentID: String
        if user.uid < recipient.id {
            documentID = "\(user.uid)_\(recipient.id)"
        } else {
            documentID = "\(recipient.id)_\(user.uid)"
        }
        
        let message: [String: Any] = [
            "senderID": user.uid,
            "timestamp": Timestamp(date: Date()),
            "content": content
        ]
        
        let documentRef = db.collection("messages").document(documentID).collection("messages").document()
        documentRef.setData(message) { error in
            if let error = error {
                print("Error writing message to Firestore: \(error)")
            } else {
                print("Message successfully written!")
            }
        }
    }

    
    
    func fetchMessages(for friend: AppUser) {
        guard let user = Auth.auth().currentUser else { return }
        
        let documentID: String
        if user.uid < friend.id {
            documentID = "\(user.uid)_\(friend.id)"
        } else {
            documentID = "\(friend.id)_\(user.uid)"
        }

        db.collection("messages").document(documentID).collection("messages")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { (snapshot, error) in
                guard let documents = snapshot?.documents else {
                    print("Error fetching messages: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                self.messages = documents.compactMap { queryDocumentSnapshot -> Message? in
                    var message = Message(from: queryDocumentSnapshot.data())
                    message?.id = queryDocumentSnapshot.documentID
                    return message
                }
            }
    }

    
}
