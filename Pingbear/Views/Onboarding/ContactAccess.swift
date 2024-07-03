import SwiftUI
import Contacts
import Firebase
import FirebaseFirestore
import PhoneNumberKit
import PostHog

struct Contact {
    var name: String
    var username: String
    var phoneNumber: String
    var isAdded: Bool = false
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
            let keysToFetch = [CNContactGivenNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
            let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)

            do {
                try store.enumerateContacts(with: fetchRequest) { (contact, stopPointer) in
                    contact.phoneNumbers.forEach { phoneNumber in
                        let rawPhoneNumber = phoneNumber.value.stringValue
                        let cleanedPhoneNumber = self.formatPhoneNumber(rawPhoneNumber)
                        if let formattedNumber = cleanedPhoneNumber {
                            DispatchQueue.main.async {
                                self.compareContacts(phoneNumber: formattedNumber, contactName: contact.givenName)
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
    
    private func compareContacts(phoneNumber: String, contactName: String) {
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
                            let newContact = Contact(name: contactName, username: username, phoneNumber: phoneNumber)
                            self.matchedUsers.append(newContact)
                        }
                    }
                }
            }
        }
    }

}

struct ContactAccessView: View {
    @ObservedObject var viewModel = ContactViewModel()
    @StateObject var addFriendModel = AddFriendsModel()
    
    @State private var goHome = false
    @State private var addFriend = false

    var body: some View {
        VStack {
            
            HStack {
                
                Button(action: {
                    addFriend = true
                    PostHogSDK.shared.capture("Person Badge Plus button Pressed")
                }) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 23, weight: .bold, design: .default))
                        .foregroundColor(Color(hex: "#1199FF"))
                }
                
                Spacer()
                
                Text("Add Friends")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    .padding(.horizontal)
                
                Spacer()
                
                Button("Skip") {
                    goHome = true
                    PostHogSDK.shared.capture("Skip button Pressed (Contact Access)")
                }
                .font(.system(size: 15.5, weight: .bold, design: .default))
                .foregroundColor(Color.gray)
            }
            .padding(.horizontal, 5)
            .padding(.bottom, 5)
            
            ScrollView {
                VStack(spacing: 25) {
                    ForEach(viewModel.matchedUsers.indices, id: \.self) { index in
                        Button(action: {
                            if !viewModel.matchedUsers[index].isAdded {
                                addFriendModel.addFriend(byUsername: viewModel.matchedUsers[index].username) { success, error in
                                    if success {
                                        DispatchQueue.main.async {
                                            viewModel.matchedUsers[index].isAdded = true
                                            PostHogSDK.shared.capture("Friend successfully added")
                                        }
                                    } else if let error = error {
                                        print("Error adding friend: \(error.localizedDescription)")
                                    }
                                }
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 18) {
                                    Text(viewModel.matchedUsers[index].name)
                                        .font(.system(size: 16, weight: .bold, design: .default))
                                        .foregroundColor(.black)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 6) { // Control spacing between text and icon
                                    Text(viewModel.matchedUsers[index].isAdded ? "Added" : "Add")
                                        .fontWeight(.bold)
                                        .foregroundColor(viewModel.matchedUsers[index].isAdded ? Color.green : Color(hex: "#1199FF"))
                                        .font(.system(size: 16, weight: .bold, design: .default))
                                    
                                    Image(systemName: viewModel.matchedUsers[index].isAdded ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundColor(viewModel.matchedUsers[index].isAdded ? Color.green : Color(hex: "#1199FF"))
                                        .font(.system(size: 16, weight: .bold, design: .default))
                                }
                                
                            }
                            .padding(.vertical, 25)
                            .padding(.horizontal, 20)
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                        }
                        .disabled(viewModel.matchedUsers[index].isAdded)
                    }
                }
                .padding(.top, 25)
            }
            
            Spacer()
            
            if viewModel.hasAddedAnyFriends {
                Button(action: {
                    goHome = true
                    PostHogSDK.shared.capture("Continue Button Pressed (Contact Access View)")
                }) {
                    Text("Continue")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(viewModel.hasAddedAnyFriends ? Color(hex: "#1199FF") : Color.gray)
                        .foregroundColor(Color(hex: "#fff"))
                        .cornerRadius(200)
                }
                .padding(.top, 10)
                .disabled(!viewModel.hasAddedAnyFriends)
            }
            
        }
        .padding()
        .onAppear {
            viewModel.requestContactAccess()
        }
        .fullScreenCover(isPresented: $goHome, content: {
            ContentView()
        })
        .fullScreenCover(isPresented: $addFriend, content: {
            FriendWall(viewModel: MyFriendsModel(), viewModel2: AddFriendsModel())
        })
    }

}
