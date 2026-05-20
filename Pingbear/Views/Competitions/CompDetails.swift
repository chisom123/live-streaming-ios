import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import AVFoundation

// ─────────────────────────────────────────────────────────────
// MARK: - Member Entry
// ─────────────────────────────────────────────────────────────

struct MemberEntry: Identifiable {
    let id: String
    let userName: String
    let profilePictureUrl: String?
    let roundsWon: Int
    let totalRoundWinnings: Double
}

struct CompDetails: View {

    enum AlertType: Identifiable {
        case notification
        var id: Int { 0 }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var isEditingCompetition = false
    @State private var currentUserId: String = Auth.auth().currentUser?.uid ?? ""
    @State private var isLoading = true
    @StateObject private var notificationManager = PushNotificationManager.shared
    @State private var activeAlert: AlertType?
    @StateObject private var chatIndicator: ChatIndicatorViewModel
    @State private var showingJoinSelectView = false
    @StateObject private var myFriendsModel = MyFriendsModel()
    @State private var showingThemePicker = false
    @State private var members: [MemberEntry] = []

    @StateObject private var roundViewModel = RoundViewModel()
    @ObservedObject private var callManager: VoiceCallManager = VoiceCallManager.shared
    @ObservedObject var competition: Competition

    private let db = Firestore.firestore()

    init(competition: Competition) {
        self.competition = competition
        self._chatIndicator = StateObject(wrappedValue: ChatIndicatorViewModel(competitionId: competition.id))
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading) {

                // ── Header ────────────────────────────────────────
                HStack {
                    Button(action: {
                        roundViewModel.stopListening()
                        dismiss()
                        Analytics.shared.trackTap(
                            elementId: "back_button",
                            screenName: "competition_details"
                        )
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(AppTheme.iconColor)
                    }

                    Spacer()

                    Button(action: {
                        isEditingCompetition = true
                        Analytics.shared.trackTap(
                            elementId: "edit_competition_name",
                            screenName: "competition_details"
                        )
                    }) {
                        Text(competition.description == "Competition"
                             ? "Add Competition Name"
                             : competition.description)
                            .font(.system(size: 18, weight: .bold))
                            .lineLimit(1)
                            .foregroundColor(AppTheme.primaryText)
                            .padding(.horizontal)
                    }

                    Spacer()

                    NavigationLink(destination: MembersView(competition: competition)) {
                        Image(systemName: "ellipsis")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .foregroundColor(AppTheme.iconColor)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        Analytics.shared.trackTap(
                            elementId: "open_members",
                            screenName: "competition_details"
                        )
                    })
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // ── Action buttons ────────────────────────────────
                HStack(spacing: 10) {

                    VoiceCallButton {
                        Analytics.shared.trackTap(
                            elementId: "join_voice_call",
                            screenName: "competition_details"
                        )
                        joinCall()
                    }

                    Button(action: {
                        if roundViewModel.hasActiveRound {
                            let elementId = roundViewModel.justCompletedRound ? "play_again" : "open_round"
                            Analytics.shared.trackTap(
                                elementId: elementId,
                                screenName: "competition_details"
                            )
                            roundViewModel.reenterRound()
                        } else {
                            Analytics.shared.trackTap(
                                elementId: "start_round",
                                screenName: "competition_details"
                            )
                            startNewRound()
                        }
                    }) {
                        Text(roundViewModel.roundInfo?.status == .judging
                             ? "Judging..."
                             : roundViewModel.hasActiveRound
                                 ? "Open Round"
                                 : roundViewModel.justCompletedRound
                                     ? "Play Again"
                                     : "Start Round")
                            .frame(maxWidth: .infinity, minHeight: 45)
                            .font(.system(size: 20, weight: .bold))
                            .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .background(members.count <= 1 && !roundViewModel.hasActiveRound
                                        ? AppTheme.disabledBackground
                                        : AppTheme.accent)
                            .foregroundColor(members.count <= 1 && !roundViewModel.hasActiveRound
                                        ? AppTheme.disabledText
                                        : .white)
                            .cornerRadius(200)
                    }
                    .disabled(members.count <= 1 && !roundViewModel.hasActiveRound)

                    NavigationLink(destination: ChatView(competition: competition)) {
                        ZStack {
                            Image("message-circle")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(AppTheme.iconColor)
                                .frame(width: 27, height: 27)
                                .frame(width: 45, height: 45)
                                .padding(6)

                            if chatIndicator.hasUnreadMessages {
                                Text(chatIndicator.displayCount)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 20, minHeight: 20)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 11, y: -11)
                            }
                        }
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        chatIndicator.markAsRead()
                        Analytics.shared.trackTap(
                            elementId: "open_chat",
                            screenName: "competition_details"
                        )
                    })
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 10)
                .background(AppTheme.cardBackground)
                .cornerRadius(10)
                .padding(.vertical, 20)
                .padding(.horizontal, 20)

