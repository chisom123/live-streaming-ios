import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct JoinSelectView: View {
    @State var selectedFriends: Set<String> = []
    @State var currentUserId: String = Auth.auth().currentUser?.uid ?? ""
    @State private var isPresentingCompDetails = false
    @State private var isShareSheetPresented = false
    @State private var showAddFriendsView = false
    @State private var isLoading = true
    @State private var showMinimumPlayersAlert = false
    @State private var currentMemberCount: Int = 0
    @Environment(\.presentationMode) var presentationMode
    
    var competition: Competition
    @ObservedObject var viewModel: MyFriendsModel
    
    var body: some View {
        ZStack {
            
            VStack {
                // Header
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Add Players to Competition")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    Button(action: {
                        self.showAddFriendsView = true
                    }) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                VStack {
                    // Invite Friends Button
                    Button(action: {
                        isShareSheetPresented = true
                        Analytics.shared.trackTap(
                            elementId: "invite_share_sheet",
                            screenName: "add_players"
                        )
                    }) {
                        HStack {
                            Text("Invite Friends to Play")
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: "#FFF"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 10)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color(hex: "#D3D3D3"))
                                .padding(.trailing, 10)
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .padding(.vertical, 5)
                        .background(Color(hex: "#1A2245"))
                        .cornerRadius(10)
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
                            .foregroundColor(.white)
                            .padding(.bottom, 10)
                        
                        Button(action: {
                            self.showAddFriendsView = true
                        }) {
                            Text("Add Friends")
                                .font(.system(size: 18, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: "#FF4081"))
                        }
                        
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(viewModel.friends, id: \.id) { friend in
                                    VStack(spacing: 0) {
                                        SelectableFriendView(
                                            friend: friend.name,
                                            profileImageUrl: friend.profileImageUrl,
                                            isSelected: self.selectedFriends.contains(friend.id)
                                        ) {
                                            if self.selectedFriends.contains(friend.id) {
                                                self.selectedFriends.remove(friend.id)
                                            } else {
                                                self.selectedFriends.insert(friend.id)
                                            }
                                        }
                                        
                                        if friend.id != viewModel.friends.last?.id {
                                            Divider()
                                                .background(Color.white.opacity(0.2))
                                        }
                                    }
                                }
                            }
                            .background(Color(hex: "#1A2245"))
                            .cornerRadius(10)
                        }
                    }
                    
                    if !selectedFriends.isEmpty && (currentMemberCount + selectedFriends.count) < 3 {
                        Text("\(3 - (currentMemberCount + selectedFriends.count)) More Player Needed")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "#FFF"))
                            .padding(.top, 10)
                    }
                    
                    Button(action: {
                        if (currentMemberCount + selectedFriends.count) >= 3 {
                            updateCompetitionAllowJoin()
                            isPresentingCompDetails = true
                        } else {
                            showMinimumPlayersAlert = true
                            Analytics.shared.track(
                                event: "minimum_player_alert_shown",
                                properties: ["competition_id": competition.id]
                            )
                        }
                    }) {
                        Text("Continue")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .background(!self.selectedFriends.isEmpty ? Color(hex: "#FF4081") : Color(hex: "#D3D3D3").opacity(0.2))
                            .foregroundColor(!self.selectedFriends.isEmpty ? Color(hex: "#FFF") : Color(hex: "#D3D3D3").opacity(0.2))
                            .cornerRadius(200)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    .disabled(self.selectedFriends.isEmpty)
                }
                .padding(.horizontal)
            }
        }
        .background(Color(hex: "#10183C"))
        .onAppear {
            fetchMemberCount()
            viewModel.fetchFriends {
                isLoading = false
            }
            Analytics.shared.trackScreen(name: "add_players")
        }
        .fullScreenCover(isPresented: $isPresentingCompDetails) {
            CompDetails(competition: competition)
        }
        .fullScreenCover(isPresented: $showAddFriendsView, onDismiss: {
            viewModel.fetchFriends {
                isLoading = false
            }
        }) {
            AddFriendsView(addFriendsModel: AddFriendsModel())
        }
        .alert(isPresented: $showMinimumPlayersAlert) {
            Alert(
                title: Text("1 More Player Needed to Continue"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func fetchMemberCount() {
        let db = Firestore.firestore()
        db.collection("competitions")
            .document(competition.id)
            .collection("members")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching member count: \(error)")
                    return
                }
                
                DispatchQueue.main.async {
                    self.currentMemberCount = snapshot?.documents.count ?? 0
                }
            }
    }
    
    private func createShareText() -> String {
        return "apps.apple.com/app/socialstar-social-competition/id6473705189"
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
        let dispatchGroup = DispatchGroup()
        
        // Changed from batch write to sequential operations
        for userId in selectedFriends {
            dispatchGroup.enter()
            
            // STEP 1: First add to competition members collection
            // This establishes membership which is required by security rules
            let memberRef = db.collection("competitions")
                .document(competition.id)
                .collection("members")
                .document(userId)
            
            memberRef.setData(["userId": userId]) { error in
                if let error = error {
                    print("Error adding member: \(error)")
                    dispatchGroup.leave()
                    return
                }
                
                // STEP 2: Now that membership is established, we can add to groupMemberships
                // This should now work because the security rules can verify membership
                let membershipRef = db.collection("groupMemberships")
                    .document(userId)
                    .collection("competitions")
                    .document(competition.id)
                
                membershipRef.setData(["competitionId": competition.id]) { error in
                    if let error = error {
                        print("Error adding to groupMemberships: \(error)")
                    } else {
                        // Analytics event only tracked on successful addition
                        Analytics.shared.trackCompetition(
                            action: "join",
                            competitionId: competition.id,
                            properties: ["user_id": userId]
                        )
                    }
                    dispatchGroup.leave()
                }
            }
        }

        // Wait for all operations to complete before continuing
        dispatchGroup.notify(queue: .main) {
            DispatchQueue.main.async {
                self.isPresentingCompDetails = true
            }
        }
    }
}

// Helper Views
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

struct SelectableFriendView: View {
    var friend: String
    var profileImageUrl: String?
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                HStack(spacing: 20) {
                    ProfilePictureView(url: profileImageUrl, size: 40)
                    
                    Text(friend)
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                        .lineSpacing(9)
                        .foregroundColor(.white)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, 30)
                
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? Color(hex: "#FF4081") : .white)
                    .padding(.trailing, 30)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(isSelected ? Color(hex: "#FF4081").opacity(0.2) : Color.clear)
        }
    }
}

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
                    .foregroundColor(self.isMarked ? Color(hex: "#FF4081") : .white)
                Text(self.label)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .background(Color(hex: "#1A2245"))
            .cornerRadius(20)
        }
    }
}
