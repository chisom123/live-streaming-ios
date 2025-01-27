import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import PostHog

struct JoinSelectView: View {
    
    @State var selectedFriends: Set<String> = [] // Tracks selected friends
    @State var currentUserId: String = Auth.auth().currentUser?.uid ?? ""
    @State private var isPresentingCompDetails = false
    @State private var isShareSheetPresented = false
    @State private var isLoading = true // Track loading state
    
    var competition: Competition // this holds the selected competition details
    
    @ObservedObject var viewModel: MyFriendsModel // Add this line
    
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
                
                Text("Add Players to Competition")
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
                Button(action: {
                    // Open share sheet
                    isShareSheetPresented = true
                    PostHogSDK.shared.capture("Invite Share Sheet Tapped")
                }) {
                    HStack() { // Align by text baseline
                        Text("Invite Friends to Play")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "#1199FF"))
                            .truncationMode(.tail)
                            .padding(.leading, 10)
                        
                        Spacer()
                        
                        Image(systemName: "square.and.arrow.up")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25) // Increase the size
                            .font(.system(size: 25, weight: .bold)) // Apply bold weight
                            .foregroundColor(Color(hex: "#1199FF"))

                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color(hex: "#F5F5F5"))
                    .cornerRadius(5)
                    .padding(.bottom, 20)
                }
                .sheet(isPresented: $isShareSheetPresented) {
                    ActivityViewController(activityItems: [createShareText()])
                }
                
                if isLoading {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.friends.isEmpty {
                    Spacer()
                    Text("No Friends Yet")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .foregroundColor(.gray)
                    Spacer()
                } else {
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
                }
                
                Button(action: {
                    updateCompetitionAllowJoin()
                    isPresentingCompDetails = true
                }) {
                    Text("Continue")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(!self.selectedFriends.isEmpty ? Color(hex: "#1199FF") : Color(hex: "#D3D3D3")) // Change button
                        .foregroundColor(Color(hex: "#fff"))
                        .cornerRadius(200)
                }
                .padding(.top, 10)
                .padding(.bottom, 10)
                .disabled(self.selectedFriends.isEmpty)
                
            }
            .padding(.horizontal)
        }
        .onAppear {
            viewModel.fetchFriends {
                isLoading = false // Set loading to false after fetching friends
            }
        }
        .fullScreenCover(isPresented: $isPresentingCompDetails) {
            // Pass the competition object to CompDetails
            CompDetails(competition: competition)
        }
    }
    
    private func createShareText() -> String {
        return "pingbearapp.com"
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
                    
                    PostHogSDK.shared.capture("Friend Added to Competition", properties: ["userId": userId])
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

}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
