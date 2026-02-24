import SwiftUI
import Kingfisher
import FirebaseAuth
import FirebaseFirestore

// Keep this extension - still needed for dismissing camera flow
extension Notification.Name {
    static let showUserPhotosAfterUpload = Notification.Name("showUserPhotosAfterUpload")
}

struct FullScreenPhotoView: View {
    let photo: UserPhoto
    let userName: String
    let competitionId: String?
    let userProfilePictureUrl: String?
    @Environment(\.dismiss) private var dismiss
    
    // Rating state
    @State private var currentStarCount: Int
    
    // Slot machine state
    @State private var spinResults: [SlotMachineUtils.SpinResult] = []
    @State private var isSpinning: Bool = false
    @State private var hasStartedSpinning: Bool = false
    @State private var spinsRemaining: Int = 3
    @State private var selectedRatingIndex: Int? = nil
    @State private var showWinScreen: Bool = false
    @State private var totalPointsEarned: Int = 0
    @State private var displayedPointsEarned: Int = 0
    @State private var hasAlreadyVoted: Bool = false
    @State private var isLoadingSpinState: Bool = false
    @State private var prizePoolAmount: Double = 50.0
    
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
    
    // Other ratings state
    @State private var showingOtherRatings = false
    
    // Chat ViewModel for sending messages
    @StateObject private var chatViewModel: ChatViewModel
    
    // Navigation flag
    let shouldShowUserPhotosOnBack: Bool
    
    // State for dismissal loading
    @State private var isDismissing = false
    
    let onDismiss: ((Int) -> Void)?
    
    init(photo: UserPhoto, userName: String, competitionId: String?, userProfilePictureUrl: String? = nil, onDismiss: ((Int) -> Void)? = nil, shouldShowUserPhotosOnBack: Bool = false) {
        self.photo = photo
        self.userName = userName
        self.competitionId = competitionId
        self.userProfilePictureUrl = userProfilePictureUrl
        self.onDismiss = onDismiss
        self._currentStarCount = State(initialValue: photo.stars)
        self._chatViewModel = StateObject(wrappedValue: ChatViewModel(competitionId: competitionId ?? ""))
        self.shouldShowUserPhotosOnBack = shouldShowUserPhotosOnBack
    }
    
    private let db = Firestore.firestore()
    
