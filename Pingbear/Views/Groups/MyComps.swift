import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import PostHog

struct MyCompsView: View {
    @StateObject private var viewModel = CompetitionsModel()
    @State private var selectedCompetition: Competition?
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            // Top Bar with Title
            HStack {
                Text("Home")
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .foregroundColor(.black) // Set the text color as needed
                    .padding(.horizontal, 20)

                Spacer() // Pushes the remaining content to the trailing edge
                
                Button(action: {
                    viewModel.cleanupListeners()
                    createNewCompetition()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40) // Adjust the size as needed
                        .foregroundColor(Color(hex: "#1199FF")) // Your desired color
                        .background(Color.white)
                        .clipShape(Circle())
                }
                .padding(.trailing, 20)
            }
            .padding(.vertical, 15)

            Spacer()
            
            if isLoading {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    VStack(spacing: 20) {
                        ForEach(viewModel.competitions, id: \.id) { competition in
                            HStack {
                                Text(competition.description)
                                    .font(.system(size: 16, weight: .bold))
                                    .lineLimit(2)
                                    .lineSpacing(9)
                                    .foregroundColor(.black)
                                    .truncationMode(.tail)
                                    .padding(.leading, 10)
                                
                                Spacer()
                                
                                HStack(spacing: 8) {
                                    Text("\(competition.entriesNotVotedCount)")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(Color(hex: "#fff"))
                                    
                                    Image(systemName: "photo.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 18, height: 18)
                                        .foregroundColor(Color(hex: "#fff"))
                                }
                                .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                                .background(Color(hex: "#7B68EE"))
                                .cornerRadius(200)
                                .padding(.trailing, 10)
                            }
                            .padding(20)
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                            .padding(.horizontal, 20)
                            .onTapGesture {
                                viewModel.cleanupListeners()
                                self.selectedCompetition = competition
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(item: $selectedCompetition) { comp in
            CompDetails(competition: comp)
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
        let batch = db.batch()
        
        let competitionRef = db.collection("competitions").document()
        let timestamp = Timestamp()
        let defaultName = "Unnamed Competition"
        
        let competitionData: [String: Any] = [
            "description": defaultName,
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
                        description: defaultName,
                        date: timestamp.dateValue()
                    )
                }
                PostHogSDK.shared.capture("New Competition", properties: ["name": defaultName])
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
                .foregroundColor(.black) // Set the text color as needed
                .padding(.bottom, 20)
            
            Text("Start a competition or wait to be added")
                .font(.system(size: 17, weight: .bold, design: .default))
                .foregroundColor(.gray) // Set the text color as needed
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .padding(.bottom, 25)
            
            Button(action: newCompAction) {  // This button now uses the passed function
                Text("New Competition")
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .padding(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                    .background(Color(hex: "#1199FF"))
                    .foregroundColor(Color(hex: "#fff"))
                    .cornerRadius(200)
            }
        }
        .padding(.horizontal, 20)
    }
}
