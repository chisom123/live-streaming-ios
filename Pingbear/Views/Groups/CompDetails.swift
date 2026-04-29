import SwiftUI
import FirebaseFirestore
import FirebaseAuth
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
    @State private var unreadMessageCount = 0
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
    @State private var showingThemeSelection = false
    @State private var selectedThemeForCapture: Theme? = nil
    @StateObject private var raceViewModel = RaceViewModel()
    
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
                            .foregroundColor(Color.white)
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
                            .foregroundColor(.white)
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
                            .foregroundColor(Color.white)
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
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24, weight: .bold))
                            .frame(width: 45, height: 45)
                            .padding(6)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }

                    NavigationLink(destination: EntryView(competitionId: competition.id, competition: competition)) {
                        Text("Start Rating")
                            .frame(maxWidth: .infinity, minHeight: 45)
                            .font(.system(size: 20, weight: .bold, design: .default))
                            .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .background(entryViewModel.hasEntriesToVoteOn ? Color(hex: "#4169E1") : Color(hex: "#D3D3D3").opacity(0.2))
                            .foregroundColor(entryViewModel.hasEntriesToVoteOn ? Color.white : Color(hex: "#D3D3D3").opacity(0.2))
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
                            Image(systemName: "message.fill")
                                .font(.system(size: 24, weight: .bold))
                                .frame(width: 45, height: 45)
                                .padding(6)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                            
                            if chatIndicator.hasUnreadMessages {
                                Text(chatIndicator.displayCount)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 20, minHeight: 20)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 12, y: -12)
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
                .background(Color(hex: "#1A2245"))
                .cornerRadius(10)
                .padding(.top, 20)
                .padding(.bottom, shouldShowRaceBar ? 0 : 20)
                .padding(.horizontal, 20)
                
                // MARK: - Race Status Bar
                if shouldShowRaceBar {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Prize Pool")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.bottom, 2)
                                
                                HStack(spacing: 4) {
                                    Text(raceViewModel.hasActiveRace ? "\(raceViewModel.raceInfo?.pointsPool ?? 0)" : "Win Points")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(Color(hex: "#FFF"))
                                    
                                    Image("gem")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(.white)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 23, height: 23)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(Color(hex: "#6A5ACD"))
                                .cornerRadius(12)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Ends In")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.bottom, 2)
                                
                                Text(raceViewModel.hasActiveRace ? raceViewModel.timeRemaining : "24h")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(hex: "#1A2245"))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                
                if isLoading {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    if entryViewModel.totalMemberCount == 1 {
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
                                
                                Analytics.shared.trackTap(
                                    elementId: "leaderboard_user_cell",
                                    screenName: "competition_details"
                                )
                            }
                        )
                    } else {
                        if entryViewModel.userLeaderboard.isEmpty {
                            EmptyLeaderboardView(action: {
                                checkCameraAndMicrophonePermissions { granted in
                                    if granted {
                                        joincomp()
                                    } else {
                                        self.activeAlert = .camera
                                    }
                                }
                                Analytics.shared.trackTap(
                                    elementId: "add_photo_initiated",
                                    screenName: "competition_details"
                                )
                            })
                            Spacer()
                        } else {
                            ScrollView {
                                // MARK: - Leaderboard
                                VStack(spacing: 0) {
                                    ForEach(Array(sortedLeaderboard().enumerated()), id: \.element.id) { index, userEntry in
                                        Button(action: {
                                            selectedUserForPhotos = UserSelection(
                                                user: userEntry,
                                                competitionId: competition.id
                                            )
                                            Analytics.shared.trackTap(
                                                elementId: "leaderboard_user_cell",
                                                screenName: "competition_details"
                                            )
                                        }) {
                                            VStack(spacing: 0) {
                                                HStack {
                                                    // Position
                                                    Text("\(index + 1)")
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .frame(width: 30)
                                                        .padding(.leading, 20)
                                                    
                                                    HStack(spacing: 20) {
                                                        ProfilePictureView(url: userEntry.profilePictureUrl, size: 40)
                                                        
                                                        VStack(alignment: .leading, spacing: 4) {
                                                            Text(userEntry.userName)
                                                                .font(.system(size: 16, weight: .bold))
                                                                .lineLimit(1)
                                                                .truncationMode(.tail)
                                                                .foregroundColor(.white)
                                                            
                                                            // Projected points badge
                                                            if let points = projectedPoints(for: userEntry), points > 0 {
                                                                HStack(spacing: 4) {
                                                                    Text("\(points)")
                                                                        .font(.system(size: 14, weight: .bold))
                                                                        .foregroundColor(.white)
                                                                    
                                                                    Image("gem")
                                                                        .resizable()
                                                                        .renderingMode(.template)
                                                                        .foregroundColor(.white)
                                                                        .aspectRatio(contentMode: .fit)
                                                                        .frame(width: 15, height: 15)
                                                                }
                                                                .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                                                                .background(Color(hex: "#6A5ACD"))
                                                                .cornerRadius(200)
                                                            }
                                                        }
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    // Today's race stars
                                                    HStack(spacing: 8) {
                                                        Text("\(raceStars(for: userEntry))")
                                                            .font(.system(size: 17, weight: .bold))
                                                            .foregroundColor(Color(hex: "#FFF"))
                                                        
                                                        Image(systemName: "star.fill")
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: 18, height: 18)
                                                            .foregroundColor(Color(hex: "#FFF"))
                                                    }
                                                    .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                                                    .background(Color(hex: "#DAA520"))
                                                    .cornerRadius(200)
                                                    .padding(.trailing, 30)
                                                }
                                                .padding(.vertical, 25)
                                                .background(userEntry.userName == "Me" ? Color(hex: "#2A3255") : Color.clear)
                                                
                                                if index < sortedLeaderboard().count - 1 {
                                                    Divider()
                                                        .background(Color.white.opacity(0.2))
                                                }
                                            }
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .background(Color(hex: "#1A2245"))
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
            }
        }
        .background(Color(hex: "#10183C"))
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
    
    /// Returns today's race stars for a given user entry
    private func raceStars(for userEntry: UserEntry) -> Int {
        return raceViewModel.participants
            .first { $0.userId == userEntry.id }?.totalStars ?? 0
    }
    
    /// Returns projected points for a user if they have stars in today's race
    private func projectedPoints(for userEntry: UserEntry) -> Int? {
        guard raceViewModel.hasActiveRace else { return nil }
        let points = raceViewModel.participants
            .first { $0.userId == userEntry.id }?.projectedPoints ?? 0
        return points > 0 ? points : nil
    }
    
    /// Returns the leaderboard sorted by today's race stars descending
    /// Users with 0 race stars sink to the bottom, sorted by name for consistency
    private func sortedLeaderboard() -> [UserEntry] {
        return entryViewModel.userLeaderboard.sorted { a, b in
            let starsA = raceStars(for: a)
            let starsB = raceStars(for: b)
            if starsA != starsB {
                return starsA > starsB
            }
            // Equal stars - keep "Me" at top of tied group, otherwise alphabetical
            if a.userName == "Me" { return true }
            if b.userName == "Me" { return false }
            return a.userName < b.userName
        }
    }
    
    private var shouldShowRaceBar: Bool {
        !isLoading
    }
    
    // MARK: - Data Fetching
    
    private func fetchData() {
        isLoading = true
        
        entryViewModel.fetchEntries(mode: .compDetailsView) {
            entryViewModel.fetchMemberCount()
            DispatchQueue.main.async {
                self.isLoading = false
                
                let userIsOnLeaderboard = self.entryViewModel.userLeaderboard.contains { userEntry in
                    userEntry.userName == "Me" || userEntry.id == self.currentUserId
                }
                
                if userIsOnLeaderboard {
                    self.hasUserPostedFirstEntry = true
                }
                
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

// MARK: - Empty / No Players Views (unchanged)

struct EmptyLeaderboardView: View {
    var action: () -> Void
    
    var body: some View {
        VStack {
            Text("No Activity Yet")
                .font(.system(size: 21, weight: .bold, design: .default))
                .foregroundColor(.white)
                .padding(.top, 20)
                .padding(.bottom, 20)
            
            VStack() {
                Button(action: action) {
                    HStack {
                        Text("New Photo")
                            .font(.system(size: 17, weight: .bold, design: .default))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: "#4169E1"))
                    .foregroundColor(.white)
                    .cornerRadius(200)
                }
            }
            .frame(width: 280)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(hex: "#1A2245"))
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
                ForEach(Array(["Me", "Player 2", "Player 3", "Player 4"].enumerated()), id: \.element) { index, userName in
                    VStack(spacing: 0) {
                        if userName == "Me" {
                            Button(action: {
                                onMeTapped()
                            }) {
                                HStack {
                                    Text("\(index + 1)")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 30)
                                        .padding(.leading, 20)
                                    
                                    HStack(spacing: 20) {
                                        ProfilePictureView(url: currentUserProfileUrl, size: 40)
                                        
                                        Text(userName)
                                            .font(.system(size: 16, weight: .bold))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .foregroundColor(.white)
                                    }

                                    Spacer()

                                    HStack(spacing: 6.5) {
                                        Text("0")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(Color(hex: "#FFF"))
                                        
                                        Image(systemName: "star.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 18, height: 18)
                                            .foregroundColor(Color(hex: "#FFF"))
                                    }
                                    .frame(width: 70, height: 30)
                                    .background(Color(hex: "#DAA520"))
                                    .cornerRadius(200)
                                    .padding(.trailing, 30)
                                }
                                .padding(.vertical, 25)
                                .background(Color(hex: "#2A3255"))
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            HStack {
                                Text("\(index + 1)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 30)
                                    .padding(.leading, 20)
                                
                                HStack(spacing: 20) {
                                    ProfilePictureView(url: nil, size: 40)
                                    
                                    Text(userName)
                                        .font(.system(size: 16, weight: .bold))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .foregroundColor(.white)
                                }

                                Spacer()

                                Button(action: action_player) {
                                    Text("Add")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(Color(hex: "#FFF"))
                                        .frame(width: 70, height: 30)
                                        .background(Color(hex: "#4169E1"))
                                        .cornerRadius(200)
                                }
                                .padding(.trailing, 30)
                            }
                            .padding(.vertical, 25)
                            .background(Color.clear)
                        }
                        
                        if userName != "Player 4" {
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
