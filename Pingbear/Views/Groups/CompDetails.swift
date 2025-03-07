import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import PostHog
import AVFoundation

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
    @State private var isMyPostsPresented = false
    @State private var isVotingPresented = false
    @State private var isEditingCompetition = false
    @State private var currentUserId: String = Auth.auth().currentUser?.uid ?? ""
    @State private var isLoading = true
    @State private var showingJoinSelectView = false
    @StateObject private var notificationManager = PushNotificationManager.shared
    @State private var activeAlert: AlertType?
    
    @ObservedObject var entryViewModel: EntryViewModel

    @ObservedObject var competition: Competition
    
    private let db = Firestore.firestore()

    init(competition: Competition) {
        self.competition = competition
        self.entryViewModel = EntryViewModel(competitionId: competition.id, mode: .compDetailsView)
    }

    
    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                HStack {
                    Button(action: {
                        entryViewModel.removeListeners()
                        goToMyComps = true
                        PostHogSDK.shared.capture("Close Competition Details")
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable() // Allows resizing of the image
                            .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                            .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                            .foregroundColor(Color.white) // Your desired color
                    }
                    
                    Spacer() // This spacer will ensure the two buttons are at opposite ends.
                    
                    // Just make the Text view into a Button
                    Button(action: {
                        isEditingCompetition = true
                    }) {
                        Text(competition.description)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .lineLimit(1)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                            .onAppear {
                                PostHogSDK.shared.capture("Comp Details View Opened", properties: [
                                    "competition_id": competition.id
                                ])
                            }
                    }
                    
                    Spacer()
                    
                    // Step 2: Share Button
                    Button(action: {
                        entryViewModel.removeListeners()
                        isMembersPresented = true
                        PostHogSDK.shared.capture("View Competition Competitors")
                    }) {
                        Image(systemName: "ellipsis")
                            .resizable() // Allows resizing of the image
                            .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                            .frame(width: 32, height: 32) // Adjust the width and height to decrease the size
                            .foregroundColor(Color.white) // Your desired color
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                HStack(spacing: 10) { // Add an HStack with some spacing between the buttons
                    // Button positioned at the bottom right
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
                        entryViewModel.removeListeners()
                        vote()
                        PostHogSDK.shared.capture("Rating Initiated")
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
                        isMyPostsPresented = true
                    }) {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 24, weight: .bold))
                            .frame(width: 45, height: 45)
                            .padding(6)
                            .foregroundColor(.white)
                            .clipShape(Circle())
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
                        NoPlayersView(action_player: addPlayer)
                    } else {
                        if entryViewModel.userLeaderboard.isEmpty {
                            EmptyLeaderboardView(action: initiateVideoCapture)
                            Spacer()
                        } else {
                            ScrollView {
                                VStack(spacing: 0) {
                                    // Update the ForEach loop section to include index
                                    ForEach(Array(entryViewModel.userLeaderboard.enumerated()), id: \.element.id) { index, userEntry in
                                        VStack(spacing: 0) {
                                            HStack {
                                                // Position number
                                                Text("\(index + 1)")
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .frame(width: 30)
                                                    .padding(.leading, 20)
                                                
                                                // Profile picture and username group
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
        }
        .fullScreenCover(isPresented: $isCameraPresented, content: {
            CameraView(competition: competition)
        })
        .fullScreenCover(isPresented: $isVotingPresented, content: {
            EntryView(competitionId: competition.id, competition: competition)
        })
        .fullScreenCover(isPresented: $goToMyComps) {
            MyCompsView()
        }
        .fullScreenCover(isPresented: $isMembersPresented) {
            MembersView(competition: competition) // Replace this with the actual view you want to present
        }
        .fullScreenCover(isPresented: $isMyPostsPresented) {
            MyPostsView(competition: competition)
        }
        .fullScreenCover(isPresented: $showingJoinSelectView) {
            JoinSelectView(competition: competition, viewModel: MyFriendsModel())
        }
        .sheet(isPresented: $isEditingCompetition) {
            EditCompetitionView(competition: competition)
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
                    title: Text("Turn On Notifications"),
                    message: Text("Don't miss out when new photos are shared and ready to be rated."),
                    dismissButton: .default(Text("OK"), action: {
                        notificationManager.requestNotificationPermission { _ in
                            print("Permission request completed")
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
                PostHogSDK.shared.capture("Add Photo Initiated")
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
        PostHogSDK.shared.capture("Tapped Add Player From Prompt")
    }
}

struct EmptyLeaderboardView: View {
    var action: () -> Void
    
    var body: some View {
        VStack {
            Text("No Activity Yet")
                .font(.system(size: 21, weight: .bold, design: .default))
                .foregroundColor(.white) // Changed to white for better contrast
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
        .background(Color(hex: "#1A2245")) // Slightly lighter than background for contrast
        .cornerRadius(10) // Increased corner radius for a softer look
        .padding(.horizontal, 20)
    }
}

struct NoPlayersView: View {
    var action_player: () -> Void
    @State private var currentUserProfileUrl: String?
    private let db = Firestore.firestore()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(["Me", "Player 2", "Player 3"].enumerated()), id: \.element) { index, userName in
                    VStack(spacing: 0) {
                        HStack {
                            // Position number
                            Text("\(index + 1)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 30)
                                .padding(.leading, 20)
                            
                            // Profile picture and username group
                            HStack(spacing: 20) {
                                // Use fetched profile picture URL for "Me", nil for others
                                ProfilePictureView(url: userName == "Me" ? currentUserProfileUrl : nil, size: 40)
                                
                                Text(userName)
                                    .font(.system(size: 16, weight: .bold))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .foregroundColor(.white)
                            }

                            Spacer()

                            if userName == "Me" {
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
                            } else {
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
                        }
                        .padding(.vertical, 25)
                        .background(userName == "Me" ? Color(hex: "#2A3255") : Color.clear)
                        
                        if userName != "Player 3" {
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
