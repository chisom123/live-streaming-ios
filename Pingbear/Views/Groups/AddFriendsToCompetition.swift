import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import PostHog

struct AddFriendsToCompetition: View {
    let competitionName: String
    @ObservedObject var viewModel: MyFriendsModel
    @ObservedObject var addFriendsModel: AddFriendsModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedFriends: Set<String> = []
    @State private var username: String = ""
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
                
                Text("Add 2 Friends to Start")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.horizontal)
                    .onAppear {
                        PostHogSDK.shared.capture("Add 2+ Friends View Opened")
                    }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(.black)
                }
                .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            
            VStack {
                // Add friend by username
                HStack(alignment: .center, spacing: 10) {
                    TextField("Enter friend's username", text: $username)
                        .padding()
                        .padding(.vertical, 5)
                        .background(Color(hex: "#F5F5F5"))
                        .foregroundColor(Color(hex: "#000"))
                        .cornerRadius(5)
                        .font(.system(size: 16, weight: .bold, design: .default))
                    
                    Button(action: {
                        addFriendByUsername()
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold, design: .default))
                            .padding()
                            .padding(.vertical, 5)
                            .background(Color(hex: "#1199FF"))
                            .foregroundColor(Color(hex: "#fff"))
                            .cornerRadius(5)
                    }
                }
                .padding(.top, 15)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(Color(hex: "#CC2255"))
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .padding(.top, 30)
                        .padding(.horizontal)
                }
                
                // Friends list header
                HStack {
                    Text("My Friends")
                        .font(.system(size: 16, weight: .bold, design: .default))
                    Spacer()
                }
                .padding(.top, 25)
                .padding(.bottom, 25)
                .frame(maxWidth: .infinity)
                
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
    }
    
    private func addFriendByUsername() {
        let processedUsername = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // First find the user ID for the username
        let db = Firestore.firestore()
        db.collection("users").whereField("username", isEqualTo: processedUsername).getDocuments { [self] (querySnapshot, err) in
            if let err = err {
                errorMessage = "Error finding user: \(err.localizedDescription)"
                return
            }
            
            guard let document = querySnapshot?.documents.first else {
                errorMessage = "Failed to add friend"
                return
            }
            
            let friendId = document.documentID
            
            // Then add the friend using the existing model
            addFriendsModel.addFriend(byUsername: processedUsername) { [self] success, error in
                if success {
                    // After successful addition, fetch updated friends list and select the new friend
                    viewModel.fetchFriends { [self] in
                        selectedFriends.insert(friendId)
                        username = ""
                        errorMessage = nil
                        hideKeyboard()
                    }
                } else {
                    errorMessage = error?.localizedDescription ?? "Failed to add friend"
                }
            }
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