                // ── Leaderboard ───────────────────────────────────
                if isLoading {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if members.count <= 1 {
                    NoPlayersView(action_player: addPlayer)
                    Spacer()
                } else {
                    leaderboardSection
                }
            }
        }
        .background(AppTheme.pageBackground)
        .navigationBarHidden(true)
        .onAppear {
            Analytics.shared.trackScreen(name: "competition_details")
            Analytics.shared.trackCompetition(
                action: "view",
                competitionId: competition.id
            )
            fetchMembers()
            roundViewModel.startListening(competitionId: competition.id)
            NotificationQueueManager.shared.processQueuedNotifications()
        }
        .onDisappear {
            roundViewModel.stopListening()
            roundViewModel.clearResultsIfNotDismissed()
        }
        // ── Single cover that owns the entire round session ───────
        // Lobby → Judging → Results → Lobby all happen inside here.
        // CompDetails is never surfaced between those transitions.
        .fullScreenCover(isPresented: Binding(
            get: { roundViewModel.shouldShowRoundCover },
            set: { if !$0 { roundViewModel.dismissRoundCover() } }
        )) {
            roundFlowView
        }
        .sheet(isPresented: $showingThemePicker) {
            ThemePickerSheet(competition: competition) { themeId, themeName in
                showingThemePicker = false
                roundViewModel.createRound(
                    themeId: themeId,
                    themeName: themeName
                ) { _ in }
            }
        }
        .fullScreenCover(isPresented: $showingJoinSelectView, onDismiss: {
            fetchMembers()
        }) {
            JoinSelectView(competition: competition, viewModel: myFriendsModel)
        }
        .sheet(isPresented: $isEditingCompetition) {
            EditCompetitionView(competition: competition)
        }
        .alert(item: $activeAlert) { _ in
            Alert(
                title: Text("Get Notified When Your Friends Want to Play"),
                message: Text(""),
                dismissButton: .default(Text("OK"), action: {
                    notificationManager.requestNotificationPermission { granted in
                        if granted, let userId = Auth.auth().currentUser?.uid {
                            notificationManager.queueTokenUpdate(userId: userId)
                        }
                    }
                })
            )
        }
        // Refresh leaderboard after a round completes and results are dismissed
        .onChange(of: roundViewModel.justCompletedRound) { completed in
            if !completed {
                fetchMembers()
                roundViewModel.startListening(competitionId: competition.id)
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Round Flow View
    //
    // Owns the full session chain: lobby → judging → results → lobby.
    // RoundJudgingView presents results directly on top of itself so
    // CompDetails is never surfaced mid-session.
    // ─────────────────────────────────────────────────────────────

    @ViewBuilder
    private var roundFlowView: some View {
        switch roundViewModel.roundInfo?.status {
        case .waiting:
            RoundLobbyView(roundViewModel: roundViewModel, competition: competition)
        case .judging:
            // RoundJudgingView presents results directly on top of itself
            // via its own fullScreenCover — never double-present here.
            RoundJudgingView(roundViewModel: roundViewModel, competition: competition)
        default:
            // roundInfo is nil when:
            //   (a) results are showing — judging view is the right background
            //       since results are presented on top of it as a child cover
            //   (b) Play Again bridge — judging view stays until new lobby arrives
            // Either way, keeping RoundJudgingView here is correct and avoids
            // the blank screen that Color.clear caused.
            RoundJudgingView(roundViewModel: roundViewModel, competition: competition)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Leaderboard
    // ─────────────────────────────────────────────────────────────

    private var leaderboardSection: some View {
        let sorted = sortedMembers()
        return ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, member in
                    VStack(spacing: 0) {
                        HStack {
                                Text("\(index + 1)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(AppTheme.primaryText)
                                    .frame(width: 30)
                                    .padding(.leading, 20)

                                HStack(spacing: 20) {
                                    ProfilePictureView(url: member.profilePictureUrl, size: 40)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(member.userName)
                                            .font(.system(size: 16, weight: .bold))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .foregroundColor(AppTheme.primaryText)

                                        if member.totalRoundWinnings > 0 {
                                            Text("$\(String(format: "%.2f", member.totalRoundWinnings))")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                                                .background(AppTheme.green)
                                                .cornerRadius(200)
                                        }
                                    }
                                }

                                Spacer()

                                if member.roundsWon > 0 {
                                    HStack(spacing: 6) {
                                        Text("\(member.roundsWon)")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(.white)
                                        Image(systemName: "trophy.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 16, height: 16)
                                            .foregroundColor(.white)
                                    }
                                    .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                                    .background(AppTheme.gold)
                                    .cornerRadius(200)
                                    .padding(.trailing, 30)
                                } else {
                                    HStack(spacing: 6) {
                                        Text("0")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(.white)
                                        Image(systemName: "trophy.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 16, height: 16)
                                            .foregroundColor(.white)
                                    }
                                    .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                                    .background(AppTheme.disabledBackground)
                                    .cornerRadius(200)
                                    .padding(.trailing, 30)
                                }
                            }
                            .padding(.vertical, 25)
                            .background(member.userName == "Me"
                                         ? AppTheme.cardHighlight
                                         : AppTheme.cardBackground)

                            if index < sorted.count - 1 {
                                Divider().background(AppTheme.divider)
                            }
                    }
                }
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(10)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .refreshable {
            fetchMembers()
            roundViewModel.startListening(competitionId: competition.id)
        }
    }

    private func sortedMembers() -> [MemberEntry] {
        members.sorted { a, b in
            if a.roundsWon != b.roundsWon { return a.roundsWon > b.roundsWon }
            if a.totalRoundWinnings != b.totalRoundWinnings {
                return a.totalRoundWinnings > b.totalRoundWinnings
            }
            if a.userName == "Me" { return true }
            if b.userName == "Me" { return false }
            return a.userName < b.userName
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Fetch Members
    // ─────────────────────────────────────────────────────────────

    private func fetchMembers() {
        isLoading = true

        db.collection("competitions")
            .document(competition.id)
            .collection("members")
            .getDocuments { snapshot, error in
                guard let memberDocs = snapshot?.documents, error == nil else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        Analytics.shared.trackError(
                            message: error?.localizedDescription ?? "Failed to fetch competition members",
                            properties: [AnalyticsProperty.competitionId: self.competition.id]
                        )
                    }
                    return
                }

                let memberIds = memberDocs.map { $0.documentID }
                guard !memberIds.isEmpty else {
                    DispatchQueue.main.async {
                        self.members = []
                        self.isLoading = false
                    }
                    return
                }

                var statsByUserId: [String: (roundsWon: Int, totalRoundWinnings: Double)] = [:]
                for doc in memberDocs {
                    let data = doc.data()
                    statsByUserId[doc.documentID] = (
                        roundsWon:          data["rounds_won"]           as? Int    ?? 0,
                        totalRoundWinnings: data["total_round_winnings"] as? Double ?? 0.0
                    )
                }

                let chunks = stride(from: 0, to: memberIds.count, by: 30).map {
                    Array(memberIds[$0..<min($0 + 30, memberIds.count)])
                }

                var fetched: [MemberEntry] = []
                let group = DispatchGroup()

                for chunk in chunks {
                    group.enter()
                    self.db.collection("users")
                        .whereField(FieldPath.documentID(), in: chunk)
                        .getDocuments { snapshot, _ in
                            defer { group.leave() }
                            guard let docs = snapshot?.documents else { return }
                            let entries = docs.map { doc -> MemberEntry in
                                let data = doc.data()
                                let isMe = doc.documentID == self.currentUserId
                                let stats = statsByUserId[doc.documentID]
                                return MemberEntry(
                                    id:                 doc.documentID,
                                    userName:           isMe ? "Me" : (data["name"] as? String ?? "Unknown"),
                                    profilePictureUrl:  data["profilePictureUrl"] as? String,
                                    roundsWon:          stats?.roundsWon ?? 0,
                                    totalRoundWinnings: stats?.totalRoundWinnings ?? 0.0
                                )
                            }
                            fetched.append(contentsOf: entries)
                        }
                }

                group.notify(queue: .main) {
                    self.members = fetched
                    self.isLoading = false

                    UNUserNotificationCenter.current().getNotificationSettings { settings in
                        DispatchQueue.main.async {
                            if settings.authorizationStatus == .notDetermined,
                               fetched.count >= 2 {
                                self.activeAlert = .notification
                            }
                        }
                    }
                }
            }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Voice Call
    // ─────────────────────────────────────────────────────────────

    private func joinCall() {
        callManager.joinCall(
            competitionId:   competition.id,
            competitionName: competition.description
        ) { success in
            if !success { print("CompDetails: Failed to join call") }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Actions
    // ─────────────────────────────────────────────────────────────

    private func startNewRound() {
        if let themeName = roundViewModel.lastThemeName {
            roundViewModel.createRound(
                themeId: roundViewModel.lastThemeId,
                themeName: themeName
            ) { _ in }
        } else {
            showingThemePicker = true
        }
    }

    func addPlayer() {
        showingJoinSelectView = true
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - No Players View
// ─────────────────────────────────────────────────────────────

struct NoPlayersView: View {
    var action_player: () -> Void
    @State private var currentUserProfileUrl: String?
    private let db = Firestore.firestore()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("1")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
                    .frame(width: 30)
                    .padding(.leading, 20)

                HStack(spacing: 20) {
                    ProfilePictureView(url: currentUserProfileUrl, size: 40)
                    Text("Me")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                }

                Spacer()

                HStack(spacing: 6) {
                    Text("0")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Image(systemName: "trophy.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(.white)
                }
                .frame(width: 70, height: 30)
                .background(AppTheme.disabledBackground)
                .cornerRadius(200)
                .padding(.trailing, 30)
            }
            .padding(.vertical, 25)
            .background(AppTheme.cardHighlight)

            Divider().background(AppTheme.divider)

            ForEach(["Player 2", "Player 3"], id: \.self) { name in
                VStack(spacing: 0) {
                    HStack {
                        Text(name == "Player 2" ? "2" : "3")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.primaryText)
                            .frame(width: 30)
                            .padding(.leading, 20)

                        HStack(spacing: 20) {
                            ProfilePictureView(url: nil, size: 40)
                            Text(name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppTheme.primaryText)
                        }

                        Spacer()

                        Button(action: {
                            Analytics.shared.trackTap(
                                elementId: "add_player",
                                screenName: "competition_details"
                            )
                            action_player()
                        }) {
                            Text("Add")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 70, height: 30)
                                .background(AppTheme.accent)
                                .cornerRadius(200)
                        }
                        .padding(.trailing, 30)
                    }
                    .padding(.vertical, 25)
                    .background(AppTheme.cardBackground)

                    if name == "Player 2" {
                        Divider().background(AppTheme.divider)
                    }
                }
            }
        }
        .background(AppTheme.cardBackground)
        .cornerRadius(10)
        .padding(.horizontal, 20)
        .onAppear { fetchCurrentUserProfilePicture() }
    }

    private func fetchCurrentUserProfilePicture() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(userId).getDocument { document, _ in
            if let document = document, document.exists {
                self.currentUserProfileUrl = document.data()?["profilePictureUrl"] as? String
            }
        }
    }
}
