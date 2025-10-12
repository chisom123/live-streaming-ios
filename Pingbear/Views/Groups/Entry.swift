import SwiftUI
import Kingfisher
import FirebaseAuth
import FirebaseFirestore

enum SlideDirection {
    case left, right
}

struct EntryView: View {
    @StateObject private var viewModel: EntryViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Simple state management
    @State private var currentEntryState = EntryState()
    @State private var showingMessageComposer = false
    
    // Bonus notification state
    @State private var showBonusNotification = false
    @State private var bonusAmount = 0
    
    // Services
    @StateObject private var interactionService = PhotoInteractionService()
    @StateObject private var chatViewModel: ChatViewModel
    
    var competition: Competition
    private let db = Firestore.firestore()

    init(competitionId: String, competition: Competition) {
        _viewModel = StateObject(wrappedValue: EntryViewModel(competitionId: competitionId, mode: .entryView))
        self.competition = competition
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(competitionId: competitionId))
    }
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                if let entry = currentEntry {
                    PhotoMainImageView(
                        photoUrl: entry.photoUrl,
                        overlayText: entry.overlayText,
                        overlayVerticalPosition: entry.overlayVerticalPosition,
                        isTransitioning: currentEntryState.isTransitioning,
                        slideDirection: currentEntryState.slideDirection,
                        screenWidth: geometry.size.width
                    )
                }
            }
            
            // Navigation
            VStack {
                if let entry = currentEntry {
                    PhotoNavigationBar(
                        onBack: { dismiss() },
                        userName: entry.userName,
                        userProfilePictureUrl: entry.userProfilePictureUrl,
                        themeName: entry.themeName,
                        themeId: entry.themeId,
                        competitionId: competition.id,
                        onMessage: { showingMessageComposer = true }
                    )
                }
                Spacer()
            }
            
            // Bottom sheet
            PhotoRatingBottomSheet(
                interactions: interactionService.interactions,
                isLoading: interactionService.isLoadingInteractions || currentEntryState.isTransitioning,
                minHeight: PhotoViewConstants.minHeight,
                midHeight: PhotoViewConstants.midHeight(withFooter: true),
                maxHeight: PhotoViewConstants.maxHeight(withFooter: true),
                bottomPadding: PhotoViewConstants.starFooterHeight
            )
            
            // Rating footer
            PhotoStarRatingFooter(
                rating: $currentEntryState.rating,
                hasAlreadyVoted: currentEntryState.hasVoted,
                isRatingEnabled: currentEntryState.canRate,
                animateRating: currentEntryState.isAnimatingRating,
                onRatingSubmit: handleRatingSubmission,
                height: PhotoViewConstants.starFooterHeight
            )
            
            // Bonus notification
            if showBonusNotification {
                BonusNotificationView(
                    bonusAmount: bonusAmount,
                    isShowing: $showBonusNotification
                )
                .zIndex(1000)
            }
        }
        .background(Color(hex: "#10183C"))
        .sheet(isPresented: $showingMessageComposer) {
            if let entry = currentEntry {
                MessageComposerView(
                    photo: entry.toUserPhoto(),
                    userName: entry.userName,
                    competitionId: competition.id,
                    onSend: sendPhotoMessage
                )
            }
        }
        .onChange(of: viewModel.currentIndex) { _ in
            handleEntryChange()
        }
        .onAppear {
            setupInitialEntry()
            Analytics.shared.trackScreen(name: "entry_rating")
        }
        .onDisappear {
            cleanup()
        }
        .navigationBarHidden(true)
    }
}

// MARK: - State Management

private extension EntryView {
    
    struct EntryState {
        var rating: Int = 0
        var hasVoted: Bool = false
        var canRate: Bool = true
        var isAnimatingRating: Bool = false
        var isTransitioning: Bool = false
        var slideDirection: SlideDirection = .left
        
        mutating func reset() {
            rating = 0
            hasVoted = false
            canRate = true
            isAnimatingRating = false
        }
        
        mutating func startRatingAnimation() {
            isAnimatingRating = true
        }
        
        mutating func completeRating() {
            hasVoted = true
            canRate = false
            isAnimatingRating = false
        }
        
        mutating func startTransition() {
            isTransitioning = true
            slideDirection = .left
        }
        
        mutating func completeTransition() {
            isTransitioning = false
        }
    }
    
    var currentEntry: Entry? {
        guard viewModel.entries.indices.contains(viewModel.currentIndex) else { return nil }
        return viewModel.entries[viewModel.currentIndex]
    }
}

// MARK: - Entry Management

private extension EntryView {
    
    func setupInitialEntry() {
        guard let entry = currentEntry else {
            // Retry once if entries haven't loaded yet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if self.currentEntry != nil {
                    self.loadEntryData()
                }
            }
            return
        }
        
        loadEntryData()
        preloadImages()
    }
    
    func handleEntryChange() {
        currentEntryState.reset()
        loadEntryData()
    }
    
    func loadEntryData() {
        guard let entry = currentEntry else { return }
        
        // Load voting status and interactions
        Task {
            await loadVotingStatus(for: entry)
            loadInteractions(for: entry)
        }
    }
    
    @MainActor
    func loadVotingStatus(for entry: Entry) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let voteDoc = try await db.collection("groupMemberships")
                .document(currentUserId)
                .collection("competitions")
                .document(competition.id)
                .collection("votes")
                .document(entry.id)
                .getDocument()
            
            currentEntryState.hasVoted = voteDoc.exists
            currentEntryState.canRate = !voteDoc.exists
        } catch {
            print("Error loading voting status: \(error)")
        }
    }
    
    func loadInteractions(for entry: Entry) {
        interactionService.prepareForNewEntry()
        interactionService.loadRatingData(competitionId: competition.id, entryId: entry.id)
        interactionService.fetchInteractions(competitionId: competition.id, entryId: entry.id)
    }
    
    func preloadImages() {
        let startIndex = max(0, viewModel.currentIndex)
        let endIndex = min(viewModel.entries.count, startIndex + 3)
        
        for i in startIndex..<endIndex {
            if i != viewModel.currentIndex,
               let url = URL(string: viewModel.entries[i].photoUrl) {
                KingfisherManager.shared.retrieveImage(with: url) { _ in }
            }
        }
    }
}

