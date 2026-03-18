import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MyCompsView: View {
    @StateObject private var viewModel = CompetitionsModel()
    @State private var isLoading = true
    @State private var competitionToLeave: Competition?
    @State private var showLeaveConfirmation = false
    @State private var isCreatingCompetition = false
    @State private var navigateToNewCompetition: Competition?

    var body: some View {
        VStack {
            // Clean Top Bar with just Logo and Plus
            HStack {
                Color.clear
                    .frame(width: 30, height: 30)

                Spacer()

                Image("Logo-T")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .offset(y: -1.5)

                Spacer()

                // Plus button – directly creates a new competition
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
            .padding(.vertical, 10)

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
                            NavigationLink(destination: CompDetails(competition: competition)) {
                                CompetitionCellContent(
                                    competition: competition,
                                    isLast: competition.id == viewModel.competitions.last?.id,
                                    onLeave: {
                                        competitionToLeave = competition
                                        showLeaveConfirmation = true
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .simultaneousGesture(TapGesture().onEnded {
                                viewModel.cleanupListeners()
                                Analytics.shared.trackTap(
                                    elementId: "competition_cell",
                                    screenName: "competitions_list"
                                )
                            })
                        }
                    }
                    .background(Color(hex: "#1A2245"))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .background(Color(hex: "#10183C"))
        .background(
            EmptyView()
                .navigationDestination(
                    isPresented: Binding(
                        get: { navigateToNewCompetition != nil },
                        set: { if !$0 { navigateToNewCompetition = nil } }
                    ),
                    destination: {
                        if let competition = navigateToNewCompetition {
                            CompDetails(competition: competition)
                        }
                    }
                )
        )
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshCompetitions"))) { _ in
            viewModel.refreshCompetitions()
        }
    }

    // MARK: - Private helpers

    private func fetchData() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        viewModel.setupCompetitionListeners(userId: userId) {
            self.isLoading = false
        }
    }

    private func leaveCompetition(competitionId: String, userId: String) {
        viewModel.competitions.removeAll { $0.id == competitionId }

        let membersViewModel = MembersViewModel()
        membersViewModel.leaveCompetition(competitionId: competitionId, userId: userId)

        Analytics.shared.trackCompetition(
            action: "leave",
            competitionId: competitionId
        )

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func createNewCompetition() {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        isCreatingCompetition = true

        let db = Firestore.firestore()

        // Fetch the user's document (username, etc.)
        db.collection("users").document(userID).getDocument { (document, error) in
            if let error = error {
                print("Failed to fetch user data: \(error.localizedDescription)")
                self.isCreatingCompetition = false
                return
            }

            let competitionName = "Competition"

            let competitionRef = db.collection("competitions").document()
            let newCompetitionId = competitionRef.documentID
            let timestamp = Timestamp()
            let creationDate = timestamp.dateValue()

            // Establish membership first
            let creatorMemberRef = competitionRef.collection("members").document(userID)

            creatorMemberRef.setData([
                "userId": userID,
                "coins": 1000
            ]) { error in
                if let error = error {
                    print("Failed to add creator as member: \(error.localizedDescription)")
                    self.isCreatingCompetition = false
                    return
                }

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

                    let creatorGroupMembershipRef = db.collection("groupMemberships").document(userID)
                        .collection("competitions").document(newCompetitionId)

                    creatorGroupMembershipRef.setData(["competitionId": newCompetitionId]) { error in
                        if let error = error {
                            print("Failed to add group membership: \(error.localizedDescription)")
                        }

                        self.isCreatingCompetition = false

                        let newCompetition = Competition(
                            id: newCompetitionId,
                            description: competitionName,
                            date: creationDate
                        )

                        DispatchQueue.main.async {
                            self.navigateToNewCompetition = newCompetition
                        }

                        Analytics.shared.trackCompetition(
                            action: "create",
                            competitionId: newCompetitionId
                        )

                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                }
            }
        }
    }
}

// MARK: - EmptyCompsView

struct EmptyCompsView: View {
    var newCompAction: () -> Void
    let isCreating: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Purple header banner
            HStack(spacing: 8) {
                Text("Win 1,000+")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Image("gem")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.white)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color(hex: "#6A5ACD"))

            // Body
            Text("No Competitions Yet")
                .font(.system(size: 21, weight: .bold, design: .default))
                .foregroundColor(.white)
                .padding(.top, 30)
                .padding(.bottom, 30)

            VStack {
                Button(action: newCompAction) {
                    HStack {
                        Text("New Competition")
                            .font(.system(size: 17, weight: .bold, design: .default))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isCreating ? Color(hex: "#4169E1").opacity(0.5) : Color(hex: "#4169E1"))
                    .foregroundColor(isCreating ? .white.opacity(0.6) : .white)
                    .cornerRadius(25)
                }
                .disabled(isCreating)
            }
            .frame(width: 280)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#1A2245"))
        .cornerRadius(14)
        .padding(.horizontal, 20)
    }
}

// MARK: - CompetitionCellContent

struct CompetitionCellContent: View {
    let competition: Competition
    let isLast: Bool
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

                Image(systemName: "chevron.right")
                    .foregroundColor(Color(hex: "#D3D3D3"))
                    .font(.system(size: 15, weight: .bold))
                    .padding(.trailing, 30)
            }
            .padding(.vertical, 30)
            .contentShape(Rectangle())
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
