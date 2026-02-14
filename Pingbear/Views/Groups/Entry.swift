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
    
    // Slot machine state
    @State private var spinResults: [SlotMachineUtils.SpinResult] = []
    @State private var isSpinning: Bool = false
    @State private var hasStartedSpinning: Bool = false
    @State private var spinsRemaining: Int = 3
    @State private var selectedRatingIndex: Int? = nil
    @State private var showWinScreen: Bool = false
    @State private var totalPointsEarned: Int = 0
    @State private var displayedPointsEarned: Int = 0
    @State private var isLoadingSpinState: Bool = false
    
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
                        onMessage: { currentEntryState.showingMessageComposer = true }
                    )
                }
                Spacer()
            }
            
            // Win Screen Overlay
            if showWinScreen {
                winScreenOverlay
            }
            
            // Slot Machine Footer
            if !showWinScreen {
                slotMachineFooter
            }
        }
        .background(Color(hex: "#10183C"))
        .sheet(isPresented: $currentEntryState.showingMessageComposer) {
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
        var hasVoted: Bool = false
        var canRate: Bool = true
        var isTransitioning: Bool = false
        var slideDirection: SlideDirection = .left
        var showingMessageComposer: Bool = false
        
        mutating func reset() {
            hasVoted = false
            canRate = true
        }
        
        mutating func completeRating() {
            hasVoted = true
            canRate = false
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

// MARK: - Slot Machine UI Components

private extension EntryView {
    
    var slotMachineFooter: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Content with rounded top
            VStack(spacing: 20) {
                // Instruction Text
                Text(instructionText)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Spin Results Display
                HStack(spacing: 15) {
                    ForEach(0..<3, id: \.self) { index in
                        spinSlotView(index: index)
                    }
                }
                .frame(minHeight: 70)
                
                // Spin Button
                Button(action: handleSpin) {
                    HStack(spacing: 10) {
                        Text(spinButtonText)
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(spinButtonColor)
                    .cornerRadius(200)
                }
                .disabled(!canSpin)
            }
            .padding(20)
            .padding(.bottom, 20) // Extra padding for safe area
            .background(Color(hex: "#1A2245"))
            .clipShape(
                RoundedCorner(
                    radius: 20,
                    corners: [.topLeft, .topRight]
                )
            )
            .background(
                // Background color that extends below
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 20)
                    Color(hex: "#1A2245")
                }
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    func spinSlotView(index: Int) -> some View {
        Button(action: {
            if hasStartedSpinning && !isSpinning && selectedRatingIndex == nil && spinsRemaining == 0 {
                handleSelectRating(index: index)
            }
        }) {
            VStack(spacing: 8) {
                if index < spinResults.count {
                    let result = spinResults[index]
                    
                    // Star rating
                    Text("\(result.stars)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Star icon
                    Image(systemName: "star.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                } else {
                    // Empty slot
                    Text("")
                        .font(.system(size: 24, weight: .bold))
                }
            }
            .frame(width: 60, height: 60)
            .background(slotBackgroundColor(index: index))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(slotBorderColor(index: index), lineWidth: selectedRatingIndex == index ? 2 : 0)
            )
            .scaleEffect(selectedRatingIndex == index ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: selectedRatingIndex)
        }
        .disabled(!hasStartedSpinning || isSpinning || selectedRatingIndex != nil || spinsRemaining > 0)
    }
    
    var winScreenOverlay: some View {
        ZStack {
            // Green background
            Color(hex: "#10B981")
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            showWinScreen = false
                            // Auto-advance after closing win screen
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                self.advanceToNextEntry()
                            }
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                // Win content
                VStack(spacing: 30) {
                    Text("You Won")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    // Points display with animation
                    HStack(spacing: 15) {
                        Text("+\(displayedPointsEarned)")
                            .font(.system(size: 72, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "star.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }
                    
                    Text("Points")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                // Continue button
                Button(action: {
                    withAnimation {
                        showWinScreen = false
                    }
                    // Auto-advance after brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.advanceToNextEntry()
                    }
                }) {
                    HStack(spacing: 10) {
                        Text("Continue")
                            .font(.system(size: 20, weight: .bold))
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 20, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "#10B981"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.white)
                    .cornerRadius(200)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .zIndex(100) // Ensure it's above everything
    }
    
    var instructionText: String {
        if !hasStartedSpinning {
            return "Tap spin"
        } else if isSpinning {
            return "Spinning..."
        } else if hasStartedSpinning && spinsRemaining == 0 && selectedRatingIndex == nil {
            return "Pick a rating"
        } else {
            return "Submitting..."
        }
    }
    
    var spinButtonText: String {
        if isSpinning {
            return "Spinning..."
        } else {
            return "Spin"
        }
    }
    
    var spinButtonColor: Color {
        if canSpin {
            return Color(hex: "#4169E1")
        } else {
            return Color(hex: "#666666")
        }
    }
    
    var canSpin: Bool {
        return !isSpinning && spinsRemaining > 0 && !currentEntryState.hasVoted
    }
    
    func slotBackgroundColor(index: Int) -> Color {
        if selectedRatingIndex == index {
            return Color(hex: "#4169E1")
        } else if hasStartedSpinning && spinsRemaining == 0 && selectedRatingIndex == nil {
            return Color(hex: "#2A3A6B")
        } else {
            return Color(hex: "#2A3A6B").opacity(0.6)
        }
    }
    
    func slotBorderColor(index: Int) -> Color {
        if selectedRatingIndex == index {
            return .white
        } else if hasStartedSpinning && spinsRemaining == 0 && selectedRatingIndex == nil {
            return Color.white.opacity(0.3)
        } else {
            return .clear
        }
    }
}

// MARK: - Slot Machine Logic

private extension EntryView {
    
    func handleSpin() {
        guard canSpin else { return }
        
        Task {
            await performSequentialSpins()
        }
    }
    
    // Perform all remaining spins sequentially
    private func performSequentialSpins() async {
        isSpinning = true
        hasStartedSpinning = true
        
        let totalToSpin = spinsRemaining
        let startingIndex = 3 - spinsRemaining
        var settledRatings = spinResults.map { $0.stars }
        
        for i in 0..<totalToSpin {
            let slotIndex = startingIndex + i
            
            // Run single spin animation
            let finalResult = await runSingleSpin(slotIndex: slotIndex, usedRatings: settledRatings)
            
            // Update settled ratings
            settledRatings.append(finalResult.stars)
            
            // Decrement spins remaining
            await MainActor.run {
                spinsRemaining -= 1
            }
            
            // Pause between spins (except after last spin)
            if i < totalToSpin - 1 {
                try? await Task.sleep(nanoseconds: 600_000_000) // 600ms
            }
        }
        
        // Save spin state to Firestore
        if let entry = currentEntry {
            SpinStateManager.shared.saveSpinState(
                competitionId: competition.id,
                entryId: entry.id,
                spinResults: spinResults
            ) { success in
                if !success {
                    print("Failed to save spin state")
                }
            }
        }
        
        isSpinning = false
    }
    
    // Run a single spin animation for one slot
    private func runSingleSpin(slotIndex: Int, usedRatings: [Int]) async -> SlotMachineUtils.SpinResult {
        var spinCount = 0
        
        // Animate with random values
        while spinCount < 10 {
            let randomRating = Int.random(in: 1...5)
            let tempResult = SlotMachineUtils.SpinResult(stars: randomRating, multiplier: 1, points: 0)
            
            await MainActor.run {
                if slotIndex < spinResults.count {
                    spinResults[slotIndex] = tempResult
                } else {
                    spinResults.append(tempResult)
                }
            }
            
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            spinCount += 1
        }
        
        // Generate final result - avoid duplicates
        var finalRating: Int
        var attempts = 0
        repeat {
            finalRating = Int.random(in: 1...5)
            attempts += 1
        } while usedRatings.contains(finalRating) && attempts < 100
        
        // Generate spin result using SlotMachineUtils
        let multiplier = SlotMachineUtils.getWeightedMultiplier()
        let points = SlotMachineUtils.calculatePoints(stars: finalRating, multiplier: multiplier)
        
        let finalResult = SlotMachineUtils.SpinResult(stars: finalRating, multiplier: multiplier, points: points)
        
        await MainActor.run {
            if slotIndex < spinResults.count {
                spinResults[slotIndex] = finalResult
            } else {
                spinResults.append(finalResult)
            }
        }
        
        return finalResult
    }
    
    func handleSelectRating(index: Int) {
        guard index < spinResults.count, selectedRatingIndex == nil, let entry = currentEntry else { return }
        
        selectedRatingIndex = index
        let selectedStars = spinResults[index].stars
        
        // Calculate total points from ALL 3 spins
        totalPointsEarned = SlotMachineUtils.calculateTotalPoints(from: spinResults)
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Submit the rating
        handleRatingSubmission(stars: selectedStars, points: totalPointsEarned)
    }
    
    // Animate the counter on win screen
    private func animateCounter() {
        let duration: TimeInterval = 2.0
        let steps = 60
        let increment = totalPointsEarned / steps
        var currentStep = 0
        
        Timer.scheduledTimer(withTimeInterval: duration / Double(steps), repeats: true) { timer in
            currentStep += 1
            
            if currentStep >= steps {
                displayedPointsEarned = totalPointsEarned
                timer.invalidate()
            } else {
                displayedPointsEarned += increment
            }
        }
    }
}

// MARK: - Entry Management

private extension EntryView {
    
    func setupInitialEntry() {
        guard let entry = currentEntry else {
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
        // Reset ALL state for new entry
        currentEntryState.reset()
        spinResults = []
        isSpinning = false
        hasStartedSpinning = false
        spinsRemaining = 3
        selectedRatingIndex = nil
        showWinScreen = false
        totalPointsEarned = 0
        displayedPointsEarned = 0
        isLoadingSpinState = false
        
        loadEntryData()
    }
    
    func loadEntryData() {
        guard let entry = currentEntry else { return }
        
        Task {
            await loadVotingStatus(for: entry)
            loadSpinState(for: entry)
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
    
    func loadSpinState(for entry: Entry) {
        guard !currentEntryState.hasVoted else { return }
        
        isLoadingSpinState = true
        
        SpinStateManager.shared.loadSpinState(
            competitionId: competition.id,
            entryId: entry.id
        ) { spinResults in
            DispatchQueue.main.async {
                self.isLoadingSpinState = false
                
                if !spinResults.isEmpty {
                    self.spinResults = spinResults
                    self.hasStartedSpinning = true
                    
                    // Calculate remaining spins based on how many they've already done
                    let spinsUsed = spinResults.count
                    self.spinsRemaining = 3 - spinsUsed
                    
                    self.totalPointsEarned = SlotMachineUtils.calculateTotalPoints(from: spinResults)
                }
            }
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
    
    func handleRatingSubmission(stars: Int, points: Int) {
        guard let entry = currentEntry,
              let currentUserId = Auth.auth().currentUser?.uid,
              currentEntryState.canRate else { return }
        
        // Immediate UI feedback
        currentEntryState.completeRating()
        triggerHapticFeedback(for: stars)
        
        // Submit rating
        ParlayManager.shared.handleRating(
            competitionId: competition.id,
            entryId: entry.id,
            userId: currentUserId,
            rating: stars
        ) { [self] success in
            DispatchQueue.main.async {
                if success {
                    print("Rating processed successfully")
                    
                    // Award points to RATER
                    GlobalLeaderboardManager.shared.handleStarAwarded(
                        userId: currentUserId,
                        stars: points,
                        competitionId: self.competition.id
                    ) { pointsSuccess in
                        if pointsSuccess {
                            print("✅ Rater awarded \(points) points")
                        }
                    }
                    
                    // Submit to interaction service with points
                    self.interactionService.submitRating(
                        competitionId: self.competition.id,
                        entryId: entry.id,
                        rating: stars,
                        points: points
                    ) { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            self.interactionService.fetchInteractions(
                                competitionId: self.competition.id,
                                entryId: entry.id
                            )
                        }
                    }
                    
                    // Show win screen and start counter animation
                    withAnimation {
                        self.showWinScreen = true
                    }
                    
                    // Start counter animation after brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.animateCounter()
                    }
                    
                } else {
                    print("Failed to process rating")
                    self.handleRatingFailure()
                }
            }
        }
        
        Analytics.shared.trackEntry(
            action: "rate",
            entryId: entry.id,
            competitionId: competition.id,
            properties: ["rating": stars, "location": "entry_view", "total_points": points]
        )
    }
    
    func handleRatingFailure() {
        currentEntryState.reset()
        selectedRatingIndex = nil
        spinResults = []
        hasStartedSpinning = false
        spinsRemaining = 3
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
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        if let userId = Auth.auth().currentUser?.uid {
            db.collection("users").document(userId).getDocument { userDoc, _ in
                let username = userDoc?.data()?["name"] as? String ?? "Someone"
                
                NotificationQueueManager.shared.queueGroupNotification(
                    competitionId: self.competition.id,
                    title: self.competition.description,
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
