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
    
    @Environment(\.presentationMode) var presentationMode
    @State private var goToMyComps = false
    @State private var isCameraPresented = false
    @State private var isMembersPresented = false
    @State private var isVotingPresented = false
    @State private var isEditingCompetition = false
    @State private var isChatPresented = false
    @State private var unreadMessageCount = 0
    @State private var currentUserId: String = Auth.auth().currentUser?.uid ?? ""
    @State private var isLoading = true
    @StateObject private var notificationManager = PushNotificationManager.shared
    @State private var activeAlert: AlertType?
    @State private var selectedUserForPhotos: UserSelection? = nil
    @State private var currentUserProfilePictureUrl: String? = nil
    @StateObject private var chatIndicator: ChatIndicatorViewModel
    @State private var showingJoinSelectView = false
    
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
                        goToMyComps = true
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
                    
                    Button(action: {
                        entryViewModel.removeListeners()
                        isMembersPresented = true
                        Analytics.shared.trackTap(
                            elementId: "view_competitors",
                            screenName: "competition_details"
                        )
                    }) {
                        Image(systemName: "ellipsis")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .foregroundColor(Color.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                HStack(spacing: 10) {
                    Button(action: {
                        entryViewModel.removeListeners()
                        initiateVideoCapture()
                    }) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24, weight: .bold))
                            .frame(width: 45, height: 45)
                            .padding(6)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }

                    Button(action: {
                        vote()
                        Analytics.shared.trackEntry(
                            action: "rate",
                            competitionId: competition.id
                        )
                    }) {
                        Text("Start Rating")
                            .frame(maxWidth: .infinity, minHeight: 45)
                            .font(.system(size: 20, weight: .bold, design: .default))
                            .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .background(entryViewModel.hasEntriesToVoteOn ? Color(hex: "#FF4081") : Color(hex: "#D3D3D3").opacity(0.2))
                            .foregroundColor(entryViewModel.hasEntriesToVoteOn ? Color.white : Color(hex: "#D3D3D3").opacity(0.2))
                            .cornerRadius(200)
                    }
                    .disabled(!entryViewModel.hasEntriesToVoteOn)
                    
                    Button(action: {
                        entryViewModel.removeListeners()
                        chatIndicator.markAsRead()
                        isChatPresented = true
                    }) {
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
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 10)
                .background(Color(hex: "#1A2245"))
                .cornerRadius(10)
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
                
                if isLoading {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    if entryViewModel.totalMemberCount == 1 {
                        NoPlayersView(
                            action_player: addPlayer,
                            onMeTapped: {
                                // Create a UserEntry for the current user
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
                            EmptyLeaderboardView(action: initiateVideoCapture)
                            Spacer()
                        } else {
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(Array(entryViewModel.userLeaderboard.enumerated()), id: \.element.id) { index, userEntry in
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
                                                    Text("\(index + 1)")
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .frame(width: 30)
                                                        .padding(.leading, 20)
                                                    
                                                    HStack(spacing: 20) {
                                                        ProfilePictureView(url: userEntry.profilePictureUrl, size: 40)
                                                        
                                                        Text(userEntry.userName)
                                                            .font(.system(size: 16, weight: .bold))
                                                            .lineLimit(1)
                                                            .truncationMode(.tail)
                                                            .foregroundColor(.white)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    HStack(spacing: 8) {
                                                        Text("\(userEntry.totalStars)")
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
                                                
                                                if userEntry.id != entryViewModel.userLeaderboard.last?.id {
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
                            }
                            .refreshable {
                                entryViewModel.fetchEntries(mode: .compDetailsView)
                                entryViewModel.fetchMemberCount()
                            }
                        }
                    }
                }
                
            }
        }
        .background(Color(hex: "#10183C"))
        .onAppear {
            fetchData()
            NotificationQueueManager.shared.processQueuedNotifications()
            fetchCurrentUserProfilePictureUrl()
        }
        .fullScreenCover(isPresented: $isCameraPresented, content: {
            CameraView(competition: competition)
        })
        .fullScreenCover(isPresented: $isVotingPresented, onDismiss: {
            // Re-setup listeners after returning from voting
            entryViewModel.setupListeners()
            // Then refresh the vote status immediately
            entryViewModel.refreshVoteStatus()
            chatIndicator.refresh()
        }, content: {
            EntryView(competitionId: competition.id, competition: competition)
        })
        .fullScreenCover(isPresented: $goToMyComps) {
            MyCompsView()
        }
        .fullScreenCover(isPresented: $isMembersPresented) {
            MembersView(competition: competition)
        }
        .fullScreenCover(isPresented: $isChatPresented) {
            ChatView(competition: competition)
        }
        .fullScreenCover(isPresented: $showingJoinSelectView) {
            JoinSelectView(competition: competition, viewModel: MyFriendsModel())
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
        .onDisappear {
            entryViewModel.removeListeners()
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
                    title: Text("Get Notified When There Are New Photos for You to Rate"),
                    message: Text(""),
                    dismissButton: .default(Text("OK"), action: {
                        notificationManager.requestNotificationPermission { granted in
                            if granted {
                                // Explicitly queue the token update to ensure persistence
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
    
    private func fetchData() {
        isLoading = true
        
        entryViewModel.fetchEntries(mode: .compDetailsView) {
            entryViewModel.fetchMemberCount()
            DispatchQueue.main.async {
                self.isLoading = false
                
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
    
    
    func initiateVideoCapture() {
        entryViewModel.removeListeners()
        checkCameraAndMicrophonePermissions { granted in
            if granted {
                Analytics.shared.trackTap(
                    elementId: "add_photo_initiated",
                    screenName: "competition_details"
                )
                joincomp()
            } else {
                self.activeAlert = .camera
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
    func vote() {
        entryViewModel.removeListeners()
        self.isVotingPresented = true
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

struct EmptyLeaderboardView: View {
    var action: () -> Void
    
    var body: some View {
        VStack {
            Text("No Activity Yet")
                .font(.system(size: 21, weight: .bold, design: .default))
                .foregroundColor(.white)
                .padding(.top, 20)
                .padding(.bottom, 25)
            
            Button(action: {
                action()
            }) {
                Text("New Photo")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .background(Color(hex: "#FF4081"))
                    .foregroundColor(.white)
                    .cornerRadius(200)
            }
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
    var onMeTapped: () -> Void  // Add this parameter
    @State private var currentUserProfileUrl: String?
    private let db = Firestore.firestore()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(["Me", "Player 2", "Player 3", "Player 4"].enumerated()), id: \.element) { index, userName in
                    VStack(spacing: 0) {
                        if userName == "Me" {
                            // Make the entire "Me" cell tappable
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
                                    .padding(EdgeInsets(top: 2.75, leading: 12.75, bottom: 2.75, trailing: 12.75))
                                    .background(Color(hex: "#DAA520"))
                                    .cornerRadius(200)
                                    .padding(.trailing, 30)
                                }
                                .padding(.vertical, 25)
                                .background(Color(hex: "#2A3255"))
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            // For other cells, only the Add button is tappable
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
                                    HStack(spacing: 8) {
                                        Text("Add")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(Color(hex: "#FFF"))
                                    }
                                    .padding(EdgeInsets(top: 3, leading: 15, bottom: 3, trailing: 15))
                                    .background(Color(hex: "#FF4081"))
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
