import SwiftUI
import Contacts
import FirebaseFirestore

struct Contact: Identifiable {
    var id: String // We'll use the phone number as the ID since it's unique
    var givenName: String
    var familyName: String
    var phoneNumber: String {
        didSet {
            self.id = phoneNumber
        }
    }
    var hasApp: Bool = false
    
    init(givenName: String, familyName: String, phoneNumber: String) {
        self.givenName = givenName
        self.familyName = familyName
        self.phoneNumber = phoneNumber
        self.id = phoneNumber
    }
}

func fetchContacts() -> [Contact] {
    let store = CNContactStore()
    let keysToFetch = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
    let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
    
    var contacts: [Contact] = []
    
    do {
        try store.enumerateContacts(with: fetchRequest) { (contact, stop) in
            if let phoneNumber = contact.phoneNumbers.first?.value.stringValue {
                let newContact = Contact(givenName: contact.givenName, familyName: contact.familyName, phoneNumber: phoneNumber)
                contacts.append(newContact)
            }
        }
    } catch {
        print("Failed to fetch contacts:", error)
    }
    
    return contacts
}

struct ContactsView: View {
    @State private var contacts: [Contact] = []
    @Binding var isShown: Bool  // This is the binding to control showing the modal
    @Binding var selectedContact: Contact?  // This binding variable will signal chat initiation
    
    var body: some View {
        VStack {
            // Top bar with close button
            HStack {
                Spacer()
                Button(action: {
                    isShown = false  // This will dismiss the modal
                }) {
                    Image(systemName: "xmark")  // Using the system image for "X"
                        .resizable()
                        .frame(width: 20, height: 20)
                        .padding()
                        .foregroundColor(.black)
                }
            }
            
            // List of contacts
            List(contacts) { contact in
                if contact.hasApp {
                    Button(action: {
                        self.selectedContact = contact
                        isShown = false
                    }) {
                        HStack {
                            Text(contact.givenName + " " + contact.familyName)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                } else {
                    HStack {
                        Text(contact.givenName + " " + contact.familyName)
                        Spacer()
                    }
                }
            }
            .onAppear {
                self.contacts = fetchContacts()
                checkWhichContactsHaveApp()
            }
        }
        .background(Color.white)
        .edgesIgnoringSafeArea(.all)
    }

    func checkWhichContactsHaveApp() {
        let db = Firestore.firestore()
        
        for (index, contact) in contacts.enumerated() {
            let phoneNumber = contact.phoneNumber
            
            db.collection("users")
              .whereField("phoneNumber", isEqualTo: phoneNumber)
              .getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error fetching users: \(error.localizedDescription)")
                } else if let snapshot = snapshot, !snapshot.isEmpty {
                    self.contacts[index].hasApp = true
                }
            }
        }
    }
}
