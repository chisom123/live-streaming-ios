import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import PostHog

struct MyCompsView: View {
    @StateObject private var viewModel = CompetitionsModel()
    @State private var selectedCompetition: Competition?
    @State private var isLoading = true
    @State private var navigateToSettings = false
    
    var body: some View {
        VStack {
            // Top Bar with Title
            HStack {
                Button(action: {
                    viewModel.cleanupListeners()
                    navigateToSettings = true
                }) {
                    Image("settings")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.white) // or any color you want
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                }
                
                Spacer()
                
                Text("Competitions")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(.white) // Set the text color as needed

                Spacer() // Pushes the remaining content to the trailing edge
                
                Button(action: {
                    viewModel.cleanupListeners()
                    createNewCompetition()
                }) {
                    Image(systemName: "plus.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(Color.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)

            Spacer()
            
            if isLoading {
                ProgressView()
                    .tint(.white)
                Spacer()
            } else if viewModel.competitions.isEmpty {
                EmptyCompsView(
                    newCompAction: {
                        viewModel.cleanupListeners()
                        createNewCompetition()
                    }
                )
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.competitions, id: \.id) { competition in
                            VStack(spacing: 0) { // Added spacing: 0 here to control internal spacing
                                HStack {
                                    Text(competition.description)
                                        .font(.system(size: 16, weight: .bold))
                                        .lineLimit(2)
                                        .lineSpacing(9)
                                        .foregroundColor(.white)
                                        .truncationMode(.tail)
                                        .padding(.leading, 30)
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 8) {
                                        Text("\(competition.entriesNotVotedCount)")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(Color(hex: "#FFF"))
                                        
                                        Image(systemName: "photo.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 18, height: 18)
                                            .foregroundColor(Color(hex: "#FFF"))
                                    }
                                    .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                                    .background(Color(hex: "#3B4374"))
                                    .cornerRadius(200)
                                    .padding(.trailing, 30)
                                }
                                .padding(.vertical, 25)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.cleanupListeners()
                                    self.selectedCompetition = competition
                                }
                                
                                if competition.id != viewModel.competitions.last?.id {
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
        .navigationBarHidden(true)
        .background(Color(hex: "#10183C"))
        .fullScreenCover(item: $selectedCompetition) { comp in
            CompDetails(competition: comp)
        }
        .fullScreenCover(isPresented: $navigateToSettings) {
            SettingsView()
        }
        .onAppear {
            fetchData()
        }
        .onDisappear {
            viewModel.cleanupListeners()
        }
    }
    
    private func fetchData() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        viewModel.setupCompetitionListeners(userId: userId) {
            self.isLoading = false
        }
    }
    
    private func createNewCompetition() {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("Error: User not logged in")
            return
        }
        
        let db = Firestore.firestore()
        
        // First fetch the user's username
        db.collection("users").document(userID).getDocument { (document, error) in
            if let error = error {
                print("Error fetching username: \(error.localizedDescription)")
                // Fallback to creating competition with default name
                self.createCompetitionWithName("Unnamed Competition")
                return
            }
            
            guard let document = document, document.exists,
                  let username = document.data()?["username"] as? String else {
                // Fallback to creating competition with default name if username not found
                self.createCompetitionWithName("Unnamed Competition")
                return
            }
            
            // Create competition with username
            let competitionName = "\(username)'s competition"
            self.createCompetitionWithName(competitionName)
        }
    }

    private func createCompetitionWithName(_ name: String) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        let batch = db.batch()
        
        let competitionRef = db.collection("competitions").document()
        let competitionId = competitionRef.documentID
        let timestamp = Timestamp()
        
        let competitionData: [String: Any] = [
            "id": competitionId,
            "description": name,
            "timestamp": timestamp
        ]
        
        batch.setData(competitionData, forDocument: competitionRef)
        
        // Set user as member
        let memberRef = competitionRef.collection("members").document(userID)
        batch.setData(["userId": userID], forDocument: memberRef)
        
        // Add to user's groupMemberships
        let groupMembershipRef = db.collection("groupMemberships").document(userID)
                                  .collection("competitions").document(competitionRef.documentID)
        batch.setData(["competitionId": competitionRef.documentID], forDocument: groupMembershipRef)
        
        batch.commit { err in
            if let err = err {
                print("Failed to create competition: \(err.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    self.selectedCompetition = Competition( // Changed to use existing selectedCompetition
                        id: competitionRef.documentID,
                        description: name,
                        date: timestamp.dateValue()
                    )
                }
                
                PostHogSDK.shared.capture("New Competition", properties: [
                    "competition_id": competitionId
                ])
            }
        }
    }
}

struct EmptyCompsView: View {
    var newCompAction: () -> Void
    
    var body: some View {
        VStack {
            Text("No Competitions Yet")
                .font(.system(size: 21, weight: .bold, design: .default))
                .foregroundColor(.white) // Changed to white for better contrast
                .padding(.top, 20)
                .padding(.bottom, 25)
            
            Button(action: newCompAction) {
                Text("New Competition")
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .padding(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                    .background(Color(hex: "#FF4081")) // Vibrant magenta from our earlier color palette
                    .foregroundColor(.white)
                    .cornerRadius(200)
            }
            .padding(.bottom, 20)
            
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(hex: "#1A2245")) // Slightly lighter than background for contrast
        .cornerRadius(10) // Increased corner radius for a softer look
        .padding(.horizontal, 20)
    }
}
