import SwiftUI
import Contacts
import Firebase
import FirebaseFirestore
import PhoneNumberKit
import PostHog

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
    
    var hasAddedAnyFriends: Bool {
        matchedUsers.contains(where: { $0.isAdded })
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
    
    private func compareContacts(phoneNumber: String, firstName: String, lastName: String) {
        db.collection("users").whereField("phoneNumber", isEqualTo: phoneNumber).getDocuments { snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching documents: \(error.localizedDescription)")
                    return
                }
                if let snapshot = snapshot, !snapshot.documents.isEmpty {
                    for doc in snapshot.documents {
                        let data = doc.data()
                        if let username = data["username"] as? String, let phoneNumber = data["phoneNumber"] as? String {
                            let newContact = Contact(firstName: firstName, lastName: lastName, username: username, phoneNumber: phoneNumber)
                            self.matchedUsers.append(newContact)
                        }
                    }
                }
            }
        }
    }

}
