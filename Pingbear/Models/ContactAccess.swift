import Contacts
import FirebaseAuth
import FirebaseFirestore
import PhoneNumberKit
import PostHog
import CryptoKit

struct Contact {
    var firstName: String
    var lastName: String
    var username: String
    var phoneNumber: String
    var isAdded: Bool = false
    
    var fullName: String {
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
}

class ContactViewModel: ObservableObject {
    @Published var matchedUsers = [Contact]()
    private let db = Firestore.firestore()
    private let phoneNumberKit = PhoneNumberKit()
    private var currentUserFriends: Set<String> = []
    private var processedPhoneNumbers: Set<String> = []
    
    private let salt = "5Ax1HpaMDwxIv15M6t4ZdGuC8"
    
    var hasAddedAnyFriends: Bool {
        matchedUsers.contains(where: { $0.isAdded })
    }

    init() {
        fetchCurrentUserFriends()
    }

    func requestContactAccess() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            if let error = error {
                print("Error requesting access: \(error)")
                return
            }
            if granted {
                self.fetchContacts()
                PostHogSDK.shared.capture("Contacts Fetched")
            } else {
                print("Access Denied")
                PostHogSDK.shared.capture("Contacts Access Denied")
            }
        }
    }

    private func fetchCurrentUserFriends() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("No current user found")
            return
        }

        db.collection("users").document(currentUserID).collection("friends").getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("Error fetching friends: \(error)")
                return
            }
            
            let friendIDs = snapshot?.documents.compactMap { $0.documentID } ?? []
            self?.currentUserFriends = Set(friendIDs)
            
            // After fetching friends, update the matched users list
            self?.updateMatchedUsers()
        }
    }
    
    private func fetchContacts() {
        DispatchQueue.global(qos: .userInitiated).async { // Run this on a background thread
            let store = CNContactStore()
            let keysToFetch = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
            let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)

            do {
                try store.enumerateContacts(with: fetchRequest) { (contact, stopPointer) in
                    contact.phoneNumbers.forEach { phoneNumber in
                        let rawPhoneNumber = phoneNumber.value.stringValue
                        let cleanedPhoneNumber = self.formatPhoneNumber(rawPhoneNumber)
                        if let formattedNumber = cleanedPhoneNumber {
                            DispatchQueue.main.async {
                                self.compareContacts(phoneNumber: formattedNumber, firstName: contact.givenName, lastName: contact.familyName)
                            }
                        } else {
                            print("Unformatted or error in phone number: \(rawPhoneNumber)")
                        }
                    }
                }
            } catch let error {
                DispatchQueue.main.async { // Switch back to the main thread to update UI or handle errors
                    print("Failed to fetch contacts: \(error)")
                }
            }
        }
    }

    
    private func formatPhoneNumber(_ phoneNumber: String) -> String? {
        do {
            let parsedPhoneNumber = try phoneNumberKit.parse(phoneNumber)
            return phoneNumberKit.format(parsedPhoneNumber, toType: .e164)
        } catch {
            print("Error parsing phone number: \(error)")
            return nil
        }
    }
    
    private func hashPhoneNumber(_ phoneNumber: String) -> String {
        // Normalize phone number by removing non-digit characters
        let cleanedNumber = phoneNumber
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        
        // Create a consistent hash using a fixed salt
        let hashInput = salt + cleanedNumber
        let hash = SHA256.hash(data: Data(hashInput.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func compareContacts(phoneNumber: String, firstName: String, lastName: String) {
        if processedPhoneNumbers.contains(phoneNumber) {
            return
        }
        
        processedPhoneNumbers.insert(phoneNumber)
        
        let hashedPhoneNumber = hashPhoneNumber(phoneNumber)
        
        db.collection("users").whereField("phoneNumberHash", isEqualTo: hashedPhoneNumber).getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching documents: \(error.localizedDescription)")
                    return
                }
                if let snapshot = snapshot, !snapshot.documents.isEmpty {
                    for doc in snapshot.documents {
                        let data = doc.data()
                        if let username = data["username"] as? String,
                           !self.currentUserFriends.contains(doc.documentID) {
                            let newContact = Contact(firstName: firstName, lastName: lastName, username: username, phoneNumber: hashedPhoneNumber)
                            if !self.matchedUsers.contains(where: { $0.phoneNumber == hashedPhoneNumber }) {
                                self.matchedUsers.append(newContact)
                            }
                        }
                    }
                }
            }
        }
    }

    private func updateMatchedUsers() {
        self.matchedUsers = self.matchedUsers.filter { contact in
            !self.currentUserFriends.contains { friendID in
                self.db.collection("users").document(friendID).getDocument { snapshot, error in
                    if let error = error {
                        print("Error fetching user document: \(error)")
                        return
                    }
                    if let data = snapshot?.data(),
                       let username = data["username"] as? String,
                       username == contact.username {
                        DispatchQueue.main.async {
                            self.matchedUsers.removeAll { $0.username == username }
                        }
                    }
                }
                return false
            }
        }
    }
}
