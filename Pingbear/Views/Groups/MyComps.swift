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
    @State private var showCreateCompetition = false
    @State private var isCreatingCompetition = false // New state for creation loading
    
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
                        .foregroundColor(.white)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                }
                
                Spacer()
                
                Text("Competitions")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(.white)

                Spacer()
                
                Button(action: {
                    if !isCreatingCompetition {
                        createNewCompetition()
                    }
                }) {
                    Image(systemName: "plus.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(isCreatingCompetition ? Color.white.opacity(0.5) : Color.white)
                }
                .disabled(isCreatingCompetition)
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
                        if !isCreatingCompetition {
                            createNewCompetition()
                        }
                    },
                    isCreating: isCreatingCompetition
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
        .fullScreenCover(isPresented: $navigateToSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showCreateCompetition) {
            CreateCompetitionNameView()
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
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        isCreatingCompetition = true
        
        let db = Firestore.firestore()
        
        // First fetch the user's username
        db.collection("users").document(userID).getDocument { (document, error) in
            if let error = error {
                print("Failed to fetch user data: \(error.localizedDescription)")
                self.isCreatingCompetition = false
                return
            }
            
            let competitionName = "Competition"
            
            // Now create the competition
            let competitionRef = db.collection("competitions").document()
            let newCompetitionId = competitionRef.documentID
            let timestamp = Timestamp()
            let creationDate = timestamp.dateValue()
            
            // First establish membership
            let creatorMemberRef = competitionRef.collection("members").document(userID)
            
            creatorMemberRef.setData(["userId": userID]) { error in
                if let error = error {
                    print("Failed to add creator as member: \(error.localizedDescription)")
                    self.isCreatingCompetition = false
                    return
                }
                
                // Create the competition
                let competitionData: [String: Any] = [
                    "id": newCompetitionId,
                    "description": competitionName,
                    "timestamp": timestamp,
                    "hostId": userID
                ]
                
                competitionRef.setData(competitionData) { error in
                    if let error = error {
                        print("Failed to create competition: \(error.localizedDescription)")
                        self.isCreatingCompetition = false
                        return
                    }
                    
                    // Add to creator's groupMemberships
                    let creatorGroupMembershipRef = db.collection("groupMemberships").document(userID)
                                                     .collection("competitions").document(newCompetitionId)
                    creatorGroupMembershipRef.setData(["competitionId": newCompetitionId]) { error in
                        if let error = error {
                            print("Failed to add group membership: \(error.localizedDescription)")
                        }
                        
                        self.isCreatingCompetition = false
                        
                        // Create Competition object and navigate to it
                        let newCompetition = Competition(
                            id: newCompetitionId,
                            description: competitionName,
                            date: creationDate
                        )
                        
                        // Navigate to the newly created competition
                        DispatchQueue.main.async {
                            self.selectedCompetition = newCompetition
                        }
                        
                        Analytics.shared.trackCompetition(
                            action: "create",
                            competitionId: newCompetitionId
                        )
                        
                        // Provide haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                }
            }
        }
    }
}

// Updated EmptyCompsView to handle loading state
struct EmptyCompsView: View {
    var newCompAction: () -> Void
    let isCreating: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("No Competitions Yet")
                .font(.system(size: 21, weight: .bold, design: .default))
                .foregroundColor(.white)
                .padding(.top, 30)
                .padding(.bottom, 30)
            
            // Button container - fixed width for consistency
            VStack() {
                Button(action: newCompAction) {
                    HStack {
                        Text("New Competition")
                            .font(.system(size: 17, weight: .bold, design: .default))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isCreating ? Color(hex: "#FF4081").opacity(0.5) : Color(hex: "#FF4081"))
                    .foregroundColor(isCreating ? .white.opacity(0.6) : .white)
                    .cornerRadius(25)
                }
                .disabled(isCreating)
            }
            .frame(width: 280)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .background(Color(hex: "#1A2245"))
        .cornerRadius(14)
        .padding(.horizontal, 20)
    }
}

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
