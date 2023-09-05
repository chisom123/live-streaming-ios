import SwiftUI
import Firebase
import Contacts
import FirebaseFirestore

class HomeViewModel: ObservableObject {
    @Published var appUsers: [AppUser] = []
    @Published var isChatViewPresented: Bool = false
    @Published var isSearchViewPresented: Bool = false
    @Published var selectedUser: AppUser?
    @Published var currentIndex: Int = 0
    @Published var activeSheet: ActiveSheet? = nil
    @Published var selectedUserIndex: Int? = nil {
        didSet {
            if let index = selectedUserIndex {
                currentIndex = index
                selectUser(appUsers[index])
            }
        }
    }
    
    enum ActiveSheet: Identifiable {
        case chatView, searchView, bearsView

        var id: Int {
            hashValue
        }
    }
    
    private func normalizePhoneNumber(_ number: String) -> String {
        return number.filter { $0.isNumber }
    }

    private func fetchUserDetails(friendIDs: [String]) {
        let db = Firestore.firestore()
        
        for friendID in friendIDs {
            let docRef = db.collection("users").document(friendID)
            docRef.addSnapshotListener { (document, error) in
                if let error = error {
                    print("Error getting friend's details: \(error)")
                    return
                }
                guard let doc = document, doc.exists, let data = doc.data() else { return }

                let friendPhoneNumber = data["phoneNumber"] as? String
                let friendName = data["name"] as? String
                let friendIcon = data["icon"] as? String
                let lastMessageTimestamp = data["lastMessageTimestamp"] as? Timestamp
                
                let user = AppUser(id: friendID, name: friendName ?? "", phoneNumber: friendPhoneNumber ?? "", icon: friendIcon, lastMessageTimestamp: lastMessageTimestamp)
                DispatchQueue.main.async {
                    if let index = self.appUsers.firstIndex(where: { $0.id == friendID }) {
                        self.appUsers[index] = user
                    } else {
                        self.appUsers.append(user)
                    }
                    self.appUsers.sort { (user1, user2) -> Bool in
                        guard let timestamp1 = user1.lastMessageTimestamp, let timestamp2 = user2.lastMessageTimestamp else {
                            return user1.lastMessageTimestamp != nil
                        }
                        return timestamp1.dateValue() > timestamp2.dateValue()
                    }
                }
            }
        }
    }


    func fetchContacts() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Failed to get current user ID")
            return
        }
        
        let db = Firestore.firestore()
        
        // First, get the current user's friends
        db.collection("users").document(currentUserID).collection("friends").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error getting friends: \(error)")
                return
            }
            let friendIDs = snapshot?.documents.compactMap { $0["uid"] as? String } ?? []
            self.fetchUserDetails(friendIDs: friendIDs)
            
            // Add mutual contacts to friends collection if not added yet
            DispatchQueue.global().async {
                let store = CNContactStore()
                store.requestAccess(for: .contacts) { (granted, error) in
                    if let error = error {
                        print("Failed to request access: \(error)")
                        return
                    }
                    if granted {
                        let keys = [CNContactPhoneNumbersKey as CNKeyDescriptor]
                        let request = CNContactFetchRequest(keysToFetch: keys)
                        do {
                            try store.enumerateContacts(with: request, usingBlock: { (contact, stopPointer) in
                                for phoneNumber in contact.phoneNumbers {
                                    let number = phoneNumber.value.stringValue
                                    let normalizedNumber = self.normalizePhoneNumber(number)
                                    
                                    db.collection("users").whereField("phoneNumber", isEqualTo: normalizedNumber).getDocuments { (snapshot, error) in
                                        if let error = error {
                                            print("Error getting documents: \(error)")
                                            return
                                        }
                                        for document in snapshot!.documents {
                                            let mutualContactID = document.documentID
                                            if !friendIDs.contains(mutualContactID) {
                                                // If this contact isn't already a friend, add to friends collection
                                                db.collection("users").document(currentUserID).collection("friends").document(mutualContactID).setData(["uid": mutualContactID])
                                                db.collection("users").document(mutualContactID).collection("friends").document(currentUserID).setData(["uid": currentUserID])
                                            }
                                        }
                                    }
                                }
                            })
                        } catch let error {
                            print("Failed to enumerate contacts: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    func fetchFriends() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Failed to get current user ID")
            return
        }
        
        let db = Firestore.firestore()

        // Fetch the current user's friends from Firestore
        db.collection("users").document(currentUserID).collection("friends").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error getting friends: \(error)")
                return
            }
            let friendIDs = snapshot?.documents.compactMap { $0["uid"] as? String } ?? []
            self.fetchUserDetails(friendIDs: friendIDs)
        }
    }


    func selectUser(_ user: AppUser) {
        selectedUser = user
        activeSheet = .chatView
    }

    func showBearsView() {
        activeSheet = .bearsView
    }
}
