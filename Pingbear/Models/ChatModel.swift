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
    
    private func documentID(from userUID: String, friendUID: String) -> String {
        return userUID < friendUID ? "\(userUID)_\(friendUID)" : "\(friendUID)_\(userUID)"
    }
    
    func sendMessage(to recipient: AppUser, content: String) {
        guard let user = Auth.auth().currentUser,
              let lastMessage = self.messages.last, lastMessage.senderID != user.uid else {
            print("Failed prerequisites for sending message.")
            return
        }

        let message: [String: Any] = [
            "senderID": user.uid,
            "timestamp": Timestamp(date: Date()),
            "content": content
        ]
        
        let documentRef = db.collection("messages").document(documentID(from: user.uid, friendUID: recipient.id)).collection("messages").document()
        
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
        
        let lastViewedRef = db.collection("chats").document(documentID(from: user.uid, friendUID: friend.id)).collection("last_viewed")
        
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

        let lastViewedRef = db.collection("chats").document(documentID(from: user.uid, friendUID: friend.id)).collection("last_viewed").document(friend.id)
        
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

        db.collection("messages").document(documentID(from: user.uid, friendUID: friend.id)).collection("messages")
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

