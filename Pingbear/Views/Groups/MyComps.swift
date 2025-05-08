import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MyCompsView: View {
    @StateObject private var viewModel = CompetitionsModel()
    @State private var selectedCompetition: Competition?
    @State private var isLoading = true
    @State private var navigateToSettings = false
    @State private var competitionToLeave: Competition?
    @State private var showLeaveConfirmation = false
    @State private var showDemoCompetition = false
    
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
                    },
                    demoCompAction: {
                        viewModel.cleanupListeners()
                        openDemoCompetition()
                    }
                )
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.competitions, id: \.id) { competition in
                            CompetitionCell(
                                competition: competition,
                                isLast: competition.id == viewModel.competitions.last?.id,
                                onTap: {
                                    viewModel.cleanupListeners()
                                    selectedCompetition = competition
                                },
                                onLeave: {
                                    competitionToLeave = competition
                                    showLeaveConfirmation = true
                                }
                            )
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
        .fullScreenCover(isPresented: $showDemoCompetition) {
            DemoCompDetailsView()
        }
        .fullScreenCover(isPresented: $navigateToSettings) {
            SettingsView()
        }
        .alert("Leave Competition", isPresented: $showLeaveConfirmation) {
            Button("Cancel", role: .cancel) {
                competitionToLeave = nil
            }
            Button("Leave", role: .destructive) {
                if let competition = competitionToLeave,
                   let userId = Auth.auth().currentUser?.uid {
                    leaveCompetition(competitionId: competition.id, userId: userId)
                }
                competitionToLeave = nil
            }
        } message: {
            Text("Are you sure you want to leave this competition?")
        }
        .onAppear {
            fetchData()
            Analytics.shared.trackScreen(name: "competitions_list")
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
    
    private func openDemoCompetition() {
        showDemoCompetition = true
    }
    
    private func leaveCompetition(competitionId: String, userId: String) {
        let membersViewModel = MembersViewModel()
        membersViewModel.leaveCompetition(competitionId: competitionId, userId: userId)
        
        // Track analytics event
        Analytics.shared.trackCompetition(
            action: "leave",
            competitionId: competitionId
        )
        
        // Optionally provide haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func createNewCompetition() {
         guard let userID = Auth.auth().currentUser?.uid else {
             print("Error: User not logged in")
             return
         }
         
         let db = Firestore.firestore()
         let batch = db.batch()
         
         let competitionRef = db.collection("competitions").document()
         let competitionId = competitionRef.documentID  // Get the ID early to use in the data
         let timestamp = Timestamp()
         let defaultName = "Unnamed Competition"
         
         let competitionData: [String: Any] = [
             "id": competitionId,  // Add the ID to the competition document
             "description": defaultName,
             "timestamp": timestamp,
             "hostId": userID
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
                 
                 Analytics.shared.trackCompetition(
                     action: "create",
                     competitionId: competitionId
                 )
             }
         }
     }
}

// New component for the competition cell with swipe and long press actions
struct CompetitionCell: View {
    let competition: Competition
    let isLast: Bool
    let onTap: () -> Void
    let onLeave: () -> Void
    
    @State private var isLongPressing = false
    
    var body: some View {
        VStack(spacing: 0) {
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
                onTap()
            }
            .contextMenu {
                Button() {
                    onLeave()
                } label: {
                    Label("Leave Competition", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                // Provide haptic feedback on long press
                let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
                impactGenerator.impactOccurred()
            }
            .scaleEffect(isLongPressing ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLongPressing)
            
            if !isLast {
                Divider()
                    .background(Color.white.opacity(0.2))
            }
        }
    }
}

struct EmptyCompsView: View {
    var newCompAction: () -> Void
    var demoCompAction: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("No Competitions Yet")
                .font(.system(size: 21, weight: .bold, design: .default))
                .foregroundColor(.white)
                .padding(.top, 30)
                .padding(.bottom, 30)
            
            // Button container - fixed width for consistency
            VStack(spacing: 16) {
                Button(action: demoCompAction) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                            .padding(.trailing, 4)
                        
                        Text("Try Demo Competition")
                            .font(.system(size: 16, weight: .semibold, design: .default))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: "#3B4374"))
                    .foregroundColor(.white)
                    .cornerRadius(25)
                }
                
                Button(action: newCompAction) {
                    HStack {
                        Text("New Competition")
                            .font(.system(size: 17, weight: .bold, design: .default))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: "#FF4081"))
                    .foregroundColor(.white)
                    .cornerRadius(25)
                }
            }
            .frame(width: 280)
            .padding(.bottom, 25)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .background(Color(hex: "#1A2245"))
        .cornerRadius(14)
        .padding(.horizontal, 20)
    }
}
