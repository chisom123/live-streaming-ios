import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import NotificationBannerSwift

struct JoinSelectView: View {
    
    @State var selectedFriends: Set<String> = [] // Tracks selected friends
    @State var currentUserId: String = Auth.auth().currentUser?.uid ?? ""
    @State private var isPresentingCompDetails = false
    @State private var username: String = ""
    
    var competition: Competition // this holds the selected competition details
    
    @ObservedObject var viewModel: MyFriendsModel // Add this line
    @ObservedObject var viewModel2: AddFriendsModel

    func processUsername(_ username: String) -> String {
        return username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    isPresentingCompDetails = true
                }) {
                    Image("Close")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .padding(.leading, 20)
                        .padding(.top, 20)
                }
                
                Spacer()
            }
            
            VStack {
                
                Text("Add Friends to this Group")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.top, 40)
                    .padding(.bottom, 40)
                    .padding(.horizontal)
                
                
                
                // Radio buttons for selection
                HStack(alignment: .center, spacing: 10) {
                    TextField("Enter Friend's Username", text: $username)
                        .padding()
                        .background(Color(hex: "#F5F5F5"))
                        .foregroundColor(Color(hex: "#000"))
                        .cornerRadius(5)
                        .font(.system(size: 16, weight: .bold, design: .default))
                    
                    Button(action: {
                        let processedUsername = processUsername(username)
                        viewModel2.addFriend(byUsername: processedUsername) { (success, error) in
                            if success {
                                findAndAddFriendByUsername(processedUsername)
                            } else {
                                let banner = NotificationBanner(title: "Failed to Add Friend", style: .danger)
                                banner.show()
                            }
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold, design: .default))
                            .padding()
                            .background(Color(hex: "#1199FF"))
                            .foregroundColor(Color(hex: "#fff"))
                            .cornerRadius(5)
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
        .refreshable {
            viewModel.fetchFriends()
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
                    self.selectedFriends.insert(document.documentID) // Assuming documentID is the user ID
                    updateCompetitionAllowJoin()
                    isPresentingCompDetails = true
                }
            }
        }
    }
    
    func updateCompetitionAllowJoin() {
        let db = Firestore.firestore()
        let competitionID = competition.id
        let batch = db.batch() // Create a batch write object

        var completionCounter = 0 // Counter to track the completion of getDocument calls

        for userId in selectedFriends {
            let participantRef = db.collection("competitions")
                                    .document(competitionID)
                                    .collection("participants")
                                    .document(userId)

            // Perform a document check
            participantRef.getDocument { (document, error) in
                completionCounter += 1  // Increment the counter for each completion

                if let document = document, document.exists {
                    print("User already a participant")
                } else {
                    // Add a new participant
                    batch.setData([
                        "userId": userId,
                        "voted_entries": []
                    ], forDocument: participantRef)
                }

                // Commit the batch if all document checks are completed
                if completionCounter == selectedFriends.count {
                    batch.commit { err in
                        if let err = err {
                            print("Error writing batch: \(err)")
                        } else {
                            print("Batch write succeeded.")
                            DispatchQueue.main.async {
                                isPresentingCompDetails = true
                            }
                        }
                    }
                }
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
