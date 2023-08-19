import SwiftUI
import Contacts
import FirebaseFirestore
import FirebaseAuth

struct AppUser: Identifiable {
    var id: String // UID of the user
    var name: String
    var phoneNumber: String
}

struct HomeView: View {
    
    @State private var logoutSuccess = false
    @State private var appUsers: [AppUser] = []
    @State private var currentIndex: Int = 0

    func normalizePhoneNumber(_ number: String) -> String {
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

    var body: some View {
        VerticalPager(pageCount: appUsers.count, currentIndex: $currentIndex) {
            ForEach(appUsers, id: \.id) { user in
                ZStack {
                    Color.white.edgesIgnoringSafeArea(.all) // You can change this to any background color you like
                    Image("teddy-bear") // replace "your-image-name" with your image's name
                        .resizable()
                        .scaledToFit()
                        .frame(width: 175, height: 175) // change width and height according to your needs
                    VStack(alignment: .leading) {
                        Text(user.name)
                            .font(.system(size: 16, weight: .bold, design: .default)) // Updated
                            .padding(.leading, 30)
                            .padding(.top, 40)
                            .foregroundColor(.black)
                        Text("Tap to view")
                            .font(.system(size: 16, weight: .bold, design: .default)) // Updated
                            .padding(.leading, 30)
                            .padding(.top, 8)
                            .foregroundColor(Color(hex: "#1199FF"))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .onAppear {
            fetchContacts()
        }
        .navigationBarHidden(true)
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        // Your action for the left button
                    }) {
                        Image("Settings") // Replace with your image name
                            .resizable()
                            .frame(width: 45, height: 45)
                            .padding(.leading, 30)
                            .padding(.bottom, 20)
                    }
                    Spacer()
                    Button(action: {
                        // Your action for the right button
                    }) {
                        Image("Folder") // Replace with your image name
                            .resizable()
                            .frame(width: 45, height: 45)
                            .padding(.trailing, 30)
                            .padding(.bottom, 20)
                    }
                }
            }
        )
    }




}

struct VerticalPager<Content: View>: View {
    let pageCount: Int
    @Binding var currentIndex: Int
    let content: Content

    @GestureState private var translation: CGFloat = 0

    init(pageCount: Int, currentIndex: Binding<Int>, @ViewBuilder content: () -> Content) {
        self.pageCount = pageCount
        self._currentIndex = currentIndex
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            LazyVStack(spacing: 0) {
                self.content.frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.primary.opacity(0.000000001))
            .offset(y: -CGFloat(self.currentIndex) * geometry.size.height)
            .offset(y: self.translation)
            .animation(.interactiveSpring(response: 0.3), value: currentIndex)
            .animation(.interactiveSpring(), value: translation)
            .gesture(
                DragGesture(minimumDistance: 1).updating(self.$translation) { value, state, _ in
                    state = value.translation.height
                }.onEnded { value in
                    let offset = -Int(value.translation.height)
                    if abs(offset) > 20 {
                        let newIndex = currentIndex + min(max(offset, -1), 1)
                        if newIndex >= 0 && newIndex < pageCount {
                            self.currentIndex = newIndex
                        }
                    }
                }
            )
        }
    }
}

