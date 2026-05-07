import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import AVFoundation

extension CompDetails {
    struct UserSelection: Identifiable {
        let id = UUID()
        let user: UserEntry
        let competitionId: String
    }
}

struct CompDetails: View {
    
    enum AlertType: Identifiable {
        case camera, notification
        
        var id: Int {
            switch self {
                case .camera: return 0
                case .notification: return 1
            }
        }
    }
    
    @Environment(\.dismiss) private var dismiss
    @State private var isCameraPresented = false
    @State private var isEditingCompetition = false
    @State private var currentUserId: String = Auth.auth().currentUser?.uid ?? ""
    @State private var isLoading = true
    @StateObject private var notificationManager = PushNotificationManager.shared
    @State private var activeAlert: AlertType?
    @State private var selectedUserForPhotos: UserSelection? = nil
    @State private var currentUserProfilePictureUrl: String? = nil
    @StateObject private var chatIndicator: ChatIndicatorViewModel
    @State private var showingJoinSelectView = false
    @State private var hasUserPostedFirstEntry = false
    @StateObject private var myFriendsModel = MyFriendsModel()
    @StateObject private var themesViewModel = ThemesViewModel()
    @State private var selectedThemeForCapture: Theme? = nil
    @StateObject private var raceViewModel = RaceViewModel()
    @State private var showContributeSheet = false

    @ObservedObject var entryViewModel: EntryViewModel
    @ObservedObject var competition: Competition
    
    private let db = Firestore.firestore()

    init(competition: Competition) {
        self.competition = competition
        self.entryViewModel = EntryViewModel(competitionId: competition.id, mode: .compDetailsView)
        self._chatIndicator = StateObject(wrappedValue: ChatIndicatorViewModel(competitionId: competition.id))
    }

    
    var body: some View {
        ZStack {
            VStack(alignment: .leading) {

                // ── Header ────────────────────────────────────
                HStack {
                    Button(action: {
                        entryViewModel.removeListeners()
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
                            elementId: "edit_competition_name_button",
                            screenName: "competition_details"
                        )
                    }) {
                        Text(competition.description == "Competition" ? "Add Competition Name" : competition.description)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .lineLimit(1)
                            .foregroundColor(AppTheme.primaryText)
                            .padding(.horizontal)
                            .onAppear {
                                Analytics.shared.trackCompetition(
                                    action: "view",
                                    competitionId: competition.id
                                )
                            }
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
                        entryViewModel.removeListeners()
                        Analytics.shared.trackTap(
                            elementId: "view_competitors",
                            screenName: "competition_details"
                        )
                    })
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // ── Action buttons ────────────────────────────
                HStack(spacing: 10) {
                    Button(action: {
                        entryViewModel.removeListeners()
                        Analytics.shared.trackTap(
                            elementId: "add_photo_initiated",
                            screenName: "competition_details"
                        )
                        checkCameraAndMicrophonePermissions { granted in
                            if granted {
                                joincomp()
                            } else {
                                self.activeAlert = .camera
                            }
                        }
                    }) {
                        Image("camera")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(AppTheme.iconColor)
                            .frame(width: 32, height: 32)
                            .frame(width: 45, height: 45)
                            .padding(6)
                    }

                    NavigationLink(destination: EntryView(competitionId: competition.id, competition: competition)) {
                        Text("Start Rating")
                            .frame(maxWidth: .infinity, minHeight: 45)
                            .font(.system(size: 20, weight: .bold, design: .default))
                            .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .background(entryViewModel.hasEntriesToVoteOn ? AppTheme.accent : AppTheme.disabledBackground)
                            .foregroundColor(entryViewModel.hasEntriesToVoteOn ? Color.white : AppTheme.disabledText)
                            .cornerRadius(200)
                    }
                    .disabled(!entryViewModel.hasEntriesToVoteOn)
                    .simultaneousGesture(TapGesture().onEnded {
                        entryViewModel.removeListeners()
                        if entryViewModel.hasEntriesToVoteOn {
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        }
                        Analytics.shared.trackEntry(
                            action: "rate",
                            competitionId: competition.id
                        )
                    })
                    
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
                        entryViewModel.removeListeners()
                        chatIndicator.markAsRead()
                    })
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 10)
                .background(AppTheme.cardBackground)
                .cornerRadius(10)
                .padding(.top, 20)
                .padding(.horizontal, 20)