    var body: some View {
        ZStack {
            // Main content
            ZStack {
                GeometryReader { geometry in
                    let screenWidth = geometry.size.width
                    
                    // Photo with text overlay using shared component
                    PhotoMainImageView(
                        photoUrl: photo.photoUrl,
                        overlayText: photo.overlayText,
                        overlayVerticalPosition: photo.overlayVerticalPosition,
                        isTransitioning: false,
                        slideDirection: .left,
                        screenWidth: screenWidth
                    )
                }
                
                // TOP NAVIGATION using shared component
                VStack {
                    PhotoNavigationBar(
                        onBack: {
                            handleBackNavigation()
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
                
                // Bottom sheet - different content based on user role and status
                if isEntryCreator {
                    // Entry Creator View
                    if parlayStatus != nil && parlayStake > 0 {
                        // Has parlay - show predictions
                        entryCreatorBottomSheet
                    }
                    // No parlay - show nothing
                } else {
                    // Rater View
                    if hasAlreadyVoted && !showWinScreen {
                        // Already voted - show winnings
                        alreadyVotedFooter
                    } else if showWinScreen {
                        // Just won - show win screen
                        winScreenOverlay
                    } else {
                        // Can still rate - show slot machine
                        slotMachineFooter
                    }
                }
            }
            
            // Dismissal loading overlay
            if isDismissing {
                Color(hex: "#10183C")
                    .ignoresSafeArea()
            }
        }
        .background(Color(hex: "#10183C"))
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
        .sheet(isPresented: $showingOtherRatings) {
            OtherRatingsView(interactions: interactionService.interactions)
        }
        .onAppear {
            checkVotingStatus()
            loadSpinState()
            loadPrizePool()
            
            if let currentUserId = Auth.auth().currentUser?.uid {
                isEntryCreator = (photo.userId == currentUserId)
            }
            
            if let competitionId = competitionId {
                interactionService.loadRatingData(
                    competitionId: competitionId,
                    entryId: photo.id
                )
                
                // Fetch interactions first
                interactionService.fetchInteractions(
                    competitionId: competitionId,
                    entryId: photo.id
                )
            }
            
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
        .onChange(of: interactionService.interactions) { _ in
            // When interactions are loaded, check if user has already voted and load points
            if hasAlreadyVoted {
                if let userInteraction = interactionService.getCurrentUserInteraction() {
                    totalPointsEarned = userInteraction.points
                    displayedPointsEarned = userInteraction.points
                    print("✅ Loaded points from interaction: \(userInteraction.points)")
                } else {
                    print("❌ No interaction found for current user")
                }
            }
        }
    }
    
    // MARK: - Slot Machine UI Components
    
    private var alreadyVotedFooter: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Content with rounded top
            VStack(spacing: 5) {
                // "Rating Completed" text
                Text("You Won")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                // Side by side: Points won and Star rating given
                HStack(spacing: 30) {
                    // Points Won
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Text("+\(displayedPointsEarned)")
                                .font(.system(size: 45, weight: .bold))
                                .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                            
                            Image("gem")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 48, height: 48)
                        }
                    }
                }
                .padding(.vertical, 10)
                
                Button(action: {
                    showingOtherRatings = true
                }) {
                    Text("See Ratings (\(interactionService.interactions.count))")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#FFF"))
                }
                .padding(.top, 4)
                .padding(.bottom)
                
                // Disabled Spin button
                Button(action: {}) {
                    HStack(spacing: 10) {
                        Text("Spin")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "#c2c2c2"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "#666666"))
                    .cornerRadius(200)
                }
                .disabled(true)
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
    
    private var slotMachineFooter: some View {
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
    
    private func spinSlotView(index: Int) -> some View {
        Button(action: {
            if hasStartedSpinning && !isSpinning && selectedRatingIndex == nil && spinsRemaining == 0 {
                handleSelectRating(index: index)
            }
        }) {
            VStack(spacing: 2) {
                if index < spinResults.count {
                    let result = spinResults[index]
                    
                    // Star rating
                    Text("\(result.stars)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Star icon
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
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
    
    private var winScreenOverlay: some View {
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
                        
                        Image("gem")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(.white)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 65, height: 65)
                    }
                    
                    Text("$\(Int(ceil(prizePoolAmount))) Prize Pool")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                // Continue button
                
                Button(action: {
                    withAnimation {
                        showWinScreen = false
                    }
                }) {
                    HStack(spacing: 10) {
                        Text("Continue")
                            .font(.system(size: 20, weight: .bold))
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 20, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "#000"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 65)
                    .background(Color.white)
                    .cornerRadius(200)
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Slot Machine Logic
    
    private var instructionText: String {
        if !hasStartedSpinning {
            return "Tap spin"
        } else if isSpinning {
            return "Spinning..."
        } else if selectedRatingIndex != nil {
            return "Submitting..."  // ← Add this condition
        } else if hasStartedSpinning && spinsRemaining == 0 {
            return "Pick a rating"
        } else {
            return "Submitting..."
        }
    }
    
    private var spinButtonText: String {
        if isSpinning {
            return "Spinning..."
        } else {
            return "Spin"
        }
    }
    
    private var spinButtonColor: Color {
        if canSpin {
            return Color(hex: "#4169E1")
        } else {
            return Color(hex: "#666666")
        }
    }
    
    private var canSpin: Bool {
        return !isSpinning && spinsRemaining > 0 && !hasAlreadyVoted && userName != "Me"
    }
    
    private func slotBackgroundColor(index: Int) -> Color {
        if hasStartedSpinning && spinsRemaining == 0 && selectedRatingIndex == nil {
            return Color(hex: "#2A3A6B")
        } else {
            return Color(hex: "#2A3A6B").opacity(0.6)
        }
    }
    
    private func slotBorderColor(index: Int) -> Color {
        if hasStartedSpinning && spinsRemaining == 0 && selectedRatingIndex == nil {
            return Color.white.opacity(0.3)
        } else {
            return .clear
        }
    }
    
    private func handleSpin() {
        guard canSpin else { return }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        Task {
            await performSequentialSpins()
        }
    }
    
    // MARK: - Fetch predicted rating for current rater
    
    /// Reads the entry's predictions map to find if the entry creator predicted
    /// what rating the current user would give. Returns that predicted rating if found.
    private func fetchMyPredictedRating(competitionId: String, userId: String) async -> Int? {
        return await withCheckedContinuation { continuation in
            db.collection("competitions")
                .document(competitionId)
                .collection("entries")
                .document(photo.id)
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
    
    // MARK: - Sequential Spins with Guaranteed Predicted Rating
    
    private func performSequentialSpins() async {
        isSpinning = true
        hasStartedSpinning = true
        
        let totalToSpin = spinsRemaining
        let startingIndex = 3 - spinsRemaining
        
        // Fetch prediction and assign to a random slot upfront
        let guaranteedRating: Int
        let guaranteedSlot: Int
        
        if let competitionId = competitionId,
           let currentUserId = Auth.auth().currentUser?.uid,
           let prediction = await fetchMyPredictedRating(competitionId: competitionId, userId: currentUserId) {
            // Has prediction - guarantee that number appears
            guaranteedRating = prediction
        } else {
            // No prediction - guarantee a 4 or 5 always appears so rater has a "good" option
            guaranteedRating = Int.random(in: 4...5)
        }
        // Pick a random slot among the ones we're about to spin so it's not always first/last
        guaranteedSlot = startingIndex + Int.random(in: 0..<totalToSpin)
        
        // Track ALL ratings that must not appear in non-forced slots.
        // Seed with already-settled results + the guaranteed rating so free slots
        // never accidentally duplicate it.
        var usedRatings = spinResults.map { $0.stars }
        usedRatings.append(guaranteedRating)
        
        for i in 0..<totalToSpin {
            let slotIndex = startingIndex + i
            let isGuaranteedSlot = slotIndex == guaranteedSlot
            let forcedRating = isGuaranteedSlot ? guaranteedRating : nil
            
            // Forced slot: pass empty usedRatings — it ignores them anyway.
            // Free slots: pass usedRatings so they avoid all settled + guaranteed values.
            let finalResult = await runSingleSpin(
                slotIndex: slotIndex,
                usedRatings: isGuaranteedSlot ? [] : usedRatings,
                forcedRating: forcedRating
            )
            
            // Only append free-slot results to usedRatings — guaranteed was already added above.
            if !isGuaranteedSlot {
                usedRatings.append(finalResult.stars)
            }
            
            await MainActor.run {
                spinsRemaining -= 1
            }
            
            // Pause between spins (except after last spin)
            if i < totalToSpin - 1 {
                try? await Task.sleep(nanoseconds: 600_000_000) // 600ms
            }
        }
        
        // Save spin state to Firestore
        saveSpinState()
        
        isSpinning = false
    }
    
    // MARK: - Single Spin Animation
    
    /// Runs the slot animation for one slot then settles on the final value.
    /// If `forcedRating` is provided the slot always lands on that value.
    /// Otherwise it picks randomly while avoiding anything in `usedRatings`.
    private func runSingleSpin(
        slotIndex: Int,
        usedRatings: [Int],
        forcedRating: Int? = nil
    ) async -> SlotMachineUtils.SpinResult {
        var spinCount = 0
        
        // Animate with random values during the spin
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
        
        // Settle on the final value
        var finalRating: Int
        if let forced = forcedRating {
            // This slot must show the predicted rating
            finalRating = forced
        } else {
            // Pick randomly, avoiding all used/reserved ratings
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
    
    private func handleSelectRating(index: Int) {
        guard index < spinResults.count, selectedRatingIndex == nil else { return }
        
        selectedRatingIndex = index  // Triggers scale animation
        let selectedStars = spinResults[index].stars
        
        // Calculate total points from ALL 3 spins
        totalPointsEarned = SlotMachineUtils.calculateTotalPoints(from: spinResults)
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Wait 0.5 second before submitting (keeps enlarged state visible)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.submitRating(stars: selectedStars, points: self.totalPointsEarned)
        }
    }

    private func loadPrizePool() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // First check if user has an active pot
        db.collection("users").document(userId).getDocument { document, error in
            if let potId = document?.data()?["active_pot_id"] as? String {
                // User is in a pot, get that pot's prize pool
                self.db.collection("global_pots").document(potId).getDocument { potDoc, _ in
                    if let potData = potDoc?.data() {
                        let firstPlace = potData["first_place_prize"] as? Double ?? 100.0
                        let maxParts = potData["max_participants"] as? Int ?? 99
                        let decay = potData["decay_rate"] as? Double ?? 0.91
                        let minPay = potData["min_payout"] as? Double ?? 0.01
                        
                        let maxPool = self.calculateMaxPrizePool(
                            firstPlace: firstPlace,
                            decayRate: decay,
                            minPayout: minPay,
                            maxParticipants: maxParts
                        )
                        
                        DispatchQueue.main.async {
                            self.prizePoolAmount = maxPool
                        }
                    }
                }
            } else {
                // User not in pot, get default from config
                self.db.collection("app_config").document("global_leaderboard")
                    .getDocument { configDoc, _ in
                        if let data = configDoc?.data() {
                            let firstPlace = data["first_place_prize"] as? Double ?? 100.0
                            let decayRate = data["decay_rate"] as? Double ?? 0.91
                            let minPayout = data["min_payout"] as? Double ?? 0.01
                            let maxParticipants = data["pot_max_participants"] as? Int ?? 99
                            
                            let maxPool = self.calculateMaxPrizePool(
                                firstPlace: firstPlace,
                                decayRate: decayRate,
                                minPayout: minPayout,
                                maxParticipants: maxParticipants
                            )
                            
                            DispatchQueue.main.async {
                                self.prizePoolAmount = maxPool
                            }
                        }
                    }
            }
        }
    }

    private func calculateMaxPrizePool(firstPlace: Double, decayRate: Double, minPayout: Double, maxParticipants: Int) -> Double {
        var totalCents = 0
        
        for rank in 1...maxParticipants {
            let prizeCents = Int(floor(firstPlace * 100 * pow(decayRate, Double(rank - 1))))
            if prizeCents < Int(minPayout * 100) {
                break
            }
            totalCents += prizeCents
        }
        
        return Double(totalCents) / 100.0
    }
    
    // Animate the counter on win screen
    private func animateCounter() {
        let duration: TimeInterval = 2.0
        let steps = 60
        var currentStep = 0
        
        Timer.scheduledTimer(withTimeInterval: duration / Double(steps), repeats: true) { timer in
            currentStep += 1
            
            if currentStep >= steps {
                displayedPointsEarned = totalPointsEarned
                timer.invalidate()
            } else {
                displayedPointsEarned = (totalPointsEarned * currentStep) / steps
            }
        }
    }
    
    // MARK: - Entry Creator Bottom Sheet
    
    private var entryCreatorBottomSheet: some View {
        UltraSmoothBottomSheet(
            minHeight: PhotoViewConstants.minHeight,
            midHeight: UIScreen.main.bounds.height * 0.5,
            maxHeight: PhotoViewConstants.maxHeight(withFooter: false),
            bottomPadding: 0
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
                
                // Scrollable content
                ScrollView {
                    VStack(spacing: 16) {
                        // Single container for both Predictions and Other Ratings
                        VStack(spacing: 12) {
                            HStack {
                                Text("My Predictions")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                parlayStatusBadge
                            }
                            .padding(.bottom, 8)
                            
                            if parlayStatus == "pending" {
                                parlayProgressViewInline
                            } else if parlayStatus == "won" {
                                parlayWonViewInline
                            } else if parlayStatus == "lost" {
                                parlayLostViewInline
                            }
                            
                            // Other Ratings Section
                            let predictedUserIds = Set(parlayPredictions.keys)
                            let otherRatings = interactionService.interactions.filter { !predictedUserIds.contains($0.userId) }
                            
                            if !otherRatings.isEmpty {
                                VStack(spacing: 0) {
                                    Divider()
                                        .background(Color.white.opacity(0.2))
                                        .padding(.bottom, 12)
                                    
                                    HStack {
                                        Text("Other Ratings (\(otherRatings.count))")
                                            .foregroundColor(.white)
                                            .font(.system(size: 15, weight: .bold))
                                            .padding(.top, 5)
                                            .padding(.bottom, 10)
                                        
                                        Spacer()
                                    }
                                    
                                    VStack(spacing: 0) {
                                        ForEach(otherRatings) { interaction in
                                            VStack(spacing: 0) {
                                                HStack(spacing: 5) {
                                                    ProfilePictureView(url: interaction.profilePictureUrl, size: 36)
                                                    
                                                    Text(interaction.userName)
                                                        .font(.system(size: 15, weight: .semibold))
                                                        .foregroundColor(.white)
                                                        .lineLimit(1)
                                                        .padding(.leading, 10)
                                                    
                                                    Spacer()
                                                    
                                                    HStack(spacing: 6) {
                                                        Text("\(interaction.rating)")
                                                            .font(.system(size: 15, weight: .bold))
                                                            .foregroundColor(.white)
                                                        
                                                        Image(systemName: "star.fill")
                                                            .resizable()
                                                            .frame(width: 15, height: 15)
                                                            .foregroundColor(.white)
                                                    }
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 5)
                                                    .background(Color(hex: "#DAA520"))
                                                    .cornerRadius(20)
                                                }
                                                .padding(.horizontal, 0)
                                                .padding(.vertical, 15)
                                                
                                                if interaction.id != otherRatings.last?.id {
                                                    Divider()
                                                        .background(Color.white.opacity(0.2))
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    // MARK: - Navigation Handler
    
    private func handleBackNavigation() {
        if shouldShowUserPhotosOnBack {
            isDismissing = true
            NotificationCenter.default.post(name: .dismissCameraFlow, object: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.dismiss()
            }
        } else {
            onDismiss?(currentStarCount)
            dismiss()
        }
    }
    
    // MARK: - Parlay Status Views
    
    private var parlayStatusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(parlayStatusColor)
                .frame(width: 8, height: 8)
            
            Text(parlayStatusText)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(parlayStatusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(parlayStatusColor.opacity(0.15))
        .cornerRadius(20)
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
    
    private var parlayProgressViewInline: some View {
        VStack(spacing: 8) {
            predictionsList
            
            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical, 5)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Entry")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("\(parlayStake)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image("coin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    }
                }
                
                HStack {
                    Text("To Win")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("\(parlayPayout)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image("coin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    }
                }
                
                let profit = parlayPayout - parlayStake
                HStack {
                    Text("Profit")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Text("+\(profit)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "#00FF00"))
                }
            }
        }
    }
    
    private var parlayWonViewInline: some View {
        VStack(spacing: 8) {
            predictionsList
            
            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical, 5)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Entry")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("\(parlayStake)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image("coin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    }
                }
                
                HStack {
                    Text("Win")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("\(parlayPayout)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image("coin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    }
                }
                
                let profit = parlayPayout - parlayStake
                HStack {
                    Text("Profit")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Text("+\(profit)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "#00FF00"))
                }
            }
        }
    }
    
    private var parlayLostViewInline: some View {
        VStack(spacing: 8) {
            predictionsList
            
            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical, 5)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Entry")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("\(parlayStake)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image("coin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    }
                }
                
                HStack {
                    Text("Win")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("0")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image("coin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    }
                }
            }
        }
    }
    
    private var predictionsList: some View {
        VStack(spacing: 0) {
            if !parlayPredictions.isEmpty {
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
        
        let interaction = interactionService.interactions.first { $0.userId == userId }
        let userName: String
        let profilePictureUrl: String?
        
        if let interaction = interaction {
            userName = interaction.userName
            profilePictureUrl = interaction.profilePictureUrl
        } else if let cachedProfile = pendingUserProfiles[userId] {
            userName = cachedProfile.username
            profilePictureUrl = cachedProfile.profilePictureUrl
        } else {
            userName = "Friend"
            profilePictureUrl = nil
            fetchUserProfileForPendingUser(userId: userId)
        }
        
        return AnyView(
            HStack(spacing: 12) {
                ProfilePictureView(url: profilePictureUrl, size: 36)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(userName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let actualRating = actualRating {
                        HStack(alignment: .center, spacing: 0) {
                           HStack(spacing: 3) {
                               Image(systemName: "star.fill")
                                   .font(.system(size: 12))
                                   .foregroundColor(.white)
                               
                               Text("\(predictedRating)")
                                   .font(.system(size: 14, weight: .bold))
                                   .foregroundColor(.white)
                           }
                           .frame(height: 28)
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
                           
                           if !isCorrect {
                               HStack(spacing: 4) {
                                   Text("\(actualRating)")
                                       .font(.system(size: 14, weight: .bold))
                                       .foregroundColor(.white.opacity(0.8))
                               }
                               .frame(height: 28)
                               .padding(.horizontal, 8)
                               .background(
                                    Color.gray.opacity(0.6)
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
                               .font(.system(size: 12))
                               .foregroundColor(.white)
                           
                           Text("\(predictedRating)")
                               .font(.system(size: 14, weight: .bold))
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
                
                if actualRating != nil {
                    Text(isCorrect ? "✓" : "✗")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(isCorrect ? Color(hex: "#00FF00") : Color(hex: "#FF4444"))
                } else {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 17))
                        .foregroundColor(Color(hex: "#FFD700"))
                }
            }
            .padding(.vertical, 8)
        )
    }
    
    // MARK: - Helper Methods
    
    private func fetchUserProfileForPendingUser(userId: String) {
        guard pendingUserProfiles[userId] == nil else { return }
        
        db.collection("users").document(userId).getDocument { document, error in
            if let data = document?.data(),
               let name = data["name"] as? String {
                let profilePictureUrl = data["profilePictureUrl"] as? String
                DispatchQueue.main.async {
                    self.pendingUserProfiles[userId] = (username: name, profilePictureUrl: profilePictureUrl)
                }
            }
        }
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
    
    private func sendPhotoMessage(text: String) {
        chatViewModel.sendPhotoMessage(photo: photo, text: text)
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        if let userId = Auth.auth().currentUser?.uid, let competitionId = competitionId {
            let competitionRef = db.collection("competitions").document(competitionId)
            let userRef = db.collection("users").document(userId)
            
            let group = DispatchGroup()
            var competitionDescription = "Competition"
            var username = "Someone"
            
            group.enter()
            competitionRef.getDocument { compDoc, _ in
                competitionDescription = compDoc?.data()?["description"] as? String ?? "Competition"
                group.leave()
            }
            
            group.enter()
            userRef.getDocument { userDoc, _ in
                username = userDoc?.data()?["name"] as? String ?? "Someone"
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
            }
        }
    }
    
    private func loadSpinState() {
        guard let competitionId = competitionId,
              !hasAlreadyVoted,
              userName != "Me" else {
            return
        }
        
        isLoadingSpinState = true
        
        SpinStateManager.shared.loadSpinState(
            competitionId: competitionId,
            entryId: photo.id
        ) { spinResults in
            DispatchQueue.main.async {
                self.isLoadingSpinState = false
                
                if !spinResults.isEmpty {
                    self.spinResults = spinResults
                    self.hasStartedSpinning = true
                    
                    let spinsUsed = spinResults.count
                    self.spinsRemaining = 3 - spinsUsed
                    
                    self.totalPointsEarned = SlotMachineUtils.calculateTotalPoints(from: spinResults)
                }
            }
        }
    }
    
    private func saveSpinState() {
        guard let competitionId = competitionId else {
            return
        }
        
        SpinStateManager.shared.saveSpinState(
            competitionId: competitionId,
            entryId: photo.id,
            spinResults: spinResults
        ) { success in
            if !success {
                print("Failed to save spin state")
            }
        }
    }
    
    private func submitRating(stars: Int, points: Int) {
        guard let competitionId = competitionId,
              let currentUserId = Auth.auth().currentUser?.uid,
              !hasAlreadyVoted else {
            return
        }
        
        Analytics.shared.trackEntry(
            action: "rate",
            entryId: photo.id,
            competitionId: competitionId,
            properties: ["rating": stars, "location": "fullscreen_view", "total_points": points]
        )
        
        // Use ParlayManager to handle the rating
        ParlayManager.shared.handleRating(
            competitionId: competitionId,
            entryId: photo.id,
            userId: currentUserId,
            rating: stars
        ) { [self] success in
            DispatchQueue.main.async {
                if success {
                    print("Rating processed successfully")
                    
                    // Update local star count
                    self.currentStarCount += stars
                    
                    // Award points to RATER (the current user)
                    GlobalLeaderboardManager.shared.handleStarAwarded(
                        userId: currentUserId,
                        stars: points,
                        competitionId: competitionId
                    ) { pointsSuccess in
                        if pointsSuccess {
                            print("✅ Rater awarded \(points) points")
                        } else {
                            print("❌ Failed to award points to rater")
                        }
                    }
                    
                    // Reload parlay status if user is entry creator
                    if self.isEntryCreator {
                        self.loadParlayStatus()
                    }
                    
                    // Submit to interaction service
                    self.interactionService.submitRating(
                        competitionId: competitionId,
                        entryId: self.photo.id,
                        rating: stars,
                        points: points
                    ) { interactionSuccess in
                        if interactionSuccess {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.interactionService.fetchInteractions(
                                    competitionId: competitionId,
                                    entryId: self.photo.id
                                )
                            }
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
                    
                    self.hasAlreadyVoted = true
                    
                } else {
                    print("Failed to process rating")
                    // Reset state on failure
                    self.selectedRatingIndex = nil
                    self.spinResults = []
                    self.hasStartedSpinning = false
                    self.spinsRemaining = 3
                }
            }
        }
    }
}
