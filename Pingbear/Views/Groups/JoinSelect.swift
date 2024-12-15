import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import PostHog

struct JoinSelectView: View {
    
    @State var selectedFriends: Set<String> = [] // Tracks selected friends
    @State var currentUserId: String = Auth.auth().currentUser?.uid ?? ""
    @State private var isPresentingCompDetails = false
    @State private var username: String = ""
    @State private var messageStatus: MessageStatus? = nil
    
    var competition: Competition // this holds the selected competition details
    
    @ObservedObject var viewModel: MyFriendsModel // Add this line
    @ObservedObject var viewModel2: AddFriendsModel
    
    enum MessageStatus {
        case error(String), success(String), none
    }

    func processUsername(_ username: String) -> String {
        return username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    isPresentingCompDetails = true
                }) {
                    Image(systemName: "arrow.left")
                        .resizable() // Allows resizing of the image
                        .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                        .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                        .foregroundColor(Color.black) // Your desired color
                }
                
                Spacer()
                
                Text("Add Friends to Group")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
            
                }) {
                    Image(systemName: "arrow.left")
                        .resizable() // Allows resizing of the image
                        .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                        .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                        .foregroundColor(Color.black) // Your desired color
                }
                .opacity(0)
                
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            
            VStack {
                
                // Radio buttons for selection
                HStack(alignment: .center, spacing: 10) {
                    TextField("Enter friend's username", text: $username)
                        .padding()
                        .padding(.vertical, 5)
                        .background(Color(hex: "#F5F5F5"))
                        .foregroundColor(Color(hex: "#000"))
                        .cornerRadius(10)
                        .font(.system(size: 16, weight: .bold, design: .default))
                    
                    Button(action: {
                        let processedUsername = processUsername(username)
                        viewModel2.addFriend(byUsername: processedUsername) { (success, error) in
                            if success {
                                findAndAddFriendByUsername(processedUsername)
                            } else {
                                messageStatus = .error("Failed to add friend")
                            }
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold, design: .default))
                            .padding()
                            .padding(.vertical, 5)
                            .background(Color(hex: "#1199FF"))
                            .foregroundColor(Color(hex: "#fff"))
                            .cornerRadius(10)
                    }
                }
                .padding(.top, 15)
                
                if let status = messageStatus {
                    switch status {
                    case .error(let message):
                        Text(message)
                            .foregroundColor(Color(hex: "#CC2255"))
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .padding(.top, 30)
                            .padding(.horizontal)
                    case .success(let message):
                        Text(message)
                            .foregroundColor(Color(hex: "#008000"))
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .padding(.top, 30)
                            .padding(.horizontal)
                    case .none:
                        EmptyView()
                    }
                }
                
                // List of friends and Add Friends Button
                HStack {
                    Text("My Friends")
                        .font(.system(size: 16, weight: .bold, design: .default))
                    
                    Spacer()
                    
                }
                .padding(.top, 25)
                .padding(.bottom, 25)
                .frame(maxWidth: .infinity)
                
                
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(viewModel.friends, id: \.id) { friend in // Use the real friends data
                            SelectableFriendView(friend: friend.name, isSelected: self.selectedFriends.contains(friend.id)) { // Change from 'friend' to 'friend.id' if necessary
                                if self.selectedFriends.contains(friend.id) {
                                    self.selectedFriends.remove(friend.id)
                                } else {
                                    self.selectedFriends.insert(friend.id)
                                }
                            }
                        }
                    }
                }
                
                Button(action: {
                    updateCompetitionAllowJoin()
                    isPresentingCompDetails = true
                }) {
                    Text("Continue")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(!self.selectedFriends.isEmpty ? Color(hex: "#1199FF") : Color.gray) // Change button
                        .foregroundColor(Color(hex: "#fff"))
                        .cornerRadius(200)
                }
                .padding(.top, 10)
                .padding(.bottom, 10)
                
            }
            .padding(.horizontal)
        }
        .onAppear {
            viewModel.fetchFriends() // Fetch friends when the view appears
        }
        .fullScreenCover(isPresented: $isPresentingCompDetails) {
            // Pass the competition object to CompDetails
            CompDetails(competition: competition)
        }
    }
    
    private func findAndAddFriendByUsername(_ username: String) {
        let db = Firestore.firestore()
        db.collection("users").whereField("username", isEqualTo: username).getDocuments { (querySnapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                for document in querySnapshot!.documents {
                    let userId = document.documentID
                    isUserAlreadyMember(userId: userId) { isAlreadyMember in
                        if !isAlreadyMember {
                            selectedFriends.insert(userId)
                            updateCompetitionAllowJoin()
                        } else {
                            messageStatus = .error("Friend Already a Member")
                        }
                    }
                }
            }
        }
    }
    
    private func isUserAlreadyMember(userId: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        db.collection("groupMemberships").document(userId)
            .collection("competitions").whereField("competitionId", isEqualTo: competition.id)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error checking membership: \(error)")
                    completion(false)
                } else if let snapshot = snapshot, !snapshot.documents.isEmpty {
                    completion(true)
                } else {
                    completion(false)
                }
            }
    }
    
    func updateCompetitionAllowJoin() {
        let db = Firestore.firestore()
        let currentUserRef = db.collection("users").document(currentUserId)
        
        currentUserRef.getDocument { (document, error) in
            if let document = document, let username = document.data()?["username"] as? String {
                self.updateCompetitionWithNotifications(username: username)
            } else {
                print("Failed to fetch username for current user.")
            }
        }
    }
    
    func updateCompetitionWithNotifications(username: String) {
        let db = Firestore.firestore()
        let batch = db.batch()
        let dispatchGroup = DispatchGroup()

        for userId in selectedFriends {
            dispatchGroup.enter()
            isUserAlreadyMember(userId: userId) { isMember in
                if !isMember {
                    let memberRef = db.collection("competitions").document(self.competition.id).collection("members").document(userId)
                    let memberData: [String: Any] = ["userId": userId]
                    batch.setData(memberData, forDocument: memberRef)

                    let membershipRef = db.collection("groupMemberships").document(userId).collection("competitions").document(self.competition.id)
                    let membershipData: [String: Any] = ["competitionId": self.competition.id]
                    batch.setData(membershipData, forDocument: membershipRef)

                    // Send notification
                    self.sendNotificationToUser(userId: userId, username: username, competitionDescription: self.competition.description)
                    PostHogSDK.shared.capture("Friend Added to Group", properties: ["userId": userId])
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            batch.commit { err in
                if let err = err {
                    print("Error writing batch: \(err)")
                } else {
                    print("Batch write succeeded.")
                    DispatchQueue.main.async {
                        self.isPresentingCompDetails = true
                    }
                }
            }
        }
    }

    func sendNotificationToUser(userId: String, username: String, competitionDescription: String) {
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { (document, error) in
            if let document = document, let fcmToken = document.data()?["fcmToken"] as? String {
                let title = competitionDescription
                let message = "\(username) added you to the group"
                // Assuming you have a mechanism to send push notifications
                PushNotificationSender().sendPushNotification(to: fcmToken, title: title, body: message)
            }
        }
    }

}

// SelectableFriendView component
struct SelectableFriendView: View {
    var friend: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(friend)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(2)
                    .lineSpacing(9)
                    .foregroundColor(.black)
                    .truncationMode(.tail)
                    .padding(.leading, 10) // Increased padding
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? Color(hex: "#1199FF") : .black)
                
            }
            .padding(20)
            .padding(.vertical, 3)
            .background(isSelected ? Color(hex: "#1199FF").opacity(0.2) : Color(hex: "#F5F5F5"))
            .cornerRadius(5)
        }
    }
}

// RadioButtonField component
struct RadioButtonField: View {
    let id: String
    let label: String
    let isMarked: Bool
    let callback: (String) -> ()
    
    init(
        id: String,
        label: String,
        isMarked: Bool = false,
        callback: @escaping (String) -> ()
    ) {
        self.id = id
        self.label = label
        self.isMarked = isMarked
        self.callback = callback
    }

    var body: some View {
        Button(action: {
            self.callback(self.id)
        }) {
            HStack(alignment: .center, spacing: 20) {
                Image(systemName: self.isMarked ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(self.isMarked ? Color(hex: "#1199FF") : .black)
                Text(self.label)
                    .foregroundColor(Color.black)
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .background(Color(hex: "#F5F5F5")) 
            .cornerRadius(20)
        }
    }
}