                // ── Race Bar ──────────────────────────────────
                if !isLoading {
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Prize Pool")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.secondaryText)
                                    .padding(.bottom, 2)
                                
                                Button {
                                    showContributeSheet = true
                                    Analytics.shared.trackTap(
                                        elementId: "add_to_prize_pool",
                                        screenName: "competition_details"
                                    )
                                } label: {
                                    HStack(spacing: 0) {
                                        Text("$\(String(format: "%.2f", raceViewModel.raceInfo?.totalPot ?? 0.0))")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 3)
                                        
                                        Image(systemName: "plus")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .frame(maxHeight: .infinity)
                                            .background(Color.black.opacity(0.12))
                                    }
                                    .fixedSize(horizontal: false, vertical: true)
                                    .background(AppTheme.green)
                                    .cornerRadius(200)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Ends In")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.secondaryText)
                                    .padding(.bottom, 2)

                                Text(raceViewModel.hasActiveRace ? raceViewModel.timeRemaining : "--")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(AppTheme.primaryText)
                            }
                        }
                    }
                    .padding(20)
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }

                // ── Leaderboard ───────────────────────────────
                if isLoading {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if entryViewModel.totalMemberCount == 1 {
                    NoPlayersView(
                        action_player: addPlayer,
                        onMeTapped: {
                            let currentUserEntry = UserEntry(
                                id: currentUserId,
                                userName: "Me",
                                profilePictureUrl: currentUserProfilePictureUrl,
                                totalStars: 0
                            )
                            selectedUserForPhotos = UserSelection(
                                user: currentUserEntry,
                                competitionId: competition.id
                            )
                        }
                    )
                } else if entryViewModel.userLeaderboard.isEmpty {
                    EmptyLeaderboardView(action: {
                        checkCameraAndMicrophonePermissions { granted in
                            if granted { joincomp() } else { activeAlert = .camera }
                        }
                    })
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(sortedLeaderboard().enumerated()), id: \.element.id) { index, userEntry in
                                Button(action: {
                                    Analytics.shared.trackTap(
                                        elementId: "leaderboard_cell",
                                        screenName: "competition_details"
                                    )
                                    selectedUserForPhotos = UserSelection(
                                        user: userEntry,
                                        competitionId: competition.id
                                    )
                                }) {
                                    VStack(spacing: 0) {
                                        HStack {
                                            Text("\(index + 1)")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(AppTheme.primaryText)
                                                .frame(width: 30)
                                                .padding(.leading, 20)

                                            HStack(spacing: 20) {
                                                ProfilePictureView(url: userEntry.profilePictureUrl, size: 40)

                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(userEntry.userName)
                                                        .font(.system(size: 16, weight: .bold))
                                                        .lineLimit(1)
                                                        .truncationMode(.tail)
                                                        .foregroundColor(AppTheme.primaryText)

                                                    if let payout = projectedPayout(for: userEntry), payout > 0 {
                                                        Text("$\(String(format: "%.2f", payout))")
                                                            .font(.system(size: 14, weight: .bold))
                                                            .foregroundColor(.white)
                                                            .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                                                            .background(AppTheme.green)
                                                            .cornerRadius(200)
                                                    }
                                                }
                                            }

                                            Spacer()

                                            HStack(spacing: 8) {
                                                Text("\(raceStars(for: userEntry))")
                                                    .font(.system(size: 17, weight: .bold))
                                                    .foregroundColor(.white)

                                                Image(systemName: "star.fill")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 18, height: 18)
                                                    .foregroundColor(.white)
                                            }
                                            .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                                            .background(AppTheme.gold)
                                            .cornerRadius(200)
                                            .padding(.trailing, 30)
                                        }
                                        .padding(.vertical, 25)
                                        .background(userEntry.userName == "Me" ? AppTheme.cardHighlight : AppTheme.cardBackground)

                                        if index < sortedLeaderboard().count - 1 {
                                            Divider()
                                                .background(AppTheme.divider)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .background(AppTheme.cardBackground)
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .refreshable {
                        entryViewModel.fetchEntries(mode: .compDetailsView)
                        entryViewModel.fetchMemberCount()
                        raceViewModel.loadRace(competitionId: competition.id)
                    }
                }
            }
        }
        .background(AppTheme.pageBackground)
        .navigationBarHidden(true)
        .onAppear {
            fetchData()
            NotificationQueueManager.shared.processQueuedNotifications()
            fetchCurrentUserProfilePictureUrl()
            entryViewModel.setupListeners()
            themesViewModel.loadThemes(for: competition.id)
            raceViewModel.loadRace(competitionId: competition.id)
        }
        .onDisappear {
            entryViewModel.removeListeners()
            raceViewModel.stopListening()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissCameraFlow)) { _ in
            isCameraPresented = false
            
            if !hasUserPostedFirstEntry {
                print("CompDetails: Refreshing data after first entry")
                fetchData()
                hasUserPostedFirstEntry = true
                NotificationQueueManager.shared.processQueuedNotifications()
            } else {
                NotificationQueueManager.shared.processQueuedNotifications()
            }
        }
        .fullScreenCover(isPresented: $isCameraPresented, onDismiss: {
            selectedThemeForCapture = nil
        }) {
            CameraView(competition: competition, preselectedTheme: $selectedThemeForCapture)
        }
        .fullScreenCover(isPresented: $showingJoinSelectView, onDismiss: {
            entryViewModel.fetchMemberCount()
            entryViewModel.fetchEntries(mode: .compDetailsView)
        }) {
            JoinSelectView(competition: competition, viewModel: myFriendsModel)
        }
        .sheet(isPresented: $isEditingCompetition) {
            EditCompetitionView(competition: competition)
        }
        .sheet(isPresented: $showContributeSheet, onDismiss: {
            raceViewModel.loadRace(competitionId: competition.id)
        }) {
            ContributeSheet(
                competitionId: competition.id,
                raceId: raceViewModel.raceInfo?.raceId,
                currentPot: raceViewModel.raceInfo?.totalPot ?? 0.0,
                onContributed: {
                    raceViewModel.loadRace(competitionId: competition.id)
                }
            )
        }
        .sheet(item: $selectedUserForPhotos, onDismiss: {
            chatIndicator.refresh()
        }) { selection in
            UserPhotosView(
                userId: selection.user.userName == "Me" ? currentUserId : selection.user.id,
                userName: selection.user.userName,
                competitionId: selection.competitionId,
                userProfilePictureUrl: selection.user.profilePictureUrl
            )
        }
        .alert(item: $activeAlert) { alertType in
            switch alertType {
            case .camera:
                return Alert(
                    title: Text("Camera Required"),
                    message: Text("Camera access is required to take photos. Please enable it in Settings."),
                    primaryButton: .default(Text("Open Settings"), action: openSettings),
                    secondaryButton: .cancel()
                )
            case .notification:
                return Alert(
                    title: Text("Get Notified When Your Friends Post Photos to Rate"),
                    message: Text(""),
                    dismissButton: .default(Text("OK"), action: {
                        notificationManager.requestNotificationPermission { granted in
                            if granted {
                                if let userId = Auth.auth().currentUser?.uid {
                                    notificationManager.queueTokenUpdate(userId: userId)
                                }
                                Analytics.shared.trackTap(
                                    elementId: "notification_permission_granted",
                                    screenName: "competition_details"
                                )
                                print("Notification permission granted and token queued")
                            } else {
                                Analytics.shared.trackTap(
                                    elementId: "notification_permission_denied",
                                    screenName: "competition_details"
                                )
                                print("Permission request denied")
                            }
                        }
                    })
                )
            }
        }
    }
    
    // MARK: - Race Helpers

    private func raceStars(for userEntry: UserEntry) -> Int {
        raceViewModel.participants.first { $0.userId == userEntry.id }?.totalStars ?? 0
    }

    private func projectedPayout(for userEntry: UserEntry) -> Double? {
        guard raceViewModel.hasActiveRace,
              let pot = raceViewModel.raceInfo?.totalPot, pot > 0 else { return nil }
        let payout = raceViewModel.participants.first { $0.userId == userEntry.id }?.projectedPayout ?? 0
        return payout > 0 ? payout : nil
    }

    private func sortedLeaderboard() -> [UserEntry] {
        entryViewModel.userLeaderboard.sorted { a, b in
            let starsA = raceStars(for: a)
            let starsB = raceStars(for: b)
            if starsA != starsB { return starsA > starsB }
            if a.userName == "Me" { return true }
            if b.userName == "Me" { return false }
            return a.userName < b.userName
        }
    }

    // MARK: - Data Fetching

    private func fetchData() {
        isLoading = true
        
        entryViewModel.fetchEntries(mode: .compDetailsView) {
            entryViewModel.fetchMemberCount()
            DispatchQueue.main.async {
                self.isLoading = false
                let onLeaderboard = self.entryViewModel.userLeaderboard.contains {
                    $0.userName == "Me" || $0.id == self.currentUserId
                }
                if onLeaderboard { self.hasUserPostedFirstEntry = true }

                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    DispatchQueue.main.async {
                        if settings.authorizationStatus == .notDetermined {
                            if entryViewModel.totalMemberCount >= 2 {
                                self.activeAlert = .notification
                            }
                        }
                    }
                }
            }
        }
    }
    
    func checkCameraAndMicrophonePermissions(completion: @escaping (Bool) -> Void) {
        let cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch cameraAuthStatus {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        default:
            completion(false)
        }
    }
    
    func joincomp() {
        entryViewModel.removeListeners()
        self.isCameraPresented = true
    }
    
    func openSettings() {
        entryViewModel.removeListeners()
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    func addPlayer() {
        entryViewModel.removeListeners()
        showingJoinSelectView = true
        Analytics.shared.trackTap(
            elementId: "add_player_prompt",
            screenName: "competition_details"
        )
    }
    
    private func fetchCurrentUserProfilePictureUrl() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(currentUserId).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching current user profile: \(error)")
                return
            }
            
            if let data = snapshot?.data(), let profilePictureUrl = data["profilePictureUrl"] as? String {
                DispatchQueue.main.async {
                    self.currentUserProfilePictureUrl = profilePictureUrl
                }
            }
        }
    }
}

