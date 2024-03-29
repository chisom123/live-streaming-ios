import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct JoinSelectView: View {
    
    @State var selection: String = "Everyone" // Used for radio buttons selection
    @State var selectedFriends: Set<String> = [] // Tracks selected friends
    @State var currentUserId: String = Auth.auth().currentUser?.uid ?? ""
    @State private var showingVoteSelectView = false
    @State private var showingAddFriendsView = false
    
    var competition: Competition // this holds the selected competition details
    var fromLocationCheckView: Bool // Add this line
    
    @ObservedObject var viewModel: MyFriendsModel // Add this line

    var body: some View {
        VStack {
            Text("Who is allowed to add images to this group?")
                .font(.system(size: 18, weight: .bold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(.black)
                .padding(.top, 40)
                .padding(.bottom, 40)
                .padding(.horizontal)
            
            // Radio buttons for selection
            HStack(alignment: .center, spacing: 20) {
                RadioButtonField(id: "Everyone", label: "Everyone", isMarked: selection == "Everyone", callback: { selected in
                    self.selection = selected
                    self.selectedFriends.removeAll()
                })

                RadioButtonField(id: "Just me", label: "Only Me", isMarked: selection == "Just me", callback: { selected in
                    self.selection = selected
                    self.selectedFriends.removeAll()
                })
            }
            
            // List of friends and Add Friends Button
            HStack {
                Text("My Friends")
                    .font(.system(size: 16, weight: .bold, design: .default))

                Spacer()
                
                Button(action: {
                    showingAddFriendsView = true
                }) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 22, weight: .bold)) // Adjust size and weight as needed
                        .foregroundColor(Color(hex: "#1199FF")) // Adjust color as needed
                        .padding(10) // Add padding to increase tap area
                }

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
                            // Clear the radio button selection when a custom friend list is made
                            self.selection = ""  // Or "Custom" if you want to use a specific state
                        }
                    }
                }
            }
            
            Button(action: {
                updateCompetitionAllowJoin()  // Call this when the confirm button is pressed
                showingVoteSelectView = true
            }) {
                Text("Continue")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .background(Color(hex: "#1199FF"))
                    .foregroundColor(Color(hex: "#fff"))
                    .cornerRadius(200)
            }
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
        .padding(.horizontal)
        .refreshable {
            viewModel.fetchFriends()
        }
        .onAppear {
            viewModel.fetchFriends() // Fetch friends when the view appears
            
            // Additional setup for pre-selecting options based on `competition.allow_join`
            if competition.allow_join.contains("Everyone") {
                self.selection = "Everyone"
            } else if competition.allow_join.contains(currentUserId) && competition.allow_join.count == 1 {
                self.selection = "Just me"
            } else {
                // For specific friends selection
                self.selection = ""
                // Assuming `viewModel.friends` are already fetched or will be fetched. Adjust as necessary for asynchronous loading.
                self.selectedFriends = Set(competition.allow_join.filter { $0 != currentUserId })
            }
        }
        .fullScreenCover(isPresented: $showingVoteSelectView) {
            VoteSelectView(competition: competition, fromLocationCheckView: true, viewModel: MyFriendsModel())
        }
        .fullScreenCover(isPresented: $showingAddFriendsView) {
            // Assuming AddFriendsView is properly set up to dismiss itself by setting presentationMode.wrappedValue.dismiss()
            AddFriendsView(viewModel: AddFriendsModel())
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
                    .font(.system(size: 16, weight: .semibold))
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
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .background(Color(hex: "#F5F5F5")) 
            .cornerRadius(20)
        }
    }
}
