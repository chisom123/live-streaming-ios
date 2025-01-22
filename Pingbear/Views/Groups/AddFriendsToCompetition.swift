import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import PostHog

struct AddFriendsToCompetition: View {
    let competitionName: String
    @ObservedObject var viewModel: MyFriendsModel
    @State private var showAddFriendsView = false
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedFriends: Set<String> = []
    @State private var errorMessage: String? = nil
    @State private var competition: Competition? = nil
    @State private var isProcessing = false
    
    var buttonText: String {
        let friendsNeeded = 2 - selectedFriends.count
        if isProcessing {
            return "Continue"
        } else if friendsNeeded > 0 {
            return "\(friendsNeeded) more friend\(friendsNeeded == 1 ? "" : "s") needed"
        } else {
            return "Continue"
        }
    }
    
    var body: some View {
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
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                Text("Add Friends to Competition")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.horizontal)
                    .truncationMode(.tail) // Adds an ellipsis at the end of the text if it's too long
                    .lineLimit(1) // Ensures the text is on a single line
                    .onAppear {
                        PostHogSDK.shared.capture("Add 2+ Friends View Opened")
                    }
                
                Spacer()
                
                Button(action: {
                    self.showAddFriendsView = true
                }) {
                    Image(systemName: "person.fill.badge.plus")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            
            VStack {
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(Color(hex: "#CC2255"))
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .padding(.top, 20)
                        .padding(.horizontal)
                }

                if viewModel.friends.isEmpty {
                    Spacer()
                    EmptyFriendsView(openSnapchatAction: shareToSnapchat)
                    Spacer()
                } else {
                    // Friends list
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(viewModel.friends) { friend in
                                SelectableFriendView(
                                    friend: friend.name,
                                    isSelected: selectedFriends.contains(friend.id)
                                ) {
                                    if selectedFriends.contains(friend.id) {
                                        selectedFriends.remove(friend.id)
                                    } else {
                                        selectedFriends.insert(friend.id)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Create Competition button
                Button(action: {
                    if !isProcessing {
                        isProcessing = true
                        createCompetition()
                    }
                }) {
                    Text(buttonText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(selectedFriends.count >= 2 ? Color(hex: "#1199FF") : Color.gray)
                        .foregroundColor(Color(hex: "#fff"))
                        .cornerRadius(200)
                }
                .disabled(selectedFriends.count < 2 || isProcessing)
                .padding(.top, 10)
                .padding(.bottom, 10)
            }
            .padding(.horizontal)
        }
        .onAppear {
            viewModel.fetchFriends()
        }
        .fullScreenCover(item: $competition) { comp in
            CompDetails(competition: comp)
        }
        .fullScreenCover(isPresented: $showAddFriendsView, onDismiss: {
            viewModel.fetchFriends()
        }) {
            AddFriendsView(addFriendsModel: AddFriendsModel())
        }
    }
    
    private func shareToSnapchat() {
        PostHogSDK.shared.capture("Share to Snapchat Tapped")
        
        do {
            try SnapchatShare.openSnapchat()
        } catch SnapError.snapchatNotInstalled {
            errorMessage = "Snapchat not installed"
        } catch {
            errorMessage = "Failed to share to Snapchat"
        }
    }
    
    private func createCompetition() {
        guard let userID = Auth.auth().currentUser?.uid else {
            errorMessage = "User not logged in"
            return
        }
        
        guard selectedFriends.count >= 2 else {
            errorMessage = "Please select at least 2 friends"
            return
        }
        
        let db = Firestore.firestore()
        let competitionRef = db.collection("competitions").document()
        let competitionId = competitionRef.documentID
        isProcessing = true
        
        // Step 1: Create competition and creator's initial membership (can be batched)
        let batch = db.batch()
        
        batch.setData([
            "description": competitionName,
            "timestamp": Timestamp()
        ], forDocument: competitionRef)
        
        batch.setData([
            "userId": userID
        ], forDocument: competitionRef.collection("members").document(userID))
        
        batch.commit { [self] error in
            if let error = error {
                errorMessage = "Failed to create competition: \(error.localizedDescription)"
                isProcessing = false
                return
            }
            
            // Step 2: Create creator's membership
            let creatorMembershipRef = db.collection("groupMemberships")
                .document(userID)
                .collection("competitions")
                .document(competitionId)
            
            creatorMembershipRef.setData(["competitionId": competitionId]) { [self] error in
                if let error = error {
                    errorMessage = "Failed to create creator's membership: \(error.localizedDescription)"
                    isProcessing = false
                    return
                }
                
                // Step 3: Add friends (can be parallel after initial setup)
                var completedFriends = 0
                var failedFriends: [String] = []
                
                for friendId in selectedFriends {
                    // First add friend as member
                    let memberRef = competitionRef.collection("members").document(friendId)
                    memberRef.setData(["userId": friendId]) { error in  // Removed [self]
                        if let error = error {
                            failedFriends.append(friendId)
                            checkCompletion()
                            return
                        }
                        
                        // Then create friend's membership
                        let membershipRef = db.collection("groupMemberships")
                            .document(friendId)
                            .collection("competitions")
                            .document(competitionId)
                        
                        membershipRef.setData(["competitionId": competitionId]) { error in  // Removed [self]
                            if let error = error {
                                failedFriends.append(friendId)
                            }
                            checkCompletion()
                        }
                    }
                }
                
                // Helper function to check completion and handle results
                func checkCompletion() {
                    completedFriends += 1
                    
                    if completedFriends == selectedFriends.count {
                        if !failedFriends.isEmpty {
                            errorMessage = "Failed to add friends"
                            isProcessing = false
                        } else {
                            PostHogSDK.shared.capture("Competition Created", properties: [
                                "name": competitionName,
                                "friendsCount": selectedFriends.count
                            ])
                            
                            competition = Competition(
                                id: competitionId,
                                description: competitionName,
                                date: Date()
                            )
                        }
                    }
                }
            }
        }
    }
}

struct EmptyFriendsView: View {
    var openSnapchatAction: () -> Void
    
    var body: some View {
        VStack {
            Text("Invite Friends")
                .font(.system(size: 21, weight: .bold, design: .default))
                .foregroundColor(.black) // Set the text color as needed
                .padding(.top, 20)
                .padding(.bottom, 20)
            
            Text("Please invite 2+ friends to start this competition")
                .font(.system(size: 17, weight: .bold, design: .default))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .padding(.bottom, 25)
            
            Button(action: openSnapchatAction) {
                ZStack {
                    HStack {
                        Image("Snapchat")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .padding(.leading, 8)
                        Spacer()
                    }
                    
                    Text("Open Snapchat")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(height: 44)
                .frame(maxWidth: .infinity, minHeight: 44)
                .font(.system(size: 18, weight: .bold, design: .default))
                .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .background(Color(hex: "#fffc00"))
                .foregroundColor(Color(hex: "#000"))
                .cornerRadius(200)
            }
            .padding(.bottom, 20)
        }
        .padding(20)
        .background(Color(hex: "#F5F5F5"))
        .cornerRadius(5)
    }
}