// MARK: - Empty / No Players Views

struct EmptyLeaderboardView: View {
    var action: () -> Void

    var body: some View {
        VStack {
            Text("No Activity Yet")
                .font(.system(size: 21, weight: .bold, design: .default))
                .foregroundColor(AppTheme.primaryText)
                .padding(.top, 20)
                .padding(.bottom, 20)
            
            VStack {
                Button(action: action) {
                    HStack {
                        Text("New Photo")
                            .font(.system(size: 17, weight: .bold, design: .default))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppTheme.accent)
                    .foregroundColor(.white)
                    .cornerRadius(200)
                }
            }
            .frame(width: 280)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(AppTheme.cardBackground)
        .cornerRadius(10)
        .padding(.horizontal, 20)
    }
}

struct NoPlayersView: View {
    var action_player: () -> Void
    var onMeTapped: () -> Void
    @State private var currentUserProfileUrl: String?
    private let db = Firestore.firestore()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(["Me", "Player 2", "Player 3"].enumerated()), id: \.element) { index, userName in
                    VStack(spacing: 0) {
                        if userName == "Me" {
                            Button(action: { onMeTapped() }) {
                                HStack {
                                    Text("\(index + 1)")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AppTheme.primaryText)
                                        .frame(width: 30)
                                        .padding(.leading, 20)
                                    
                                    HStack(spacing: 20) {
                                        ProfilePictureView(url: currentUserProfileUrl, size: 40)
                                        
                                        Text(userName)
                                            .font(.system(size: 16, weight: .bold))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .foregroundColor(AppTheme.primaryText)
                                    }

                                    Spacer()

                                    HStack(spacing: 6.5) {
                                        Text("0")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        Image(systemName: "star.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 18, height: 18)
                                            .foregroundColor(.white)
                                    }
                                    .frame(width: 70, height: 30)
                                    .background(AppTheme.gold)
                                    .cornerRadius(200)
                                    .padding(.trailing, 30)
                                }
                                .padding(.vertical, 25)
                                .background(AppTheme.cardHighlight)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            HStack {
                                Text("\(index + 1)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(AppTheme.primaryText)
                                    .frame(width: 30)
                                    .padding(.leading, 20)
                                
                                HStack(spacing: 20) {
                                    ProfilePictureView(url: nil, size: 40)
                                    
                                    Text(userName)
                                        .font(.system(size: 16, weight: .bold))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .foregroundColor(AppTheme.primaryText)
                                }

                                Spacer()

                                Button(action: action_player) {
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
                        }
                        
                        if userName != "Player 3" {
                            Divider()
                                .background(AppTheme.divider)
                        }
                    }
                }
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(10)
            .padding(.horizontal, 20)
        }
        .onAppear {
            fetchCurrentUserProfilePicture()
        }
    }
    
    private func fetchCurrentUserProfilePicture() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(userId).getDocument { document, error in
            if let document = document, document.exists {
                self.currentUserProfileUrl = document.data()?["profilePictureUrl"] as? String
            }
        }
    }
}
