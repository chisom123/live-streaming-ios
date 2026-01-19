import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AssignLinkToFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var friendsModel = MyFriendsModel()
    @State private var selectedFriendId: String?
    @State private var usernameInput: String = ""
    @State private var isLoadingFriends = true
    @State private var isSearchingUsername = false
    @State private var searchError: String?
    @State private var searchedUser: AppUser?
    @State private var selectionMode: SelectionMode = .friendsList
    
    var onFriendSelected: (AppUser) -> Void
    
    enum SelectionMode {
        case friendsList
        case usernameSearch
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Mode Selector - Custom styled segmented control
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectionMode = .friendsList
                            }
                        }) {
                            Text("Friends List")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    selectionMode == .friendsList
                                        ? Color(hex: "#2A3356")
                                        : Color.clear
                                )
                                .cornerRadius(200)
                        }
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectionMode = .usernameSearch
                            }
                        }) {
                            Text("Enter Username")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    selectionMode == .usernameSearch
                                        ? Color(hex: "#2A3356")
                                        : Color.clear
                                )
                                .cornerRadius(200)
                        }
                    }
                    .padding(4)
                    .background(Color(hex: "#1A2245"))
                    .cornerRadius(200)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(hex: "#10183C"))
                
                if selectionMode == .friendsList {
                    friendsListView
                } else {
                    usernameSearchView
                }
                
                // Continue Button
                Button(action: {
                    if let friend = getSelectedFriend() {
                        Analytics.shared.trackTap(
                            elementId: "assign_link_continue",
                            screenName: "assign_link_to_friend",
                            properties: [
                                "selection_mode": selectionMode == .friendsList ? "friends_list" : "username_search",
                                "assigned_user_id": friend.id
                            ]
                        )
                        onFriendSelected(friend)
                        dismiss()
                    }
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, 8)
                        .background(getSelectedFriend() != nil ? Color(hex: "#4169E1") : Color(hex: "#D3D3D3").opacity(0.2))
                        .foregroundColor(getSelectedFriend() != nil ? .white : Color(hex: "#D3D3D3").opacity(0.2))
                        .cornerRadius(200)
                }
                .disabled(getSelectedFriend() == nil)
                .padding()
                .background(Color(hex: "#10183C"))
            }
            .background(Color(hex: "#10183C"))
            .navigationTitle("Assign Story To")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        Analytics.shared.trackTap(
                            elementId: "assign_link_cancel",
                            screenName: "assign_link_to_friend"
                        )
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            friendsModel.fetchFriends {
                isLoadingFriends = false
            }
            
            Analytics.shared.trackScreen(
                name: "assign_link_to_friend",
                properties: [
                    "initial_mode": "friends_list"
                ]
            )
        }
    }
    
    // MARK: - Friends List View
    private var friendsListView: some View {
        VStack {
            if isLoadingFriends {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if friendsModel.friends.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("No Friends Yet")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Add friends or use username search")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(friendsModel.friends, id: \.id) { friend in
                            VStack(spacing: 0) {
                                SelectableFriendRowView(
                                    friend: friend,
                                    isSelected: selectedFriendId == friend.id
                                ) {
                                    selectedFriendId = friend.id
                                    searchedUser = nil // Clear username search selection
                                    
                                    Analytics.shared.trackTap(
                                        elementId: "friend_selected_from_list",
                                        screenName: "assign_link_to_friend",
                                        properties: [
                                            "friend_id": friend.id,
                                            "friend_name": friend.name
                                        ]
                                    )
                                }
                                
                                if friend.id != friendsModel.friends.last?.id {
                                    Divider()
                                        .background(Color.white.opacity(0.2))
                                }
                            }
                        }
                    }
                    .background(Color(hex: "#1A2245"))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
            }
        }
        .background(Color(hex: "#10183C"))
    }
    
    // MARK: - Username Search View
    private var usernameSearchView: some View {
        VStack(spacing: 20) {
            HStack(alignment: .center, spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.leading, 15)
                    
                    TextField("Enter Username", text: $usernameInput)
                        .padding(.vertical)
                        .padding(.leading, 5)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .accentColor(.white)
                }
                .frame(height: 70) // Same fixed height
                .background(
                    Color(hex: "#3B4374")
                        .clipShape(
                            RoundedCorner(
                                radius: 10,
                                corners: [.topLeft, .bottomLeft]
                            )
                        )
                )
                
                Button(action: searchForUsername) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .frame(width: 60, height: 70)
                        .foregroundColor(.white)
                        .background(
                            Color(hex: usernameInput.isEmpty ? "#323862" : "#4169E1")
                                .clipShape(
                                    RoundedCorner(
                                        radius: 10,
                                        corners: [.topRight, .bottomRight]
                                    )
                                )
                        )
                }
            }
            .padding(.horizontal)
            
            // Error Message
            if let error = searchError {
                Text(error)
                    .foregroundColor(Color(hex: "#FF0000"))
                    .font(.system(size: 16, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .padding(.bottom, 30)
                    .padding(.top, 10)
                    .padding(.horizontal)
            }
            
            // Search Result
            if let user = searchedUser {
                VStack(spacing: 0) {
                    SelectableFriendRowView(
                        friend: user,
                        isSelected: true
                    ) {
                        // Already selected, do nothing
                    }
                }
                .background(Color(hex: "#1A2245"))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .background(Color(hex: "#10183C"))
    }
    
    // MARK: - Helper Functions
    private func getSelectedFriend() -> AppUser? {
        if selectionMode == .friendsList {
            return friendsModel.friends.first(where: { $0.id == selectedFriendId })
        } else {
            return searchedUser
        }
    }
    
    private func searchForUsername() {
        let cleanedUsername = usernameInput.lowercased().trimmingCharacters(in: .whitespaces)
        guard !cleanedUsername.isEmpty else { return }
        
        isSearchingUsername = true
        searchError = nil
        searchedUser = nil
        selectedFriendId = nil
        
        let db = Firestore.firestore()
        
        db.collection("users")
            .whereField("username", isEqualTo: cleanedUsername)
            .getDocuments { [self] snapshot, error in
                DispatchQueue.main.async {
                    isSearchingUsername = false
                    
                    if let error = error {
                        searchError = "Search failed: \(error.localizedDescription)"
                        
                        Analytics.shared.trackError(
                            message: "Username search failed",
                            properties: [
                                "username": cleanedUsername,
                                "error": error.localizedDescription
                            ]
                        )
                        return
                    }
                    
                    guard let document = snapshot?.documents.first else {
                        searchError = "User '\(cleanedUsername)' not found"
                        
                        Analytics.shared.track(
                            event: "username_search_no_results",
                            properties: [
                                AnalyticsProperty.screenName: "assign_link_to_friend",
                                "username": cleanedUsername
                            ]
                        )
                        return
                    }
                    
                    let userId = document.documentID
                    
                    // Check if trying to assign to self
                    if userId == Auth.auth().currentUser?.uid {
                        searchError = "Cannot assign link to yourself"
                        
                        Analytics.shared.track(
                            event: "username_search_attempted_self_assign",
                            properties: [
                                AnalyticsProperty.screenName: "assign_link_to_friend"
                            ]
                        )
                        return
                    }
                    
                    let data = document.data()
                    let name = data["name"] as? String ?? "Unknown"
                    let profileImageUrl = data["profilePictureUrl"] as? String
                    
                    searchedUser = AppUser(id: userId, name: name, profileImageUrl: profileImageUrl)
                    searchError = nil
                    
                    Analytics.shared.track(
                        event: "username_search_success",
                        properties: [
                            AnalyticsProperty.screenName: "assign_link_to_friend",
                            "username": cleanedUsername,
                            "found_user_id": userId
                        ]
                    )
                }
            }
    }
}

// MARK: - Selectable Friend Row View
struct SelectableFriendRowView: View {
    let friend: AppUser
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                HStack(spacing: 20) {
                    ProfilePictureView(url: friend.profileImageUrl, size: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(friend.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, 30)
                
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Color(hex: "#4169E1") : .white)
                    .padding(.trailing, 30)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(isSelected ? Color(hex: "#4169E1").opacity(0.2) : Color.clear)
        }
    }
}
