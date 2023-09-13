import SwiftUI
import Firebase
import FirebaseFirestoreSwift
import Flurry_iOS_SDK

struct Message: Equatable, Identifiable, Hashable {
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
    @Published var friendLastViewed: Timestamp?
    
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
        
        // Check if current user sent the last message - CHECK THIS, DONT THINK ITS WORKING
        if let lastMessage = self.messages.last, lastMessage.senderID == user.uid {
            print("You can't send consecutive messages. Wait for your friend to reply!")
            return
        }
        
        let documentRef = db.collection("messages").document(documentID).collection("messages").document()
        documentRef.setData(message) { error in
            if let error = error {
                print("Error writing message to Firestore: \(error)")
            } else {
                print("Message successfully written!")
                Flurry.log(eventName: "Messages-Sent")
            }
        }
    }

    func updateLastViewed(for friend: AppUser) {
        guard let user = Auth.auth().currentUser else { return }
        
        let documentID: String
        if user.uid < friend.id {
            documentID = "\(user.uid)_\(friend.id)"
        } else {
            documentID = "\(friend.id)_\(user.uid)"
        }

        let lastViewedRef = db.collection("chats").document(documentID).collection("last_viewed")
        
        lastViewedRef.document(user.uid).setData(["timestamp": Timestamp(date: Date())]) { error in
            if let error = error {
                print("Error updating last viewed timestamp: \(error)")
            } else {
                print("Successfully updated last viewed timestamp!")
            }
        }
    }

    func fetchLastViewed(for friend: AppUser) {
        guard let user = Auth.auth().currentUser else { return }

        let documentID: String
        if user.uid < friend.id {
            documentID = "\(user.uid)_\(friend.id)"
        } else {
            documentID = "\(friend.id)_\(user.uid)"
        }

        let lastViewedRef = db.collection("chats").document(documentID).collection("last_viewed").document(friend.id)
        lastViewedRef.getDocument { (document, error) in
            if let document = document, document.exists, let timestamp = document["timestamp"] as? Timestamp {
                self.friendLastViewed = timestamp
            } else {
                print("Error fetching last viewed timestamp: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    func getConversationHistory(recipientId: String) -> String {
        var history = ""
        for message in messages.reversed() {
            if message.senderID == recipientId {
                history += "User-B: \(message.content)\n"
            } else {
                history += "User-A: \(message.content)\n"
            }
        }
        return history
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