// MARK: - Actions

private extension EntryView {
    
    func handleRatingSubmission(stars: Int) {
        guard let entry = currentEntry,
              let currentUserId = Auth.auth().currentUser?.uid,
              currentEntryState.canRate else { return }
        
        // Immediate UI feedback
        currentEntryState.rating = stars
        currentEntryState.startRatingAnimation()
        triggerHapticFeedback(for: stars)
        
        // Check if this user is in the predictions to calculate potential bonus
        checkForBonusEligibility(entry: entry, userId: currentUserId, rating: stars) { potentialBonus in
            // Submit rating
            ParlayManager.shared.handleRating(
                competitionId: self.competition.id,
                entryId: entry.id,
                userId: currentUserId,
                rating: stars
            ) { [self] success in
                DispatchQueue.main.async {
                    if success {
                        self.completeRatingSubmission(entry: entry, stars: stars, bonusEarned: potentialBonus)
                    } else {
                        self.handleRatingFailure()
                    }
                }
            }
        }
        
        Analytics.shared.trackEntry(
            action: "rate",
            entryId: entry.id,
            competitionId: competition.id,
            properties: ["rating": stars, "location": "entry_view"]
        )
    }
    
    func checkForBonusEligibility(entry: Entry, userId: String, rating: Int, completion: @escaping (Int) -> Void) {
        // Fetch the entry to check predictions
        db.collection("competitions").document(competition.id).collection("entries").document(entry.id)
            .getDocument { document, error in
                guard let data = document?.data(),
                      let predictions = data["predictions"] as? [String: Any],
                      let userPrediction = predictions[userId] as? [String: Any],
                      let predictedRating = userPrediction["predictedRating"] as? Int else {
                    completion(0)
                    return
                }
                
                // Check if the rating is different from prediction (user earns bonus)
                if rating != predictedRating {
                    // Calculate the bonus
                    guard let entryCost = data["entryCost"] as? Int else {
                        completion(0)
                        return
                    }
                    
                    let totalPredictions = predictions.count
                    let bonusPool = CompetitionPricingCalculator.shared.calculateBonusPool(lostStake: entryCost)
                    let bonus = CompetitionPricingCalculator.shared.calculateRaterBonus(
                        bonusPool: bonusPool,
                        totalPredictions: totalPredictions
                    )
                    
                    completion(bonus)
                } else {
                    completion(0)
                }
            }
    }
    
    func completeRatingSubmission(entry: Entry, stars: Int, bonusEarned: Int) {
        currentEntryState.completeRating()
        
        // Show bonus notification if earned
        if bonusEarned > 0 {
            bonusAmount = bonusEarned
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showBonusNotification = true
            }
        }
        
        // Submit to interaction service
        interactionService.submitRating(
            competitionId: competition.id,
            entryId: entry.id,
            rating: stars
        ) { _ in
            // Refresh interactions to show new rating
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.interactionService.fetchInteractions(
                    competitionId: self.competition.id,
                    entryId: entry.id
                )
            }
        }
        let isLastEntry = viewModel.currentIndex >= viewModel.entries.count - 1
        
        let advanceDelay: Double
        if bonusEarned > 0 && isLastEntry {
            advanceDelay = 3.8
        } else {
            advanceDelay = 0.8
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + advanceDelay) {
            self.advanceToNextEntry()
        }
    }
    
    func handleRatingFailure() {
        currentEntryState.reset()
    }
    
    func advanceToNextEntry() {
        if viewModel.currentIndex >= viewModel.entries.count - 1 {
            dismiss()
            return
        }
        
        // Smooth transition
        currentEntryState.startTransition()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.viewModel.currentIndex += 1
            self.currentEntryState.completeTransition()
        }
    }
    
    func sendPhotoMessage(text: String) {
        guard let entry = currentEntry else { return }
        
        let photo = entry.toUserPhoto()
        chatViewModel.sendPhotoMessage(photo: photo, text: text)
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Queue notification with sender's username
        if let userId = Auth.auth().currentUser?.uid {
            // Fetch sender's username
            db.collection("users").document(userId).getDocument { userDoc, _ in
                let username = userDoc?.data()?["username"] as? String ?? "Someone"
                
                NotificationQueueManager.shared.queueGroupNotification(
                    competitionId: competition.id,
                    title: competition.description,
                    body: "\(username) sent a message",
                    senderId: userId,
                    excludeUsers: [userId]
                )
                
                NotificationQueueManager.shared.processQueuedNotifications()
            }
        }
        
        Analytics.shared.trackTap(
            elementId: "message_send_btn_tapped",
            screenName: "entry_view"
        )
    }
    
    func triggerHapticFeedback(for star: Int) {
        let intensity = Float(star) / 5.0
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred(intensity: CGFloat(intensity))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
            heavyGenerator.impactOccurred()
        }
    }
    
    func cleanup() {
        KingfisherManager.shared.downloader.cancelAll()
        chatViewModel.cleanup()
    }
}
