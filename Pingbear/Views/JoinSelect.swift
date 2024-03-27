import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct JoinSelectView: View {
    
    @State var selection: String = "Everyone" // Used for radio buttons selection
    @State var selectedFriends: Set<String> = [] // Tracks selected friends
    @State var currentUserId: String = Auth.auth().currentUser?.uid ?? ""
    @State private var showingVoteSelectView = false
    
    var competition: Competition // this holds the selected competition details
    var fromLocationCheckView: Bool // Add this line
    
    @ObservedObject var viewModel: MyFriendsModel // Add this line

    var body: some View {
        VStack {
            Text("Who can join your group")
                .font(.system(size: 22, weight: .bold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(Color(hex: "#000"))
                .padding(.bottom, 20)
                .padding(.top, 20)
                .padding(.horizontal)

            // Radio buttons for selection
            HStack {
                RadioButtonField(id: "Everyone", label: "Everyone", isMarked: selection == "Everyone", callback: { selected in
                    self.selection = selected
                    self.selectedFriends.removeAll()
                })

                RadioButtonField(id: "Just me", label: "Just me", isMarked: selection == "Just me", callback: { selected in
                    self.selection = selected
                    self.selectedFriends.removeAll()
                })
            }.padding(.horizontal)

            // List of friends
            Text("Friends")
                .font(.headline)
                .padding(.top, 20)

            ScrollView {
                VStack(spacing: 25) {
                    ForEach(viewModel.friends, id: \.id) { friend in // Use the real friends data
                        SelectableFriendView(friend: friend.name, isSelected: self.selectedFriends.contains(friend.id)) { // Change from 'friend' to 'friend.id' if necessary
                            if self.selectedFriends.contains(friend.id) {
                                self.selectedFriends.remove(friend.id)
                            } else {
                                self.selectedFriends.insert(friend.id)
                            }
                            // Clear the radio button selection when a custom friend list is made
                            self.selection = ""  // Or "Custom" if you want to use a specific state
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            Button("Confirm Selection") {
                updateCompetitionAllowJoin()  // Call this when the confirm button is pressed
                showingVoteSelectView = true 
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(Color.white)
            .cornerRadius(8)
        }
        .refreshable {
            viewModel.fetchFriends()
        }
        .onAppear {
            viewModel.fetchFriends() // Fetch friends when the view appears
        }
        .fullScreenCover(isPresented: $showingVoteSelectView) {
            VoteSelectView(competition: competition, fromLocationCheckView: true, viewModel: MyFriendsModel())
        }
    }
    
    func updateCompetitionAllowJoin() {
        let db = Firestore.firestore()
        let competitionID = competition.id // Ensure you have the competition ID

        let allowJoinIds: [String]
        if selection == "Everyone" {
            allowJoinIds = ["Everyone"]
        } else if selection == "Just me" {
            // Set to current user's ID, ensure this is correct for your app's user identification logic
            allowJoinIds = [currentUserId]
        } else {
            var allSelectedFriends = selectedFriends
            allSelectedFriends.insert(currentUserId)  // Add the current user's ID
            allowJoinIds = Array(allSelectedFriends)
        }

        db.collection("competitions").document(competitionID).updateData([
            "allow_join": allowJoinIds
        ]) { err in
            if let err = err {
                print("Error updating document: \(err)")
            } else {
                print("Document successfully updated")
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
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
            .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
            .cornerRadius(10)
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
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: self.isMarked ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(self.isMarked ? .blue : .gray)
                Text(self.label)
                    .foregroundColor(Color.purple)
            }
            .padding(15)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
