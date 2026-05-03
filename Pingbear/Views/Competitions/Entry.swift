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
    @State private var isLoadingSpinState: Bool = true
    
    // Generation counter — incremented on every entry change so stale
    // async callbacks know to discard their results.
    @State private var loadGeneration: Int = 0
    
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
            
            // Slot Machine Footer
            slotMachineFooter
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
        .onChange(of: viewModel.entries.count) { count in
            // On cold launch the entries array is empty when onAppear fires.
            // Watch for the first entry arriving and kick off the load then.
            // Guard avoids re-running once setupInitialEntry already succeeded.
            if count > 0 && loadGeneration <= 1 && spinResults.isEmpty && !hasStartedSpinning {
                loadGeneration += 1
                loadEntryData()
                preloadImages()
            }
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
            .padding(.bottom, 20)
            .background(Color(hex: "#1A2245"))
            .clipShape(
                RoundedCorner(
                    radius: 20,
                    corners: [.topLeft, .topRight]
                )
            )
            .background(
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
            VStack(spacing: 2) {
                if index < spinResults.count {
                    let result = spinResults[index]
                    
                    Text("\(result.stars)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                } else {
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
    
    var instructionText: String {
        if isLoadingSpinState {
            return "Loading..."
        } else if !hasStartedSpinning {
            return "Tap spin"
        } else if isSpinning {
            return "Spinning..."
        } else if selectedRatingIndex != nil {
            return "Submitting..."
        } else if hasStartedSpinning && spinsRemaining == 0 {
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
        canSpin ? Color(hex: "#4169E1") : Color(hex: "#666666")
    }
    
    var canSpin: Bool {
        return !isSpinning && !isLoadingSpinState && spinsRemaining > 0 && !currentEntryState.hasVoted
    }
    
    func slotBackgroundColor(index: Int) -> Color {
        if hasStartedSpinning && spinsRemaining == 0 && selectedRatingIndex == nil {
            return Color(hex: "#2A3A6B")
        } else {
            return Color(hex: "#2A3A6B").opacity(0.6)
        }
    }
    
    func slotBorderColor(index: Int) -> Color {
        if hasStartedSpinning && spinsRemaining == 0 && selectedRatingIndex == nil {
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
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        Task {
            await performSequentialSpins()
        }
    }
    
    func fetchMyPredictedRating(entryId: String, userId: String) async -> Int? {
        return await withCheckedContinuation { continuation in
            db.collection("competitions")
                .document(competition.id)
                .collection("entries")
                .document(entryId)
                .getDocument { document, _ in
                    guard let predictions = document?.data()?["predictions"] as? [String: Any],
                          let myPrediction = predictions[userId] as? [String: Any],
                          let predictedRating = myPrediction["predictedRating"] as? Int else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: predictedRating)
                }
        }
    }
    
    func performSequentialSpins() async {
        isSpinning = true
        hasStartedSpinning = true
        
        let totalToSpin = spinsRemaining
        let startingIndex = 3 - spinsRemaining
        
        let guaranteedRating: Int
        let guaranteedSlot: Int
        
        if let entry = currentEntry,
           let currentUserId = Auth.auth().currentUser?.uid,
           let prediction = await fetchMyPredictedRating(entryId: entry.id, userId: currentUserId) {
            guaranteedRating = prediction
        } else {
            guaranteedRating = Int.random(in: 4...5)
        }
        guaranteedSlot = startingIndex + Int.random(in: 0..<totalToSpin)
        
        var usedRatings = spinResults.map { $0.stars }
        usedRatings.append(guaranteedRating)
        
        for i in 0..<totalToSpin {
            let slotIndex = startingIndex + i
            let isGuaranteedSlot = slotIndex == guaranteedSlot
            let forcedRating = isGuaranteedSlot ? guaranteedRating : nil
            
            let finalResult = await runSingleSpin(
                slotIndex: slotIndex,
                usedRatings: isGuaranteedSlot ? [] : usedRatings,
                forcedRating: forcedRating
            )
            
            if !isGuaranteedSlot {
                usedRatings.append(finalResult.stars)
            }
            
            await MainActor.run {
                spinsRemaining -= 1
            }
            
            if i < totalToSpin - 1 {
                try? await Task.sleep(nanoseconds: 600_000_000)
            }
        }
        
        // Save spin state after all spins complete
        saveSpinState()
        
        isSpinning = false
    }
    
    func runSingleSpin(
        slotIndex: Int,
        usedRatings: [Int],
        forcedRating: Int? = nil
    ) async -> SlotMachineUtils.SpinResult {
        var spinCount = 0
        
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
            
            try? await Task.sleep(nanoseconds: 100_000_000)
            spinCount += 1
        }
        
        var finalRating: Int
        if let forced = forcedRating {
            finalRating = forced
        } else {
            var attempts = 0
            repeat {
                finalRating = Int.random(in: 1...5)
                attempts += 1
            } while usedRatings.contains(finalRating) && attempts < 100
        }
        
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
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.submitRating(stars: selectedStars, entry: entry)
        }
    }
}

// MARK: - Entry Management

private extension EntryView {
    
    func setupInitialEntry() {
        loadGeneration += 1
        
        // If entries are already loaded (e.g. view re-opened), kick off immediately.
        // If not yet loaded (cold launch), the onChange(of: viewModel.entries.count)
        // watcher will trigger loadEntryData the moment the first entry arrives.
        guard currentEntry != nil else { return }
        
        loadEntryData()
        preloadImages()
    }
    
    func handleEntryChange() {
        // Bump generation so any in-flight callbacks for the previous entry
        // will see a mismatch and discard their results.
        loadGeneration += 1
        
        currentEntryState.reset()
        spinResults = []
        isSpinning = false
        hasStartedSpinning = false
        spinsRemaining = 3
        selectedRatingIndex = nil
        isLoadingSpinState = true
        
        loadEntryData()
    }
    
    func loadEntryData() {
        guard let entry = currentEntry else { return }
        
        // Capture the generation at the time this load started.
        // If it changes before any callback fires, we discard the result.
        let generation = loadGeneration
        
        isLoadingSpinState = true
        
        Task {
            // 1. Vote check first — always required before we touch spin state
            await loadVotingStatus(for: entry, generation: generation)
            
            // Bail if the entry changed while we were checking votes
            guard loadGeneration == generation else { return }
            
            // 2. Only load spin state if the user hasn't already voted
            if !currentEntryState.hasVoted {
                await loadSpinState(for: entry, generation: generation)
            } else {
                // User already voted — nothing to restore
                isLoadingSpinState = false
            }
            
            // 3. Interactions can load independently
            loadInteractions(for: entry)
        }
    }
    
    @MainActor
    func loadVotingStatus(for entry: Entry, generation: Int) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let voteDoc = try await db.collection("groupMemberships")
                .document(currentUserId)
                .collection("competitions")
                .document(competition.id)
                .collection("votes")
                .document(entry.id)
                .getDocument()
            
            guard loadGeneration == generation else { return }
            
            currentEntryState.hasVoted = voteDoc.exists
            currentEntryState.canRate = !voteDoc.exists
        } catch {
            print("Error loading voting status: \(error)")
        }
    }
    
    @MainActor
    func loadSpinState(for entry: Entry, generation: Int) async {
        await withCheckedContinuation { continuation in
            SpinStateManager.shared.loadSpinState(
                competitionId: competition.id,
                entryId: entry.id
            ) { savedResults in
                DispatchQueue.main.async {
                    // Discard if the entry changed while this was in flight
                    guard self.loadGeneration == generation else {
                        continuation.resume()
                        return
                    }
                    
                    self.isLoadingSpinState = false
                    
                    if !savedResults.isEmpty {
                        self.spinResults = savedResults
                        self.hasStartedSpinning = true
                        self.spinsRemaining = max(0, 3 - savedResults.count)
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    func saveSpinState() {
        guard let entry = currentEntry else { return }
        
        SpinStateManager.shared.saveSpinState(
            competitionId: competition.id,
            entryId: entry.id,
            spinResults: spinResults
        ) { success in
            if !success {
                print("Failed to save spin state for entry \(entry.id)")
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
    
    func submitRating(stars: Int, entry: Entry) {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              currentEntryState.canRate else { return }
        
        Analytics.shared.trackEntry(
            action: "rate",
            entryId: entry.id,
            competitionId: competition.id,
            properties: ["rating": stars, "location": "entry_view"]
        )
        
        ParlayManager.shared.handleRating(
            competitionId: competition.id,
            entryId: entry.id,
            userId: currentUserId,
            rating: stars
        ) { [self] success in
            DispatchQueue.main.async {
                if success {
                    print("Rating processed successfully")
                    
                    currentEntryState.completeRating()
                    
                    // Award stars to the photo owner via RaceManager, matching FullScreenPhotoView
                    RaceManager.shared.handleRatingReceived(
                        competitionId: competition.id,
                        photoOwnerId: entry.userId,
                        stars: stars
                    ) { raceSuccess in
                        if raceSuccess {
                            print("✅ Race stars updated for photo owner \(entry.userId)")
                        } else {
                            print("❌ Failed to update race stars")
                        }
                    }
                    
                    self.interactionService.submitRating(
                        competitionId: self.competition.id,
                        entryId: entry.id,
                        rating: stars,
                        points: 0
                    ) { interactionSuccess in
                        if interactionSuccess {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.interactionService.fetchInteractions(
                                    competitionId: self.competition.id,
                                    entryId: entry.id
                                )
                            }
                        }
                    }
                    
                    // Auto-advance to next entry after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        self.advanceToNextEntry()
                    }
                    
                } else {
                    print("Failed to process rating")
                    self.handleRatingFailure()
                }
            }
        }
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
