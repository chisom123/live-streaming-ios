import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Kingfisher
import NotificationBannerSwift

struct FullScreenPhotoView: View {
    let photo: UserPhoto
    let userName: String
    let competitionId: String?
    let userProfilePictureUrl: String?
    @Environment(\.dismiss) private var dismiss
    
    // Rating state
    @State private var rating: Int = 0
    @State private var isRatingEnabled: Bool = true
    @State private var hasAlreadyVoted: Bool = false
    @State private var animateRating: Bool = false
    @State private var currentStarCount: Int
    
    @State private var isEntryCreator = false
    
    // Parlay state
    @State private var parlayStatus: String? = nil
    @State private var parlayPredictions: [String: Any] = [:]
    @State private var parlayPayout: Int = 0
    @State private var parlayStake: Int = 0
    @State private var isLoadingParlayStatus = false
    @State private var pendingUsernamesCache: [String: String] = [:]
    @State private var pendingUserProfiles: [String: (username: String, profilePictureUrl: String?)] = [:]
    
    @State private var showingPredictionsView = false
    
    // Interaction service
    @StateObject private var interactionService = PhotoInteractionService()
    
    // Message state
    @State private var showingMessageComposer = false
    
    // Chat ViewModel for sending messages
    @StateObject private var chatViewModel: ChatViewModel
    
    let onDismiss: ((Int) -> Void)?
    
    init(photo: UserPhoto, userName: String, competitionId: String?, userProfilePictureUrl: String? = nil, onDismiss: ((Int) -> Void)? = nil) {
        self.photo = photo
        self.userName = userName
        self.competitionId = competitionId
        self.userProfilePictureUrl = userProfilePictureUrl
        self.onDismiss = onDismiss
        self._currentStarCount = State(initialValue: photo.stars)
        self._chatViewModel = StateObject(wrappedValue: ChatViewModel(competitionId: competitionId ?? ""))
    }
    
    private let db = Firestore.firestore()
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let screenWidth = geometry.size.width
                
