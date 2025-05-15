import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CreateCompetitionAddPlayersView: View {
    let competitionId: String
    let competitionName: String
    let competitionDate: Date
    @State var selectedFriends: Set<String> = []
    @State private var isLoading = true
    @State private var showAddFriendsView = false
    @ObservedObject var viewModel = MyFriendsModel()
    @State private var showCompetitionDetails = false
    @State private var competition: Competition?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
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
                    
                    Text("Add Players")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
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
                
                // Progress indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(Color(hex: "#FF4081"))
                        .frame(width: 8, height: 8)
                }
                .padding(.bottom, 20)
                
                // Main content
                VStack(spacing: 0) {
                    
                    // Friends list
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                        Spacer()
                    } else if viewModel.friends.isEmpty {
                        Spacer()
                        
                        Text("No Friends Yet")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.bottom, 10)
                        
                        Button(action: {
                            self.showAddFriendsView = true
                        }) {
                            Text("Add Friends")
                                .font(.system(size: 18, weight: .bold))
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
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                
                // Bottom buttons
                VStack(spacing: 15) {
                    if !selectedFriends.isEmpty {
                        Button(action: {
                            addSelectedFriends()
                        }) {
                            Text("Add \(selectedFriends.count) Friend\(selectedFriends.count == 1 ? "" : "s")")
                                .font(.system(size: 18, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(hex: "#FF4081"))
                                .foregroundColor(.white)
                                .cornerRadius(50)
                        }
                    }
                    
                    if selectedFriends.isEmpty {
                        Button(action: {
                            showCompetitionDetails = true
                        }) {
                            Text("Go to Competition")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(hex: "#FFF"))
                                .padding(.top, 10)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 20)
            }
        }
        .background(Color(hex: "#10183C"))
        .onAppear {
            viewModel.fetchFriends {
                isLoading = false
            }
            Analytics.shared.trackScreen(name: "create_competition_add_players")
        }
        .fullScreenCover(isPresented: $showAddFriendsView, onDismiss: {
            viewModel.fetchFriends {
                isLoading = false
            }
        }) {
            AddFriendsView(addFriendsModel: AddFriendsModel())
        }
        .fullScreenCover(isPresented: $showCompetitionDetails) {
            CompDetails(competition: Competition(
                id: competitionId,
                description: competitionName,
                date: competitionDate
            ))
        }
    }
    
    private func addSelectedFriends() {
        // Add selected friends to the competition
        let db = Firestore.firestore()
        let batch = db.batch()
        
        for friendId in selectedFriends {
            let memberRef = db.collection("competitions").document(competitionId)
                              .collection("members").document(friendId)
            batch.setData(["userId": friendId], forDocument: memberRef)
            
            let groupMembershipRef = db.collection("groupMemberships").document(friendId)
                                       .collection("competitions").document(competitionId)
            batch.setData(["competitionId": competitionId], forDocument: groupMembershipRef)
        }
        
        batch.commit { error in
            if let error = error {
                print("Failed to add friends: \(error.localizedDescription)")
            } else {
                showCompetitionDetails = true
                
                Analytics.shared.trackCompetition(
                    action: "add_friends",
                    competitionId: competitionId,
                    properties: ["friend_count": selectedFriends.count]
                )
            }
        }
    }
}
