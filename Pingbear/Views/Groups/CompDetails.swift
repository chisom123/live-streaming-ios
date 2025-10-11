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
    
    @State private var userCoins: Int = 0
    @State private var isLoadingCoins = true
    @State private var showPayView = false
    @StateObject private var payViewModel = PayViewModel()
    
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
                    
                    HStack(alignment: .center, spacing: 0) {
                        HStack {
                            Image("coin")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 19, height: 19)
                                .padding(.leading, 15)
                            
                            if isLoadingCoins {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("\(userCoins)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                        }
                        .frame(height: 45)
                        .background(
                            Color(hex: "#2A3255")
                                .clipShape(
                                    RoundedCorner(
                                        radius: 10,
                                        corners: [.topLeft, .bottomLeft]
                                    )
                                )
                        )
                        
                        Button(action: {
                            showPayView = true
                            Analytics.shared.trackTap(
                                elementId: "coins_button_header",
                                screenName: "competition_details"
                            )
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .frame(width: 45, height: 45)
                                .foregroundColor(.white)
                                .background(
                                    Color(hex: "#3B4374")
                                        .clipShape(
                                            RoundedCorner(
                                                radius: 10,
                                                corners: [.topRight, .bottomRight]
                                            )
                                        )
                                )
                        }
                    }
                    .padding(.horizontal, 40)
                    
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
                        initiateVideoCapture()
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
        .navigationBarHidden(true)
        .onAppear {
            fetchData()
            NotificationQueueManager.shared.processQueuedNotifications()
            fetchCurrentUserProfilePictureUrl()
            fetchUserCoins()
            
            entryViewModel.setupListeners()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissCameraFlow)) { _ in
            // Dismiss the camera modal immediately
            isCameraPresented = false
            
            // Refresh data immediately for better UX
            if !hasUserPostedFirstEntry {
                print("CompDetails: Refreshing data after first entry")
                fetchData()
                hasUserPostedFirstEntry = true
                
                // Process notifications without delay, but handle potential failures gracefully
                NotificationQueueManager.shared.processQueuedNotifications()
            } else {
                // Process notifications immediately for existing users too
                NotificationQueueManager.shared.processQueuedNotifications()
            }
            
            fetchUserCoins()
        }
        // ✅ KEEP: Only Camera as fullScreenCover (true modal)
        .fullScreenCover(isPresented: $isCameraPresented, content: {
            CameraView(competition: competition)
        })
        // ✅ REMOVED: Voting fullScreenCover - now using NavigationLink
        .fullScreenCover(isPresented: $showingJoinSelectView, onDismiss: {
            entryViewModel.fetchMemberCount()
            entryViewModel.fetchEntries(mode: .compDetailsView)
        }) {
            // content closure comes last
            JoinSelectView(competition: competition, viewModel: myFriendsModel)
        }
        .sheet(isPresented: $isEditingCompetition) {
            EditCompetitionView(competition: competition)
        }
        .sheet(item: $selectedUserForPhotos, onDismiss: {
            chatIndicator.refresh()
            fetchUserCoins()
        }) { selection in
            UserPhotosView(
                userId: selection.user.userName == "Me" ? currentUserId : selection.user.id,
                userName: selection.user.userName,
                competitionId: selection.competitionId,
                userProfilePictureUrl: selection.user.profilePictureUrl
            )
        }
        .sheet(isPresented: $showPayView, onDismiss: fetchUserCoins) {
            PayView(viewModel: payViewModel, competition: competition, competitionId: competition.id, entryDocId: "")
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
                    title: Text("Get Notified When Your Friends Post Photos to Rate"),
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
        .onChange(of: payViewModel.purchaseCompleted) { completed in
            if completed {
                fetchUserCoins()
                payViewModel.purchaseCompleted = false
            }
        }
    }
    
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
    // ✅ REMOVED: vote() function - no longer needed
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
    private func fetchUserCoins() {
        guard let currentUser = Auth.auth().currentUser else {
            print("No authenticated user found")
            isLoadingCoins = false
            return
        }
        
        let db = Firestore.firestore()
        
        // Fetch coins from the member document in the competition
        db.collection("competitions").document(competition.id).collection("members").document(currentUser.uid).getDocument { document, error in
            DispatchQueue.main.async {
                isLoadingCoins = false
                
                if let error = error {
                    print("Error fetching member coins: \(error.localizedDescription)")
                    return
                }
                
                guard let document = document, document.exists else {
                    print("Member document does not exist")
                    return
                }
                
                if let coins = document.data()?["coins"] as? Int {
                    self.userCoins = coins
                } else {
                    print("Coins field not found or invalid type, defaulting to 0")
                    self.userCoins = 0
                }
            }
        }
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
                    .background(Color(hex: "#4169E1"))
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
    var onMeTapped: () -> Void
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
