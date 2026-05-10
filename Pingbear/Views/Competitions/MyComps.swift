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
    @State private var activeChallenge: UserChallenge? = nil

    var body: some View {
        VStack(spacing: 0) {
            // ── Top Bar ──────────────────────────────────────
            HStack {
                Color.clear.frame(width: 30, height: 30)
                Spacer()
                Text("Home")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
                    .onAppear { Analytics.shared.trackScreen(name: "mycomps_view") }
                Spacer()
                Button(action: {
                    if !isCreatingCompetition { createNewCompetition() }
                }) {
                    Image(systemName: "plus.circle")
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(isCreatingCompetition ? AppTheme.iconColor.opacity(0.3) : AppTheme.iconColor)
                }
                .disabled(isCreatingCompetition)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            // ── Challenge Banner (always visible at top) ─────
            challengeBanner

            // ── Content (changes based on state) ─────────────
            if isLoading {
                Spacer()
                ProgressView().tint(AppTheme.primaryText)
                Spacer()
            } else if viewModel.competitions.isEmpty {
                Spacer()
                EmptyCompsView(
                    newCompAction: {
                        if !isCreatingCompetition { createNewCompetition() }
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
                    .background(AppTheme.cardBackground)
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .background(AppTheme.pageBackground)
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
            Button("Cancel", role: .cancel) { competitionToLeave = nil }
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
            loadChallenge()
            Analytics.shared.trackScreen(name: "competitions_list")
        }
        .onDisappear {
            viewModel.cleanupListeners()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshCompetitions"))) { _ in
            viewModel.refreshCompetitions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenCompetition"))) { notification in
            if let competition = notification.object as? Competition {
                navigateToNewCompetition = competition
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RaceEnded"))) { _ in
            // Refresh challenge state when a race ends in case user won
            ChallengeManager.shared.refreshChallengeState()
            loadChallenge()
        }
    }

    // MARK: - Challenge Banner

    @ViewBuilder
    private var challengeBanner: some View {
        if let challenge = activeChallenge {
            HStack(spacing: 12) {
                Image("rocket")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(AppTheme.iconColor)
                    .frame(width: 25, height: 25)

                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                        .lineLimit(1)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 200)
                                .fill(AppTheme.divider)
                                .frame(height: 5)
                            RoundedRectangle(cornerRadius: 200)
                                .fill(AppTheme.accent)
                                .frame(
                                    width: max(0, geo.size.width * CGFloat(challenge.progress)),
                                    height: 5
                                )
                        }
                    }
                    .frame(height: 5)

                    // Dollar progress text
                    Text(challenge.progressText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.secondaryText)
                }

                Spacer()
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .cornerRadius(10)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
    }

    // MARK: - Private Helpers

    private func loadChallenge() {
        ChallengeManager.shared.loadActiveChallenge { challenge in
            DispatchQueue.main.async {
                self.activeChallenge = challenge
            }
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
        viewModel.competitions.removeAll { $0.id == competitionId }
        let membersViewModel = MembersViewModel()
        membersViewModel.leaveCompetition(competitionId: competitionId, userId: userId)
        Analytics.shared.trackCompetition(action: "leave", competitionId: competitionId)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func createNewCompetition() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        isCreatingCompetition = true
        let db = Firestore.firestore()

        db.collection("users").document(userID).getDocument { (document, error) in
            if let error = error {
                print("Failed to fetch user data: \(error.localizedDescription)")
                self.isCreatingCompetition = false
                return
            }

            let competitionRef = db.collection("competitions").document()
            let newCompetitionId = competitionRef.documentID
            let timestamp = Timestamp()
            let creationDate = timestamp.dateValue()
            let creatorMemberRef = competitionRef.collection("members").document(userID)

            creatorMemberRef.setData(["userId": userID, "coins": 1000]) { error in
                if let error = error {
                    print("Failed to add creator as member: \(error.localizedDescription)")
                    self.isCreatingCompetition = false
                    return
                }

                competitionRef.setData([
                    "id": newCompetitionId,
                    "description": "Competition",
                    "timestamp": timestamp,
                    "hostId": userID
                ]) { error in
                    if let error = error {
                        print("Failed to create competition: \(error.localizedDescription)")
                        self.isCreatingCompetition = false
                        return
                    }

                    db.collection("groupMemberships").document(userID)
                        .collection("competitions").document(newCompetitionId)
                        .setData(["competitionId": newCompetitionId]) { error in
                            if let error = error {
                                print("Failed to add group membership: \(error.localizedDescription)")
                            }
                            self.isCreatingCompetition = false
                            let newCompetition = Competition(
                                id: newCompetitionId,
                                description: "Competition",
                                date: creationDate
                            )
                            DispatchQueue.main.async {
                                self.navigateToNewCompetition = newCompetition
                            }
                            Analytics.shared.trackCompetition(action: "create", competitionId: newCompetitionId)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
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
            Text("No Competitions Yet")
                .font(.system(size: 21, weight: .bold))
                .foregroundColor(AppTheme.primaryText)
                .padding(.top, 30).padding(.bottom, 30)

            VStack {
                Button(action: newCompAction) {
                    HStack {
                        Text("New Competition")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(isCreating ? AppTheme.accent.opacity(0.5) : AppTheme.accent)
                    .foregroundColor(isCreating ? .white.opacity(0.6) : .white)
                    .cornerRadius(25)
                }
                .disabled(isCreating)
            }
            .frame(width: 280).padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity).padding(.horizontal, 20)
        .background(AppTheme.cardBackground).cornerRadius(14).padding(.horizontal, 20)
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
                    .lineLimit(2).lineSpacing(9)
                    .foregroundColor(AppTheme.primaryText)
                    .truncationMode(.tail).padding(.leading, 30)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(AppTheme.secondaryText)
                    .font(.system(size: 15, weight: .bold))
                    .padding(.trailing, 30)
            }
            .padding(.vertical, 30)
            .contentShape(Rectangle())
            .contextMenu {
                Button { onLeave() } label: {
                    Label("Leave Competition", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            .scaleEffect(isLongPressing ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLongPressing)

            if !isLast {
                Divider().background(AppTheme.divider)
            }
        }
    }
}
