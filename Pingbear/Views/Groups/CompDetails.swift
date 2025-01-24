import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import PostHog
import AVFoundation

struct CompDetails: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var goToMyComps = false
    @State private var isCameraPresented = false
    @State private var isMembersPresented = false
    @State private var isMyPostsPresented = false
    @State private var isVotingPresented = false
    @State private var isEditingCompetition = false
    @State private var currentUserId: String = Auth.auth().currentUser?.uid ?? ""
    @State private var isLoading = true
    @State private var showPermissionAlert = false
    @State private var showingJoinSelectView = false
    
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
                            .foregroundColor(Color.black) // Your desired color
                    }
                    
                    Spacer() // This spacer will ensure the two buttons are at opposite ends.
                    
                    // Just make the Text view into a Button
                    Button(action: {
                        isEditingCompetition = true
                    }) {
                        Text(competition.description)
                            .font(.system(size: 17, weight: .bold, design: .default))
                            .lineLimit(1)
                            .foregroundColor(.black)
                            .padding(.horizontal)
                            .onAppear {
                                PostHogSDK.shared.capture("Comp Details View Opened")
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
                            .frame(width: 30, height: 30) // Adjust the width and height to decrease the size
                            .foregroundColor(Color.black) // Your desired color
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
                            .foregroundColor(Color(hex: "#000"))
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
                            .background(entryViewModel.hasEntriesToVoteOn ? Color(hex: "#1199FF") : Color(hex: "#D3D3D3"))
                            .foregroundColor(Color.white)
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
                            .foregroundColor(Color(hex: "#000"))
                            .clipShape(Circle())
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 10)
                .background(Color(hex: "#F5F5F5"))
                .cornerRadius(5)
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
                
                if isLoading {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    if entryViewModel.userLeaderboard.isEmpty {
                        EmptyLeaderboardView(action: initiateVideoCapture)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 15) {
                                ForEach(entryViewModel.userLeaderboard) { userEntry in
                                    leaderboardRowView(userEntry.userName, userEntry.totalStars)
                                }
                                
                                if entryViewModel.totalMemberCount == 1 {
                                    dummyFriendRow()
                                    dummyFriendRow()
                                } else if entryViewModel.totalMemberCount == 2 {
                                    dummyFriendRow()
                                }
                            }
                        }
                        .refreshable {
                            entryViewModel.fetchEntries(mode: .compDetailsView)  // Refresh the entries based on current mode
                            entryViewModel.fetchMemberCount()
                        }
                    }
                }
                
            }
        }
        .onAppear {
            fetchData()
        }
        .fullScreenCover(isPresented: $isCameraPresented, content: {
            CameraView(competition: competition)
        })
        .fullScreenCover(isPresented: $isVotingPresented, content: {
            EntryView(competitionId: competition.id, competition: competition)
        })
        .fullScreenCover(isPresented: $goToMyComps) {
            ContentView()
        }
        .fullScreenCover(isPresented: $isMembersPresented) {
            MembersView(competition: competition) // Replace this with the actual view you want to present
        }
        .fullScreenCover(isPresented: $isMyPostsPresented) {
            MyPostsView(competition: competition)
        }
        .fullScreenCover(isPresented: $showingJoinSelectView) {
            JoinSelectView(competition: competition, viewModel: MyFriendsModel(), viewModel2: AddFriendsModel())
        }
        .sheet(isPresented: $isEditingCompetition) {
            EditCompetitionView(competition: competition)
        }
        .onDisappear {
            entryViewModel.removeListeners()
        }
        .alert(isPresented: $showPermissionAlert) {
            Alert(
                title: Text("Camera Required"),
                message: Text("Camera access is required to take photos. Please enable it in Settings."),
                primaryButton: .default(Text("Open Settings"), action: openSettings),
                secondaryButton: .cancel()
            )
        }
    }
    
    private func fetchData() {
        isLoading = true
        
        entryViewModel.fetchEntries(mode: .compDetailsView) {
            entryViewModel.fetchMemberCount()
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }

    func leaderboardRowView(_ userName: String, _ stars: Int) -> some View {
        HStack {
            Text(userName)
                .font(.system(size: 16, weight: .bold))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, 10)
                .foregroundColor(userName == "Me" ? Color(hex: "#DAA520") : Color.black)  // Change text color if it's the current user

            Spacer()

            HStack(spacing: 8) {
                Text("\(stars)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color.white)
                
                Image(systemName: "star.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundColor(Color.white)
            }
            .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
            .background(Color(hex: "#DAA520"))
            .cornerRadius(200)
            .padding(.trailing, 10)
        }
        .padding(20)
        .background(Color(hex: "#F5F5F5"))
        .cornerRadius(5)
        .padding(.horizontal, 20)
    }
    
    private func dummyFriendRow() -> some View {
        HStack {
            HStack(spacing: 8) {
                Text("Add Friend")
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(Color.black.opacity(0.25))  // Black with 50% opacity
                    .padding(.leading, 10)
                
                Image(systemName: "plus.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17, height: 17)
                    .foregroundColor(Color.black.opacity(0.25))
            }

            Spacer()

            HStack(spacing: 8) {
                Text("0")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color.white)
                
                Image(systemName: "star.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundColor(Color.white)
            }
            .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
            .background(Color(hex: "#D3D3D3"))
            .cornerRadius(200)
            .padding(.trailing, 10)
        }
        .padding(20)
        .background(Color(hex: "#F5F5F5"))
        .cornerRadius(5)
        .padding(.horizontal, 20)
        .onTapGesture {
            entryViewModel.removeListeners()
            showingJoinSelectView = true
            PostHogSDK.shared.capture("Tapped Add Friend From Leaderboard Prompt")
        }
    }
    
    
    func initiateVideoCapture() {
        entryViewModel.removeListeners()
        checkCameraAndMicrophonePermissions { granted in
            if granted {
                PostHogSDK.shared.capture("Add Photo Initiated")
                joincomp()
            } else {
                showPermissionAlert = true
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
}

struct EmptyLeaderboardView: View {
    var action: () -> Void
    
    var body: some View {
        VStack {
            
            Text("No Activity Yet")
                .font(.system(size: 21, weight: .bold, design: .default))
                .foregroundColor(.black) // Set the text color as needed
                .padding(.top, 20)
                .padding(.bottom, 20)
            
            Text("Get the competition started")
                .font(.system(size: 17, weight: .bold, design: .default))
                .foregroundColor(.gray) // Set the text color as needed
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .padding(.bottom, 25)
            
            Button(action: action) {  // This button now uses the passed function
                Text("New Photo")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .background(Color(hex: "#1199FF"))
                    .foregroundColor(Color(hex: "#fff"))
                    .cornerRadius(200)
            }
            .padding(.bottom, 20)
            
 
        }
        .padding(20)
        .background(Color(hex: "#F5F5F5"))
        .cornerRadius(5)
        .padding(.horizontal, 20)
    }
}
