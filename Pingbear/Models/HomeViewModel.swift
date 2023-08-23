import SwiftUI
import Firebase
import Contacts

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
        case chatView, searchView

        var id: Int {
            hashValue
        }
    }
    
    private func normalizePhoneNumber(_ number: String) -> String {
        return number.filter { $0.isNumber }
    }

    func fetchContacts() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Failed to get current user ID")
            return
        }

        let db = Firestore.firestore()
        db.collection("users").document(currentUserID).getDocument { (document, error) in
            if let error = error {
                print("Error getting current user document: \(error)")
                return
            }
            guard let document = document, let currentUserData = document.data(), let currentUserPhoneNumber = currentUserData["phoneNumber"] as? String else {
                print("Error fetching current user phone number")
                return
            }

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
                                    let db = Firestore.firestore()
                                    db.collection("users").whereField("phoneNumber", isEqualTo: normalizedNumber).getDocuments { (snapshot, error) in
                                        if let error = error {
                                            print("Error getting documents: \(error)")
                                        } else {
                                            DispatchQueue.main.async {
                                                for document in snapshot!.documents {
                                                    let friendID = document.documentID
                                                    if let phoneNumber = document.data()["phoneNumber"] as? String, phoneNumber != currentUserPhoneNumber {
                                                        if let name = document.data()["name"] as? String {
                                                            let user = AppUser(id: friendID, name: name, phoneNumber: phoneNumber)
                                                            self.appUsers.append(user)
                                                            db.collection("users").document(currentUserID).collection("friends").document(friendID).getDocument { (document, error) in
                                                                if document?.exists == false {
                                                                    db.collection("users").document(currentUserID).collection("friends").document(friendID).setData(["uid": friendID])
                                                                    db.collection("users").document(friendID).collection("friends").document(currentUserID).setData(["uid": currentUserID])
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
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

    func selectUser(_ user: AppUser) {
        selectedUser = user
        activeSheet = .chatView
    }
}
