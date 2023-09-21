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
    @Published var hasLoadedBefore: Bool = false
    @Published var selectedUserIndex: Int? {
        didSet {
            if let index = selectedUserIndex {
                currentIndex = index
                selectUser(appUsers[index])
            }
        }
    }
    
    private let db = Firestore.firestore()
    private let phoneNumberKit = PhoneNumberKit()
    private let usersPath = "users"
    private let friendsPath = "friends"
    
    enum ActiveSheet: Identifiable {
        case chatView, searchView, bearsView, addFriendsView
        
        var id: Int { hashValue }
    }
    
    private func fetchUserDetails(friendIDs: [String]) {
        let group = DispatchGroup()
        
        for friendID in friendIDs {
            group.enter()
            let docRef = db.collection(usersPath).document(friendID)
            
            docRef.getDocument { (document, error) in
                defer { group.leave() }
                if let error = error {
                    print("Error getting friend's details: \(error)")
                    return
                }
                
                guard let data = document?.data() else { return }
                let user = AppUser(id: friendID,
                                   name: data["name"] as? String ?? "",
                                   phoneNumber: data["phoneNumber"] as? String ?? "",
                                   icon: data["icon"] as? String)
                
                DispatchQueue.main.async {
                    self.updateOrAddUser(user)
                }
            }
        }
        
        group.notify(queue: .main) {
            self.appUsers.shuffle()
        }
    }
    
    private func updateOrAddUser(_ user: AppUser) {
        if let index = appUsers.firstIndex(where: { $0.id == user.id }) {
            appUsers[index] = user
        } else {
            appUsers.append(user)
        }
    }

    private func formatPhoneNumber(_ phoneNumber: String) -> String {
        do {
            let parsedPhoneNumber = try phoneNumberKit.parse(phoneNumber)
            return phoneNumberKit.format(parsedPhoneNumber, toType: .e164)
        } catch {
            return phoneNumber
        }
    }
    
    private func fetchContacts() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Failed to get current user ID")
            return
        }

        db.collection(usersPath).document(currentUserID).collection(friendsPath).getDocuments { (snapshot, error) in
            if let error = error {
                print("Error getting friends: \(error)")
                return
            }

            let friendIDs = snapshot?.documents.compactMap { $0["uid"] as? String } ?? []
            self.fetchUserDetails(friendIDs: friendIDs)

            DispatchQueue.global().async {
                let store = CNContactStore()
                store.requestAccess(for: .contacts) { (granted, error) in
                    if let error = error {
                        print("Failed to request access: \(error)")
                        return
                    }

                    if granted {
                        self.processContacts(store: store, currentUserId: currentUserID, friendIDs: friendIDs)
                    }
                }
            }
        }
    }

    private func processContacts(store: CNContactStore, currentUserId: String, friendIDs: [String]) {
        let keys = [CNContactPhoneNumbersKey as CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        
        do {
            try store.enumerateContacts(with: request, usingBlock: { (contact, _) in
                for phoneNumber in contact.phoneNumbers {
                    let number = phoneNumber.value.stringValue
                    let formattedNumber = self.formatPhoneNumber(number)
                    
                    db.collection(self.usersPath).whereField("phoneNumber", isEqualTo: formattedNumber).getDocuments { (snapshot, error) in
                        if let error = error {
                            print("Error getting documents: \(error)")
                            return
                        }
                        
                        for document in snapshot!.documents {
                            let mutualContactID = document.documentID
                            if !friendIDs.contains(mutualContactID) {
                                self.addFriend(currentUserId: currentUserId, friendId: mutualContactID)
                            }
                        }
                    }
                }
            })
        } catch let error {
            print("Failed to enumerate contacts: \(error)")
        }
    }

    private func addFriend(currentUserId: String, friendId: String) {
        db.collection(usersPath).document(currentUserId).collection(friendsPath).document(friendId).setData(["uid": friendId])
        db.collection(usersPath).document(friendId).collection(friendsPath).document(currentUserId).setData(["uid": currentUserId])
        Flurry.log(eventName: "Friends-Added")
    }
    
    func fetchFriends() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Failed to get current user ID")
            return
        }
        
        if !hasLoadedBefore {
            db.collection(usersPath).document(currentUserID).collection(friendsPath).addSnapshotListener { (snapshot, error) in
                if let error = error {
                    print("Error getting friends: \(error)")
                    return
                }

                let friendIDs = snapshot?.documents.compactMap { $0["uid"] as? String } ?? []
                self.fetchUserDetails(friendIDs: friendIDs)
                self.fetchContacts()
            }
            hasLoadedBefore = true
        } else {
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

    func showAddFriendsView() {
        activeSheet = .addFriendsView
    }
}
