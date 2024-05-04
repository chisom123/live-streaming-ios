import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import PostHog

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct UsernameShieldView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var addFriendModel: AddFriendsModel
    @State private var username: String = ""
    @State private var currentUserUsername: String = ""  // Default text while username is loading
    @State private var messageStatus: MessageStatus? = nil
    @State private var navigateToHome = false
    @State private var showingShareSheet = false // Step 1: State variable for showing the share sheet

    enum MessageStatus {
        case error, success, none
    }

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image("Close")
                        .resizable()
                        .frame(width: 40, height: 40)
                }
                
                Spacer()
                
                Button(action: {
                    self.showingShareSheet = true
                    PostHogSDK.shared.capture("Invite friend button pressed")
                }) {
                    Text("Invite Friends")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#FF4500"))
                        .foregroundColor(Color(hex: "#fff"))
                        .cornerRadius(200)
                }
            }
            .padding(.top)
            .padding(.horizontal, 5)
            
            Spacer()
            
            Text("Enter your friend's username")
                .font(.system(size: 18, weight: .bold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(.black)
                .padding(.bottom, 40)
                .padding(.horizontal)

            TextField("Enter username", text: $username)
                .padding()
                .background(Color(hex: "#F5F5F5"))
                .foregroundColor(Color(hex: "#000"))
                .cornerRadius(5)
                .font(.system(size: 16, weight: .bold, design: .default))

            if let status = messageStatus {
                switch status {
                case .error:
                    Text("Failed to add friend")
                        .foregroundColor(Color(hex: "#CC2255"))
                        .font(.system(size: 15, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .padding(.bottom, 10)
                        .padding(.top, 20)
                        .padding(.horizontal)
                case .success:
                    Text("Friend added successfully")
                        .foregroundColor(Color(hex: "#556B2F"))
                        .font(.system(size: 15, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .padding(.bottom, 10)
                        .padding(.top, 20)
                        .padding(.horizontal)
                case .none:
                    EmptyView()
                }
            }

            Button(action: {
                let processedUsername = processUsername(username)
                saveFriendAndCreateGroup(processedUsername)
            }) {
                Text("Continue")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .background(Color(hex: "#1199FF"))
                    .foregroundColor(Color(hex: "#fff"))
                    .cornerRadius(200)
            }
            .padding(.top, 20)
            
            Spacer()
            
            HStack {
                Text("\(currentUserUsername)")
            }
            .font(.system(size: 16, weight: .bold, design: .default))
            .foregroundColor(.black)
            .padding(.bottom, 35)
        }
        .onAppear {
            fetchCurrentUserUsername { username in
                if let username = username {
                    self.currentUserUsername = username
                } else {
                    self.currentUserUsername = ""
                }
            }
        }
        .fullScreenCover(isPresented: $navigateToHome) {
            ContentView()
        }
        .sheet(isPresented: $showingShareSheet) {
            // This closure needs to return a View.
            ShareSheet(items: ["Hey I just downloaded Pingbear. Add me! Username - \(currentUserUsername)", URL(string: "https://apps.apple.com/gb/app/pingbear-picture-rating-game/id6473705189")].compactMap { $0 })
        }
        .padding()
    }
    
    func processUsername(_ username: String) -> String {
        return username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func saveFriendAndCreateGroup(_ processedFriendUsername: String) {
        addFriendModel.addFriend(byUsername: processedFriendUsername) { success, error in
            if success {
                // Fetch the user ID of the newly added friend
                fetchFriendUserId(username: processedFriendUsername) { friendUserId in
                    guard let friendUserId = friendUserId else {
                        self.messageStatus = .error
                        return
                    }
                    
                    // Fetch current user's username and process it
                    fetchCurrentUserUsername { currentUserUsername in
                        guard let currentUserUsername = currentUserUsername else {
                            self.messageStatus = .error
                            return
                        }
                        
                        let processedCurrentUserUsername = processUsername(currentUserUsername)
                        
                        // Create a new competition
                        createCompetition(friendUserId: friendUserId, friendUsername: processedFriendUsername, currentUserUsername: processedCurrentUserUsername)
                    }
                }
            } else {
                messageStatus = .error
            }
        }
    }
    
    func fetchFriendUserId(username: String, completion: @escaping (String?) -> Void) {
        let db = Firestore.firestore()
        db.collection("users").whereField("username", isEqualTo: username).getDocuments { (snapshot, error) in
            if let error = error {
                print("Error getting documents: \(error)")
                completion(nil)
            } else {
                let userIds = snapshot?.documents.compactMap { $0.documentID }
                completion(userIds?.first)
            }
        }
    }

    func fetchCurrentUserUsername(completion: @escaping (String?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        let db = Firestore.firestore()
        db.collection("users").document(currentUserId).getDocument { (document, error) in
            if let document = document, document.exists, let username = document.data()?["username"] as? String {
                completion(username)
            } else {
                print("Document does not exist")
                completion(nil)
            }
        }
    }

    func createCompetition(friendUserId: String, friendUsername: String, currentUserUsername: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            self.messageStatus = .error
            return
        }

        let db = Firestore.firestore()
        let competitionRef = db.collection("competitions").document()
        let batch = db.batch()
        let currentParticipantRef = competitionRef.collection("participants").document(currentUserId)
        let friendParticipantRef = competitionRef.collection("participants").document(friendUserId)

        let competitionDescription = "\(currentUserUsername) and \(friendUsername) 😁"
        let competitionData: [String: Any] = [
            "description": competitionDescription,
            "timestamp": Timestamp()
        ]

        batch.setData(competitionData, forDocument: competitionRef)
        batch.setData(["userId": currentUserId, "voted_entries": []], forDocument: currentParticipantRef)
        batch.setData(["userId": friendUserId, "voted_entries": []], forDocument: friendParticipantRef)

        batch.commit { err in
            if let err = err {
                print("Error writing document: \(err)")
                self.messageStatus = .error
            } else {
                self.navigateToHome = true
                UserDefaults.standard.set(true, forKey: "isFriendActivated")
                UserDefaults.standard.synchronize()
                PostHogSDK.shared.capture("Entered Pingbear with new friend and group")
            }
        }
    }
}