                // Photo with text overlay using shared component
                PhotoMainImageView(
                    photoUrl: photo.photoUrl,
                    overlayText: photo.overlayText,
                    overlayVerticalPosition: photo.overlayVerticalPosition,
                    isTransitioning: false, // No transitions in FullScreenPhotoView
                    slideDirection: .left,   // Not used but required
                    screenWidth: screenWidth
                )
            }
            
            // TOP NAVIGATION using shared component
            VStack {
                PhotoNavigationBar(
                    onBack: {
                        onDismiss?(currentStarCount)
                        dismiss()
                    },
                    userName: userName,
                    userProfilePictureUrl: userProfilePictureUrl,
                    themeName: photo.themeName,
                    themeId: photo.themeId,
                    competitionId: competitionId ?? "",
                    onMessage: {
                        showingMessageComposer = true
                    }
                )
                
                Spacer()
            }
            
            UltraSmoothBottomSheet(
                minHeight: PhotoViewConstants.minHeight,
                midHeight: PhotoViewConstants.midHeight(withFooter: true),
                maxHeight: PhotoViewConstants.maxHeight(withFooter: true),
                bottomPadding: PhotoViewConstants.starFooterHeight
            ) {
                VStack(spacing: 0) {
                    // Centered handle
                    VStack {
                        RoundedRectangle(cornerRadius: 200)
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 40, height: 5)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical)
                    
                    HStack {
                        Text("Ratings (\(interactionService.interactions.count))")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 15, weight: .bold))
                            .padding(.bottom, 10)
                        
                        Spacer()
                        
                        // Predictions Button (Only for entry creator)
                        if isEntryCreator && parlayStatus != nil {
                            Button(action: {
                                showingPredictionsView = true
                                Analytics.shared.track(event: "my_predictions_button_tapped")
                            }) {
                                HStack(spacing: 8) {
                                    Text("My Predictions")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    parlayStatusBadge
                                }
                            }
                            .padding(.bottom, 10)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Content
                    if interactionService.isLoadingInteractions {
                        EmptyView()
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(interactionService.interactions) { interaction in
                                    VStack(spacing: 0) {
                                        HStack {
                                            ProfilePictureView(url: interaction.profilePictureUrl, size: 40)
                                            
                                            Text(interaction.userName)
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                                .padding(.leading, 10)
                                            
                                            Spacer()
                                            
                                            HStack(spacing: 6) {
                                                Text("\(interaction.rating)")
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Image(systemName: "star.fill")
                                                    .resizable()
                                                    .frame(width: 16, height: 16)
                                                    .foregroundColor(.white)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color(hex: "#DAA520"))
                                            .cornerRadius(20)
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 15)
                                        
                                        if interaction.id != interactionService.interactions.last?.id {
                                            Divider()
                                                .background(Color.white.opacity(0.2))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
            
            PhotoStarRatingFooter(
                rating: $rating,
                hasAlreadyVoted: hasAlreadyVoted || userName == "Me",
                isRatingEnabled: isRatingEnabled && userName != "Me",
                animateRating: animateRating,
                onRatingSubmit: { stars in
                    submitRating(stars: stars)
                },
                height: PhotoViewConstants.starFooterHeight
            )
            
        }
        .background(Color(hex: "#10183C"))
        .onAppear {
            checkVotingStatus()
            
            // Check if current user is the entry creator
            if let currentUserId = Auth.auth().currentUser?.uid {
                isEntryCreator = (photo.userId == currentUserId)
            }
            
            if let competitionId = competitionId {
                interactionService.loadRatingData(
                    competitionId: competitionId,
                    entryId: photo.id
                )
                
                interactionService.fetchInteractions(
                    competitionId: competitionId,
                    entryId: photo.id
                )
            }
            
            // Load parlay status if user is entry creator
            if isEntryCreator {
                loadParlayStatus()
            }
            
            Analytics.shared.trackScreen(
                name: "fullscreen_photo",
                properties: [
                    "user_name": userName,
                    "can_rate": userName != "Me" && competitionId != nil
                ]
            )
        }
        .sheet(isPresented: $showingMessageComposer) {
            MessageComposerView(
                photo: photo,
                userName: userName,
                competitionId: competitionId ?? "",
                onSend: { message in
                    sendPhotoMessage(text: message)
                }
            )
        }
        .sheet(isPresented: $showingPredictionsView) {
            PredictionsDetailView(
                parlayStatus: parlayStatus ?? "",
                parlayPredictions: parlayPredictions,
                parlayPayout: parlayPayout,
                parlayStake: parlayStake,
                pendingUserProfiles: pendingUserProfiles,
                interactionService: interactionService,
                onDismiss: { showingPredictionsView = false }
            )
        }
    }
    
    // MARK: - Parlay Status Views
    
    private var parlayStatusView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("My Predictions")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                parlayStatusBadge
            }
            
            if parlayStatus == "pending" {
                parlayProgressView
            } else if parlayStatus == "won" {
                parlayWonView
            } else if parlayStatus == "lost" {
                parlayLostView
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
    
    private var parlayStatusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(parlayStatusColor)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(parlayStatusColor.opacity(0.15))
        .cornerRadius(200)
    }
    
    private var parlayStatusColor: Color {
        switch parlayStatus {
        case "won": return Color(hex: "#00FF00")
        case "lost": return Color(hex: "#FF4444")
        default: return Color(hex: "#FFD700")
        }
    }
    
    private var parlayStatusText: String {
        switch parlayStatus {
        case "won": return "Win"
        case "lost": return "Lost"
        default: return "In Progress"
        }
    }
    
    private var parlayProgressView: some View {
        VStack(spacing: 8) {
            VStack(spacing: 8) {
                let totalPredictions = parlayPredictions.count
                let completedPredictions = parlayPredictions.values.compactMap { predictionData in
                    (predictionData as? [String: Any])?["actualRating"]
                }.count
                
                HStack {
                    Text("Correct")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    let (correct, total) = getCorrectPredictionsCount()
                    Text("\(correct)/\(total)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                HStack {
                    Text("Entry")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("\(parlayStake)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image("coin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 19, height: 19)
                    }
                }
                
                HStack {
                    Text("To Win")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("\(parlayPayout)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image("coin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 19, height: 19)
                    }
                }
                
                let profit = parlayPayout - parlayStake
                HStack {
                    Text("Profit")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Text("+\(profit)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#00FF00"))
                }
            }
            
            predictionsList
        }
    }
    
    private var parlayWonView: some View {
        VStack(spacing: 8) {
            VStack(spacing: 8) {
                HStack {
                    Text("Correct")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    let (correct, total) = getCorrectPredictionsCount()
                    Text("\(correct)/\(total)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                HStack {
                    Text("Entry")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("\(parlayStake)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image("coin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 19, height: 19)
                    }
                }
                
                HStack {
                    Text("Win")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("\(parlayPayout)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image("coin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 19, height: 19)
                    }
                }
                
                let profit = parlayPayout - parlayStake
                HStack {
                    Text("Profit")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Text("+\(profit)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#00FF00"))
                }
            }
            
            predictionsList
        }
    }
    
    private var parlayLostView: some View {
        VStack(spacing: 8) {
            // Parlay summary
            VStack(spacing: 8) {
                HStack {
                    Text("Correct")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    let (correct, total) = getCorrectPredictionsCount()
                    Text("\(correct)/\(total)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                HStack {
                    Text("Entry")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("\(parlayStake)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image("coin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 19, height: 19)
                    }
                }
                
                HStack {
                    Text("Win")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("0")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image("coin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 19, height: 19)
                    }
                }
            }
            
            predictionsList
        }
    }
    
    private var predictionsList: some View {
        VStack(spacing: 0) {
            if !parlayPredictions.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.2))
                    .padding(.vertical, 8)
                
                VStack(spacing: 0) {
                    ForEach(Array(parlayPredictions.keys.sorted()), id: \.self) { userId in
                        predictionRow(for: userId)
                        
                        if userId != Array(parlayPredictions.keys.sorted()).last {
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.leading, 50)
                        }
                    }
                }
            }
        }
    }
    
    private func predictionRow(for userId: String) -> some View {
        guard let predictionData = parlayPredictions[userId] as? [String: Any],
              let predictedRating = predictionData["predictedRating"] as? Int else {
            return AnyView(EmptyView())
        }
        
        let actualRating = predictionData["actualRating"] as? Int
        let isCorrect = predictionData["correct"] as? Bool ?? false
        
        // Get user info - try interaction first, then pending cache, then fetch
        let interaction = interactionService.interactions.first { $0.userId == userId }
        let userName: String
        let profilePictureUrl: String?
        
        if let interaction = interaction {
            // User has rated - use interaction data
            userName = interaction.userName
            profilePictureUrl = interaction.profilePictureUrl
        } else if let cachedProfile = pendingUserProfiles[userId] {
            // User hasn't rated but we have cached profile
            userName = cachedProfile.username
            profilePictureUrl = cachedProfile.profilePictureUrl
        } else {
            // Need to fetch user profile
            userName = "Friend"
            profilePictureUrl = nil
            fetchUserProfileForPendingUser(userId: userId)
        }
        
        return AnyView(
            HStack(spacing: 12) {
                // Profile Picture
                ProfilePictureView(url: profilePictureUrl, size: 35)
                
                // User Info
                VStack(alignment: .leading, spacing: 5) {
                    Text(userName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    // Visual comparison of predicted vs actual
                    if let actualRating = actualRating {
                        HStack(alignment: .center, spacing: 0) {
                           // Main tab
                           HStack(spacing: 3) {
                               Image(systemName: "star.fill")
                                   .font(.system(size: 11))
                                   .foregroundColor(.white)
                               
                               Text("\(predictedRating)")
                                   .font(.system(size: 13, weight: .bold))
                                   .foregroundColor(.white)
                           }
                           .frame(height: 28) // Same fixed height
                           .padding(.horizontal, 8)
                           .background(
                            (isCorrect ? Color(hex: "#00FF00").opacity(0.6) : Color(hex: "#FF4444"))
                                   .clipShape(
                                       RoundedCorner(
                                           radius: 6,
                                           corners: isCorrect ? [.topLeft, .bottomLeft, .topRight, .bottomRight] : [.topLeft, .bottomLeft]
                                       )
                                   )
                           )
                           
                           // Connected side tab (only show if incorrect)
                           if !isCorrect {
                               HStack(spacing: 4) {
                                   Text("\(actualRating)")
                                       .font(.system(size: 13, weight: .bold)) // Same size as main
                                       .foregroundColor(.white.opacity(0.8))
                               }
                               .frame(height: 28) // Same fixed height
                               .padding(.horizontal, 8)
                               .background(
                                    Color.gray.opacity(0.6) // Dark grey/black background
                                       .clipShape(
                                           RoundedCorner(
                                               radius: 6,
                                               corners: [.topRight, .bottomRight]
                                           )
                                       )
                               )
                           }
                        }
                    } else {
                        HStack(spacing: 3) {
                           Image(systemName: "star.fill")
                               .font(.system(size: 11))
                               .foregroundColor(.white)
                           
                           Text("\(predictedRating)")
                               .font(.system(size: 13, weight: .bold))
                               .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(height: 28)
                        .padding(.horizontal, 8)
                        .background(
                            Color.gray.opacity(0.6)
                               .clipShape(
                                   RoundedCorner(
                                       radius: 6,
                                       corners: [.topLeft, .bottomLeft, .topRight, .bottomRight]
                                   )
                               )
                           )
                    }
                }
                
                Spacer()
                
                // Status indicator with icon
                if actualRating != nil {
                    Text(isCorrect ? "✓" : "✗")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isCorrect ? Color(hex: "#00FF00") : Color(hex: "#FF4444"))
                } else {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#FFD700"))
                }
            }
            .padding(.vertical, 8)
        )
    }
    
    // MARK: - Parlay Helper Methods
    
    private func isPredictedUser(userId: String) -> Bool {
        return parlayPredictions[userId] != nil
    }
    
    private func predictionIndicator(for userId: String, actualRating: Int) -> some View {
        guard let predictionData = parlayPredictions[userId] as? [String: Any],
              let predictedRating = predictionData["predictedRating"] as? Int else {
            return AnyView(EmptyView())
        }
        
        let isCorrect = actualRating == predictedRating
        let hasActualRating = predictionData["actualRating"] != nil
        
        if hasActualRating {
            return AnyView(
                HStack(spacing: 6) {
                    Text("\(predictedRating)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Image(systemName: "star.fill")
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isCorrect ? Color(hex: "#00FF00").opacity(0.5) : Color(hex: "#FF4444"))
                .cornerRadius(20)
            )
        } else {
            return AnyView(
                HStack(spacing: 6) {
                    Text("\(predictedRating)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Image(systemName: "star.fill")
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isCorrect ? Color(hex: "#00FF00").opacity(0.5) : Color(hex: "#FF4444"))
                .cornerRadius(20)
            )
        }
    }
    
    private func getPendingUsers() -> [String] {
        var pendingUsernames: [String] = []
        
        for (userId, predictionData) in parlayPredictions {
            if let prediction = predictionData as? [String: Any],
               prediction["actualRating"] == nil {
                
                // Try to find username from interactions first (most reliable)
                if let interaction = interactionService.interactions.first(where: { $0.userId == userId }) {
                    pendingUsernames.append(interaction.userName)
                }
                // Check if we have cached username in pendingUsernames state
                else if let cachedUsername = pendingUsernamesCache[userId] {
                    pendingUsernames.append(cachedUsername)
                }
                // Fallback to "Friend" if username not found
                else {
                    pendingUsernames.append("Friend")
                    // Fetch username asynchronously and cache it
                    fetchUsernameForPendingUser(userId: userId)
                }
            }
        }
        
        return pendingUsernames
    }
    
    private func fetchUsernameForPendingUser(userId: String) {
        // Don't fetch if already cached or currently fetching
        guard pendingUsernamesCache[userId] == nil else { return }
        
        db.collection("users").document(userId).getDocument { document, error in
            if let data = document?.data(),
               let username = data["username"] as? String {
                DispatchQueue.main.async {
                    self.pendingUsernamesCache[userId] = username
                }
            }
        }
    }
    
    private func fetchUserProfileForPendingUser(userId: String) {
        // Don't fetch if already cached
        guard pendingUserProfiles[userId] == nil else { return }
        
        db.collection("users").document(userId).getDocument { document, error in
            if let data = document?.data(),
               let username = data["username"] as? String {
                let profilePictureUrl = data["profilePictureUrl"] as? String
                DispatchQueue.main.async {
                    self.pendingUserProfiles[userId] = (username: username, profilePictureUrl: profilePictureUrl)
                }
            }
        }
    }
    
    private func getCorrectPredictionsCount() -> (correct: Int, total: Int) {
        var correctCount = 0
        let totalCount = parlayPredictions.count
        
        for (_, predictionData) in parlayPredictions {
            if let prediction = predictionData as? [String: Any],
               let isCorrect = prediction["correct"] as? Bool,
               isCorrect {
                correctCount += 1
            }
        }
        
        return (correctCount, totalCount)
    }
    
    private func loadParlayStatus() {
        guard let competitionId = competitionId else { return }
        
        isLoadingParlayStatus = true
        
        let entryRef = db.collection("competitions").document(competitionId).collection("entries").document(photo.id)
        
        entryRef.getDocument { document, error in
            DispatchQueue.main.async {
                self.isLoadingParlayStatus = false
                
                if let error = error {
                    print("Error loading parlay status: \(error)")
                    return
                }
                
                guard let data = document?.data() else { return }
                
                self.parlayStatus = data["parlayStatus"] as? String
                self.parlayPredictions = data["predictions"] as? [String: Any] ?? [:]
                self.parlayPayout = data["potentialPayout"] as? Int ?? 0
                self.parlayStake = data["entryCost"] as? Int ?? 0
                
                for userId in self.parlayPredictions.keys {
                    if !self.interactionService.interactions.contains(where: { $0.userId == userId }) {
                        self.fetchUserProfileForPendingUser(userId: userId)
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func sendPhotoMessage(text: String) {
        chatViewModel.sendPhotoMessage(photo: photo, text: text)
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        if let userId = Auth.auth().currentUser?.uid, let competitionId = competitionId {
            // Fetch both competition description and sender's username
            let competitionRef = db.collection("competitions").document(competitionId)
            let userRef = db.collection("users").document(userId)
            
            let group = DispatchGroup()
            var competitionDescription = "Game"
            var username = "Someone"
            
            group.enter()
            competitionRef.getDocument { compDoc, _ in
                competitionDescription = compDoc?.data()?["description"] as? String ?? "Game"
                group.leave()
            }
            
            group.enter()
            userRef.getDocument { userDoc, _ in
                username = userDoc?.data()?["username"] as? String ?? "Someone"
                group.leave()
            }
            
            group.notify(queue: .main) {
                NotificationQueueManager.shared.queueGroupNotification(
                    competitionId: competitionId,
                    title: competitionDescription,
                    body: "\(username) sent a message",
                    senderId: userId,
                    excludeUsers: [userId]
                )
                NotificationQueueManager.shared.processQueuedNotifications()
            }
        }
        
        Analytics.shared.trackTap(
            elementId: "message_send_btn_tapped",
            screenName: "fullscreen_photo_view"
        )
    }
    
    private func checkVotingStatus() {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              let competitionId = competitionId,
              userName != "Me" else {
            return
        }
        
        let voteRef = db.collection("groupMemberships")
            .document(currentUserId)
            .collection("competitions")
            .document(competitionId)
            .collection("votes")
            .document(photo.id)
        
        voteRef.getDocument { document, error in
            if let error = error {
                print("Error checking vote status: \(error)")
                return
            }
            
            DispatchQueue.main.async {
                self.hasAlreadyVoted = document?.exists ?? false
                self.isRatingEnabled = !self.hasAlreadyVoted
            }
        }
    }
    
    private func submitRating(stars: Int) {
        guard let competitionId = competitionId,
              let currentUserId = Auth.auth().currentUser?.uid,
              !hasAlreadyVoted,
              isRatingEnabled else {
            return
        }
        
        isRatingEnabled = false
        rating = stars
        
        animateRating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.animateRating = false
        }
        
        Analytics.shared.trackEntry(
            action: "rate",
            entryId: photo.id,
            competitionId: competitionId,
            properties: ["rating": stars, "location": "fullscreen_view"]
        )
        
        triggerHapticFeedback(for: stars)
        
        // Use ParlayManager to handle the rating
        ParlayManager.shared.handleRating(
            competitionId: competitionId,
            entryId: photo.id,
            userId: currentUserId,
            rating: stars
        ) { success in
            DispatchQueue.main.async {
                if success {
                    print("Rating processed successfully by ParlayManager")
                    
                    // Update local star count
                    self.currentStarCount += stars
                    
                    // Reload parlay status if user is entry creator
                    if self.isEntryCreator {
                        self.loadParlayStatus()
                    }
                    
                    // Submit to interaction service
                    self.interactionService.submitRating(
                        competitionId: competitionId,
                        entryId: self.photo.id,
                        rating: stars
                    ) { interactionSuccess in
                        if interactionSuccess {
                            print("Rating submitted successfully to interaction service")
                            
                            // Refresh the interactions to show the new rating at the top
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.interactionService.fetchInteractions(
                                    competitionId: competitionId,
                                    entryId: self.photo.id
                                )
                            }
                        }
                    }
                } else {
                    print("Failed to process rating with ParlayManager")
                    // Re-enable rating on failure
                    self.isRatingEnabled = true
                    self.rating = 0
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            self.hasAlreadyVoted = true
        }
    }
    
    private func triggerHapticFeedback(for star: Int) {
        let intensity = Float(star) / 5.0
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred(intensity: CGFloat(intensity))
        
        let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            heavyGenerator.impactOccurred()
        }
    }
}
