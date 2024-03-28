import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct VoteSelectView: View {
    
    @State var selection: String = "Everyone" // Used for radio buttons selection
    @State var selectedFriends: Set<String> = [] // Tracks selected friends
    @State var currentUserId: String = Auth.auth().currentUser?.uid ?? ""
    @State private var isPresentingCompDetails = false
    
    var competition: Competition // this holds the selected competition details
    var fromLocationCheckView: Bool // Add this line
    
    @ObservedObject var viewModel: MyFriendsModel // Add this line

    var body: some View {
        VStack {
            Text("Who is allowed to rate images in this group?")
                .font(.system(size: 18, weight: .bold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(.black)
                .padding(.top, 40)
                .padding(.bottom, 30)
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
            
            // List of friends
            Text("My Friends")
                .font(.system(size: 16, weight: .bold, design: .default))
                .frame(maxWidth: .infinity, alignment: .leading) // Align text to the left
                .padding(.top, 20)
                .padding(.bottom, 20)

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
                isPresentingCompDetails = true
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
        }
        .fullScreenCover(isPresented: $isPresentingCompDetails) {
            // Pass the competition object to CompDetails
            CompDetails(competition: competition, fromLocationCheckView: true)
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
            "allow_vote": allowJoinIds
        ]) { err in
            if let err = err {
                print("Error updating document: \(err)")
            } else {
                print("Document successfully updated")
            }
        }
    }


}
