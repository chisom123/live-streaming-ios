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
    @State private var currentUserId: String = Auth.auth().currentUser?.uid ?? ""
    @State private var isLoading = true
    @State private var showPermissionAlert = false
    
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
                    
                    Text(competition.description)
                        .font(.system(size: 17, weight: .bold, design: .default))
                        .lineLimit(1)
                        .foregroundColor(.black)
                        .padding(.horizontal)
                        .onAppear {
                            PostHogSDK.shared.capture("Comp Details View Opened")
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
                            .foregroundColor(isEventEnabled() ? Color(hex: "#000") : Color(hex: "#A9A9A9"))
                            .clipShape(Circle())
                    }
                    .disabled(!isEventEnabled())
                    
                    Button(action: {
                        entryViewModel.removeListeners()
                        vote()
                        PostHogSDK.shared.capture("Rating Initiated")
                    }) {
                        Text("Start Rating")
                            .frame(maxWidth: .infinity, minHeight: 45)
                            .font(.system(size: 20, weight: .bold, design: .default))
                            .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .background((entryViewModel.hasEntriesToVoteOn && isEventEnabled()) ? Color(hex: "#1199FF") : Color(hex: "#D3D3D3"))
                            .foregroundColor(Color.white)
                            .cornerRadius(200)
                    }
                    .disabled(!(entryViewModel.hasEntriesToVoteOn && isEventEnabled()))
                    
                    Button(action: {
                        entryViewModel.removeListeners()
                        isMyPostsPresented = true
                    }) {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 24, weight: .bold))
                            .frame(width: 45, height: 45)
                            .padding(6)
                            .foregroundColor(isEventEnabled() ? Color(hex: "#000") : Color(hex: "#A9A9A9"))
                            .clipShape(Circle())
                    }
                    .disabled(!isEventEnabled())
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
                    if competition.hasEnded {
                        EventEndedNoticeView()
                    }
                    
                    if competition.isEvent && !competition.hasStarted {
                        if let event = competition as? Event {
                            EventNotStartedView(event: event)
                            Spacer()
                        }
                    } else if entryViewModel.userLeaderboard.isEmpty && !competition.hasEnded {
                        EmptyLeaderboardView(action: initiateVideoCapture)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 15) {
                                ForEach(entryViewModel.userLeaderboard) { userEntry in
                                    leaderboardRowView(userEntry.userName, userEntry.totalStars)
                                }
                            }
                        }
                        .refreshable {
                            entryViewModel.fetchEntries(mode: .compDetailsView)  // Refresh the entries based on current mode
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
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    private func isEventEnabled() -> Bool {
        return !competition.isEvent || (competition.hasStarted && !competition.hasEnded)
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
            
            Text("No Photos Yet")
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

struct EventNotStartedView: View {
    let event: Event
    @State private var isSubscribed = false
    @State private var isLoading = false
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            return "Today at \(timeFormatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            return "Tomorrow at \(timeFormatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d'\(dayOrdinal(from: date))' MMM 'at' h:mm a"
            return formatter.string(from: date)
        }
    }

    private func dayOrdinal(from date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        
        switch day {
        case 1, 21, 31: return "st"
        case 2, 22: return "nd"
        case 3, 23: return "rd"
        default: return "th"
        }
    }
    
    private func subscribeToNotifications() {
        isLoading = true
        
        Task {
            let scheduled = await NotificationService.shared.scheduleEventNotifications(event: event)
            
            DispatchQueue.main.async {
                isSubscribed = scheduled
                isLoading = false
                
                if scheduled {
                    PostHogSDK.shared.capture("Public Competition Notification Subscribed",
                        properties: ["eventId": event.id])
                }
            }
        }
    }
    
    var body: some View {
        VStack {
            Text("Competition Starting Soon")
                .font(.system(size: 21, weight: .bold, design: .default))
                .foregroundColor(.black)
                .padding(.top, 20)
                .padding(.bottom, 20)
            
            Text("\(formatDate(event.startDateTime))")
                .font(.system(size: 17, weight: .bold, design: .default))
                .foregroundColor(.gray) // Set the text color as needed
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .padding(.bottom, 20)
            
            Button(action: subscribeToNotifications) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else if isSubscribed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                    } else {
                        Text("Remind Me")
                            .font(.system(size: 18, weight: .bold, design: .default))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .font(.system(size: 18, weight: .bold, design: .default))
                .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .background(isSubscribed ? Color(hex: "#4CAF50") : Color(hex: "#1199FF"))
                .foregroundColor(Color(hex: "#fff"))
                .cornerRadius(200)
            }
            .disabled(isSubscribed || isLoading)
            .padding(.bottom, 20)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#F5F5F5"))
        .cornerRadius(5)
        .padding(.horizontal, 20)
    }
}

struct EventEndedNoticeView: View {
    var body: some View {
        HStack {
            Text("Competition Ended")
                .font(.system(size: 16, weight: .bold))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, 10)
                .foregroundColor(Color.black)
            
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#F5F5F5"))
        .cornerRadius(5)
        .padding(.horizontal, 20)
        .padding(.bottom, 15)
    }
}
