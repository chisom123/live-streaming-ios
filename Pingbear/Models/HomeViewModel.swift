import SwiftUI
import Firebase
import Contacts
import FirebaseFirestore
import PhoneNumberKit
import Flurry_iOS_SDK

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

    private func fetchUserDetails(friendIDs: [String]) {
        let db = Firestore.firestore()

        // Use DispatchGroup to manage asynchronous operations
        let group = DispatchGroup()
        for friendID in friendIDs {
            group.enter()
            let docRef = db.collection("users").document(friendID)
            
            docRef.getDocument { (document, error) in
                defer { group.leave() }
                if let error = error {
                    print("Error getting friend's details: \(error)")
                    return
                }
                guard let doc = document, doc.exists, let data = doc.data() else { return }

                let friendPhoneNumber = data["phoneNumber"] as? String
                let friendName = data["name"] as? String
                let friendIcon = data["icon"] as? String
                    
                // Removed the lastMessageTimestamp part
                let user = AppUser(id: friendID, name: friendName ?? "", phoneNumber: friendPhoneNumber ?? "", icon: friendIcon)
                
                DispatchQueue.main.async {
                    if let index = self.appUsers.firstIndex(where: { $0.id == friendID }) {
                        self.appUsers[index] = user
                    } else {
                        self.appUsers.append(user)
                    }
                }
            }
        }

        // Once all users have been fetched, shuffle the appUsers array
        group.notify(queue: .main) {
            self.appUsers.shuffle()
        }
    }

    func formatPhoneNumber(_ phoneNumber: String) -> String {
        let phoneNumberKit = PhoneNumberKit()

        do {
            let parsedPhoneNumber = try phoneNumberKit.parse(phoneNumber)
            return phoneNumberKit.format(parsedPhoneNumber, toType: .e164)
        } catch {
            return phoneNumber
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
                                    let formattedNumber = self.formatPhoneNumber(number)
                                    
                                    db.collection("users").whereField("phoneNumber", isEqualTo: formattedNumber).getDocuments { (snapshot, error) in
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
                                                
                                                Flurry.log(eventName: "Friends-Added")
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

        // Use a realtime listener to fetch the current user's friends from Firestore
        db.collection("users").document(currentUserID).collection("friends").addSnapshotListener { (snapshot, error) in
            if let error = error {
                print("Error getting friends: \(error)")
                return
            }
            let friendIDs = snapshot?.documents.compactMap { $0["uid"] as? String } ?? []
            self.fetchUserDetails(friendIDs: friendIDs)
            
            self.fetchContacts()
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
