import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct UnlockView: View {
    @StateObject private var payViewModel = PayViewModel()
    @State private var shouldDismissCameraFlow = false
    @State private var userCoins: Int = 0
    @State private var isLoadingCoins = true
    @State private var showPayView = false
    @State private var unclaimedRakeback: Int = 0
    @State private var unlockSuccessful = false
    @State private var isUnlocking = false
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0.0
    @State private var isLoadingGroupSize = false
    @State private var customStakeAmount: String = ""
    @State private var showStakeEditor: Bool = false
    @StateObject private var membersViewModel = MembersViewModel()
    @ObservedObject private var pricingCalculator = CompetitionPricingCalculator.shared
    
    @State private var showingJoinSelectView = false
    @StateObject private var myFriendsModel = MyFriendsModel()
    
    // Parlay betting state
    @State private var selectedPredictions: [String: Int] = [:]
    @State private var showPredictionSelector = false
    @State private var selectedRaterId = ""
    
    // NEW: State for showing uploaded photo (removed UserPhotosView state)
    @State private var uploadedPhoto: UserPhoto? = nil
    @State private var showingUploadedPhoto = false
    @State private var currentUserProfilePictureUrl: String? = nil
    
    private var entryCost: Int {
        if !customStakeAmount.isEmpty, let customAmount = Int(customStakeAmount), customAmount > 0 {
            return customAmount
        }
        return 0
    }
    
    private var estimatedPayout: Int {
        guard !selectedPredictions.isEmpty && entryCost > 0 else { return 0 }
        return CompetitionPricingCalculator.shared.calculateParlayPayout(
            entryCost: entryCost,
            predictions: selectedPredictions
        )
    }
    
    private var parlayMultiplier: Double {
        guard !selectedPredictions.isEmpty else { return 0 }
        return CompetitionPricingCalculator.shared.getParlayMultiplier(
            predictions: selectedPredictions
        )
    }
    
    private var rakebackAmount: Int {
        guard entryCost > 0 else { return 0 }
        return pricingCalculator.calculateRakeback(entryCost: entryCost)
    }
    
    @Environment(\.dismiss) private var dismiss
    
    var competition: Competition
    var competitionId: String
    var image: UIImage
    var overlayText: String
    var overlayVerticalPosition: CGFloat
    var isFromCamera: Bool
    var selectedTheme: Theme?
    
    @ObservedObject private var uploadManager = EntryUploadManager.shared
    
    private let db = Firestore.firestore()
    
    init(competition: Competition, competitionId: String, image: UIImage, overlayText: String, overlayVerticalPosition: CGFloat, isFromCamera: Bool, selectedTheme: Theme?) {
        self.competition = competition
        self.competitionId = competitionId
        self.image = image
        self.overlayText = overlayText
        self.overlayVerticalPosition = overlayVerticalPosition
        self.isFromCamera = isFromCamera
        self.selectedTheme = selectedTheme
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isUploading {
                uploadProgressView
            } else {
                headerView
                Spacer()
                parlayBettingView
                Spacer()
            }
        }
        .background(Color(hex: "#10183C"))
        .sheet(isPresented: $showPayView, onDismiss: fetchUserCoins) {
            PayView(viewModel: payViewModel, competition: competition, competitionId: competitionId, entryDocId: "")
        }
        .sheet(isPresented: $showStakeEditor) {
            stakeEditorView
        }
        .sheet(isPresented: $showPredictionSelector) {
            predictionSelectorView
                .onAppear {
                    membersViewModel.fetchMembersDetails(for: competition)
                }
        }
        .fullScreenCover(isPresented: $showingJoinSelectView, onDismiss: {
            membersViewModel.fetchMembersDetails(for: competition)
        }) {
            JoinSelectView(competition: competition, viewModel: myFriendsModel)
        }
        // Show uploaded photo full screen
        .fullScreenCover(isPresented: $showingUploadedPhoto) {
            if let photo = uploadedPhoto {
                FullScreenPhotoView(
                    photo: photo,
                    userName: "Me",
                    competitionId: competitionId,
                    userProfilePictureUrl: currentUserProfilePictureUrl,
                    onDismiss: { _ in
                        showingUploadedPhoto = false
                    },
                    shouldShowUserPhotosOnBack: true
                )
            }
        }
        .onChange(of: payViewModel.purchaseCompleted) { completed in
            if completed {
                fetchUserCoins()
                payViewModel.purchaseCompleted = false
            }
        }
        .onChange(of: shouldDismissCameraFlow) { shouldDismiss in
            if shouldDismiss {
                NotificationCenter.default.post(name: .dismissCameraFlow, object: nil)
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "parlay_betting_paywall")
            fetchUserCoins()
            fetchCurrentUserProfilePicture() 
            EntryUploadManager.shared.initialize()
            membersViewModel.fetchMembersDetails(for: competition)
        }
    }
    
    // MARK: - Subviews
    
    private var uploadProgressView: some View {
        VStack {
            Spacer()
            VStack {
                ProgressView(value: uploadProgress, total: 100)
                    .scaleEffect(1.5)
                    .tint(.white)
                    .padding(.horizontal, 40)
                
                Text("\(Int(uploadProgress))%")
                    .foregroundColor(.white)
                    .font(.system(size: 17, weight: .medium))
                    .padding(.top)
            }
            .padding(50)
            Spacer()
        }
    }
    
    private var headerView: some View {
        HStack {
            // Left: Back button
            Button(action: {
                dismiss()
                Analytics.shared.track(event: "parlay_back_button_tapped")
            }) {
                Image(systemName: "arrow.left")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 27, height: 27)
                    .foregroundColor(Color.white)
            }
            
            Spacer()
            
            // Coin balance with rakeback badge
            Button(action: {
                showPayView = true
                Analytics.shared.track(event: "coins_button_tapped")
            }) {
                ZStack(alignment: .topTrailing) {
                    HStack(alignment: .center, spacing: 0) {
                        HStack(spacing: 5) {
                            Image("coin")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 19, height: 19)
                            
                            if isLoadingCoins {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("\(userCoins)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 15)
                        .frame(height: 45)
                        .background(
                            (!isLoadingCoins && entryCost > 0 && userCoins < entryCost)
                                ? Color(hex: "#F85149").opacity(0.3)
                                : Color(hex: "#2A3255")
                        )
                        .clipShape(
                            RoundedCorner(
                                radius: 200,
                                corners: [.topLeft, .bottomLeft]
                            )
                        )
                        
                        HStack {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .frame(width: 45, height: 45)
                                .foregroundColor(.white)
                                .background(
                                    Color(hex: "#3B4374")
                                        .clipShape(
                                            RoundedCorner(
                                                radius: 200,
                                                corners: [.topRight, .bottomRight]
                                            )
                                        )
                                )
                        }
                    }
                    
                    // Rakeback badge indicator
                    if unclaimedRakeback > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("\(unclaimedRakeback)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.red)
                        )
                        .offset(x: -8, y: -8)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Right: Skip button to submit without parlay
            Button(action: {
                submitWithoutParlay()
                Analytics.shared.track(event: "submit_without_parlay_tapped")
            }) {
                Text("Skip")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color(hex: "#1A2245"))
    }
    
    private var parlayBettingView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                predictionsSection
                stakeSectionView
                payoutSection
                submitButtonView
                
                if !isLoadingCoins && entryCost > 0 && userCoins < entryCost {
                    insufficientCoinsView
                }
            }
            .padding()
        }
        .background(Color(hex: "#1A2245"))
        .cornerRadius(14)
        .padding(.horizontal, 20)
        .padding(.vertical)
    }
    
    private var stakeSectionView: some View {
        VStack(spacing: 12) {
            Divider()
                .background(Color.white.opacity(0.1))
            
            HStack {
                Text("Entry")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Button(action: {
                    showStakeEditor.toggle()
                    Analytics.shared.track(event: "parlay_stake_edit_tapped")
                }) {
                    HStack(spacing: 6) {
                        Image("coin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                        
                        if entryCost > 0 {
                            Text("\(entryCost)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("Set Amount")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(!selectedPredictions.isEmpty ? .white : .white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(entryCost > 0 ? Color(hex: "#4169E1") : (!selectedPredictions.isEmpty ? Color(hex: "#4169E1") : Color.white.opacity(0.15)))
                    .cornerRadius(200)
                }
            }
        }
    }
    
    private var predictionsSection: some View {
        VStack(spacing: 16) {
            let availableRaters = membersViewModel.members.filter { $0.id != membersViewModel.currentUserId }
            
            HStack {
                Text("Make Your Predictions")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            if membersViewModel.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Spacer()
            } else if availableRaters.isEmpty {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("Add players to this competition so you can make predictions on their ratings")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.horizontal, 30)
                    }
                    
                    Button(action: {
                        showingJoinSelectView = true
                        Analytics.shared.trackTap(
                            elementId: "add_player_from_predictions",
                            screenName: "parlay_betting_paywall"
                        )
                    }) {
                        Text("Add Players")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color(hex: "#4169E1"))
                            .cornerRadius(200)
                    }
                    .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(availableRaters) { member in
                            predictionCard(for: member)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .cornerRadius(8)
            }
        }
    }
    
    private func predictionCard(for member: MemberUser) -> some View {
        let isSelected = selectedPredictions[member.id] != nil
        let selectedRating = selectedPredictions[member.id]
        
        return Button(action: {
            if isSelected {
                selectedPredictions.removeValue(forKey: member.id)
            } else {
                selectedRaterId = member.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showPredictionSelector = true
                }
            }
            
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            Analytics.shared.trackTap(
                elementId: "predictionCard_tap",
                screenName: "parlay_betting_paywall"
            )
        }) {
            VStack(spacing: 12) {
                ProfilePictureView(url: member.profileurl, size: 40)
                
                Text(member.username)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= (selectedRating ?? 0) ? "star.fill" : "star.fill")
                            .font(.system(size: 15))
                            .foregroundColor(
                                star <= (selectedRating ?? 0) ?
                                Color(hex: "#FFD700") :
                                Color.white.opacity(0.1)
                            )
                    }
                }
                
                if let rating = selectedRating {
                    let multiplier = CompetitionPricingCalculator.shared.getSingleStarMultiplier(starRating: rating)
                    Text("\(String(format: "%.1fx", multiplier))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#4169E1").opacity(0.3))
                        .cornerRadius(8)
                } else {
                    Text("Tap to predict")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                isSelected ?
                Color(hex: "#4169E1").opacity(0.2) :
                Color.white.opacity(0.05)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color(hex: "#4169E1") : Color.clear,
                        lineWidth: 2
                    )
            )
            .cornerRadius(8)
        }
    }
    
    private var payoutSection: some View {
        VStack(spacing: 12) {
            Divider()
                .background(Color.white.opacity(0.1))
            
            HStack {
                Text("Total Multiplier")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Text("\(String(format: "%.1fx", parlayMultiplier))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            HStack {
                Text("To Win")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image("coin")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                    
                    Text("\(estimatedPayout)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            let profit = estimatedPayout - entryCost
            if profit > 0 {
                HStack {
                    Text("Profit")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Text("+\(profit)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#00FF00"))
                }
            }
        }
    }
    
    private var submitButtonView: some View {
        let canSubmit = userCoins >= entryCost && !selectedPredictions.isEmpty && entryCost > 0 && !isLoadingCoins && !isUnlocking
        
        var buttonText: String {
            if selectedPredictions.isEmpty {
                return "Make Predictions to Continue"
            } else if entryCost == 0 {
                return "Set Entry Amount"
            } else {
                return "Place Predictions"
            }
        }
        
        return Button(action: {
            placeParlayBet()
            Analytics.shared.trackTap(
                elementId: "parlay_bet_placed",
                screenName: "parlay_betting_paywall"
            )
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }) {
            HStack {
                if isUnlocking {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(buttonText)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(canSubmit ? .white : Color.white.opacity(0.3))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(canSubmit ? Color(hex: "#4169E1") : Color.white.opacity(0.1))
            .cornerRadius(200)
        }
        .disabled(!canSubmit)
        .padding(.top)
    }
    
    private var insufficientCoinsView: some View {
        HStack(spacing: 12) {
            Text("Need \(entryCost - userCoins) more coins")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: "#F85149"))
            
            Spacer()
            
            Button(action: {
                showPayView = true
                Analytics.shared.trackTap(
                    elementId: "get_coins_parlay",
                    screenName: "parlay_betting_paywall"
                )
            }) {
                Text("Get Coins")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#4169E1"))
                    .cornerRadius(200)
            }
        }
        .padding()
        .background(Color(hex: "#F85149").opacity(0.1))
        .cornerRadius(8)
    }
    
    private var stakeEditorView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    showStakeEditor = false
                }) {
                    Image("x")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.white)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                }
                
                Spacer()
                
                Text("Set Entry Amount")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    if let amount = Int(customStakeAmount), amount > 0 {
                        showStakeEditor = false
                        Analytics.shared.track(
                            event: "parlay_stake_set",
                            properties: ["amount": amount]
                        )
                    }
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 21))
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#FFF"))
                }
                .opacity((Int(customStakeAmount) ?? 0) > 0 ? 1.0 : 0.5)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color(hex: "#2A3255"))
            .padding(.bottom, 50)
            
            VStack(spacing: 0) {
                HStack {
                    Text(customStakeAmount.isEmpty ? "0" : customStakeAmount)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                
                let suggestedAmounts = generateSuggestedAmounts()
                
                HStack(spacing: 0) {
                    ForEach(suggestedAmounts, id: \.self) { amount in
                        Button(action: {
                            let currentAmount = Int(customStakeAmount) ?? 0
                            let newAmount = currentAmount + amount
                            customStakeAmount = String(newAmount)
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }) {
                            HStack(spacing: 6) {
                                Image("coin")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 18, height: 18)
                                
                                Text("+\(amount)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.15))
                        }
                    }
                }
            }
            
            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    ForEach(1...3, id: \.self) { number in
                        NumberPadButton(number: "\(number)") {
                            appendNumber("\(number)")
                        }
                    }
                }
                
                HStack(spacing: 1) {
                    ForEach(4...6, id: \.self) { number in
                        NumberPadButton(number: "\(number)") {
                            appendNumber("\(number)")
                        }
                    }
                }
                
                HStack(spacing: 1) {
                    ForEach(7...9, id: \.self) { number in
                        NumberPadButton(number: "\(number)") {
                            appendNumber("\(number)")
                        }
                    }
                }
                
                HStack(spacing: 1) {
                    Button(action: {
                        clearAmount()
                    }) {
                        Text("C")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.white.opacity(0.1))
                    }
                    
                    NumberPadButton(number: "0") {
                        appendNumber("0")
                    }
                    
                    Button(action: {
                        deleteLastDigit()
                    }) {
                        Image(systemName: "delete.left")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.white.opacity(0.1))
                    }
                }
            }
            .frame(height: 240)
            .background(Color(hex: "#1A2245"))
            
            Spacer()
        }
        .background(Color(hex: "#1A2245"))
        .ignoresSafeArea(.keyboard)
    }

    struct NumberPadButton: View {
        let number: String
        let action: () -> Void
        
        var body: some View {
            Button(action: {
                action()
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }) {
                Text(number)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.05))
            }
        }
    }

    private func appendNumber(_ digit: String) {
        if customStakeAmount == "0" {
            customStakeAmount = digit
        } else if customStakeAmount.count < 8 {
            customStakeAmount += digit
        }
    }

    private func deleteLastDigit() {
        if !customStakeAmount.isEmpty {
            customStakeAmount.removeLast()
        }
    }

    private func clearAmount() {
        customStakeAmount = ""
    }
    
    private var predictionSelectorView: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: {
                    showPredictionSelector = false
                }) {
                    Image("x")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.white)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                }
                
                Spacer()
                
                Text("Predict Rating")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(.white)
                        .opacity(0)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color(hex: "#2A3255"))
            
            if membersViewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Spacer()
                }
            } else if let error = membersViewModel.error {
                VStack {
                    Spacer()
                    Text("Failed to load member data")
                        .foregroundColor(.white)
                    Text(error.localizedDescription)
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("Try Again") {
                        membersViewModel.fetchMembersDetails(for: competition)
                    }
                    .padding()
                    .background(Color(hex: "#4169E1"))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    Spacer()
                }
            } else if let member = membersViewModel.members.first(where: { $0.id == selectedRaterId }) {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        ProfilePictureView(url: member.profileurl, size: 60)
                        
                        Text("What will \(member.username) rate your photo?")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    
                    VStack(spacing: 16) {
                        ForEach((1...5).reversed(), id: \.self) { rating in
                            let isSelected = selectedPredictions[selectedRaterId] == rating
                            let multiplier = CompetitionPricingCalculator.shared.getSingleStarMultiplier(starRating: rating)
                            
                            Button(action: {
                                selectedPredictions[selectedRaterId] = rating
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    showPredictionSelector = false
                                }
                            }) {
                                HStack {
                                    HStack(spacing: 4) {
                                        ForEach(1...5, id: \.self) { star in
                                            Image(systemName: star <= rating ? "star.fill" : "star.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(star <= rating ? Color(hex: "#FFD700") : Color.white.opacity(0.1))
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 12) {
                                        Text("\(rating) Star\(rating == 1 ? "" : "s")")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                        
                                        Text("\(String(format: "%.1fx", multiplier))")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color(hex: "#4169E1").opacity(0.3))
                                            .cornerRadius(8)
                                    }
                                }
                                .padding()
                                .background(
                                    isSelected ?
                                    Color(hex: "#4169E1").opacity(0.2) :
                                    Color.white.opacity(0.05)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            isSelected ? Color(hex: "#4169E1") : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            } else {
                VStack {
                    Spacer()
                    Text("Member not found")
                        .foregroundColor(.white)
                    Spacer()
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#1A2245"))
        .onAppear {
            if membersViewModel.members.isEmpty || !membersViewModel.members.contains(where: { $0.id == selectedRaterId }) {
                membersViewModel.fetchMembersDetails(for: competition)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateSuggestedAmounts() -> [Int] {
        return [10, 25, 50]
    }
    
    private func fetchUserCoins() {
        guard let currentUser = Auth.auth().currentUser else {
            print("No authenticated user found")
            isLoadingCoins = false
            return
        }
        
        let db = Firestore.firestore()
        
        db.collection("competitions").document(competitionId).collection("members").document(currentUser.uid).getDocument { document, error in
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
                
                let data = document.data() ?? [:]
                
                if let coins = data["coins"] as? Int {
                    self.userCoins = coins
                } else {
                    print("Coins field not found or invalid type, defaulting to 0")
                    self.userCoins = 0
                }
                
                if let unclaimed = data["unclaimedRakeback"] as? Int {
                    self.unclaimedRakeback = unclaimed
                } else {
                    self.unclaimedRakeback = 0
                }
            }
        }
    }
    
    private func submitWithoutParlay() {
        guard !isUploading && !isUnlocking else { return }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            return
        }
        
        isUploading = true
        uploadProgress = 0.0
        
        let config = pricingCalculator.getCurrentConfig()
        
        EntryUploadManager.shared.uploadParlayEntry(
            image: image,
            competitionId: competitionId,
            userId: userId,
            overlayText: overlayText,
            overlayVerticalPosition: overlayVerticalPosition,
            isFromCamera: isFromCamera,
            themeId: selectedTheme?.id,
            themeName: selectedTheme?.name,
            competition: competition,
            entryCost: 0,
            predictions: [:],
            potentialPayout: 0,
            rakebackAmount: 0,
            rakebackPercentage: config.rakebackPercentage,
            effectiveHouseEdge: config.houseEdge,
            onProgress: { progress in
                self.uploadProgress = progress * 100
            },
            onSuccess: { entryId in
                self.fetchUploadedEntry(entryId: entryId, userId: userId)
            },
            onFailure: { error in
                print("Failed to upload entry: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isUploading = false
                }
            }
        )
    }
    
    private func placeParlayBet() {
        guard userCoins >= entryCost && !selectedPredictions.isEmpty && entryCost > 0 && !isUnlocking else { return }
        
        isUnlocking = true
        
        guard let currentUser = Auth.auth().currentUser else {
            print("No authenticated user found")
            isUnlocking = false
            return
        }
        
        let db = Firestore.firestore()
        
        let memberDocRef = db.collection("competitions").document(competitionId).collection("members").document(currentUser.uid)
        
        let rakebackEarned = pricingCalculator.calculateRakeback(entryCost: entryCost)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let memberDoc: DocumentSnapshot
            do {
                try memberDoc = transaction.getDocument(memberDocRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let data = memberDoc.data() else {
                let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Member document does not exist"])
                errorPointer?.pointee = error
                return nil
            }
            
            let currentCoins = data["coins"] as? Int ?? 0
            let currentUnclaimedRakeback = data["unclaimedRakeback"] as? Int ?? 0
            let currentTotalRakeback = data["totalRakebackEarned"] as? Int ?? 0
            
            let newCoins = currentCoins - self.entryCost
            let newUnclaimedRakeback = currentUnclaimedRakeback + rakebackEarned
            let newTotalRakeback = currentTotalRakeback + rakebackEarned
            
            var updates: [String: Any] = ["coins": newCoins]
            
            if rakebackEarned > 0 {
                updates["unclaimedRakeback"] = newUnclaimedRakeback
                updates["totalRakebackEarned"] = newTotalRakeback
            }
            
            transaction.updateData(updates, forDocument: memberDocRef)
            
            return nil
        }) { (object, error) in
            DispatchQueue.main.async {
                self.isUnlocking = false
                
                if let error = error {
                    print("Error in bet placement transaction: \(error)")
                    Analytics.shared.trackError(
                        message: "Parlay bet coin deduction failed",
                        properties: ["error": error.localizedDescription]
                    )
                    return
                }
                
                self.userCoins -= self.entryCost
                
                Analytics.shared.track(
                    event: "parlay_bet_placed",
                    properties: [
                        "stake": self.entryCost,
                        "predictions_count": self.selectedPredictions.count,
                        "potential_payout": self.estimatedPayout,
                        "multiplier": self.parlayMultiplier,
                        "rakeback_earned": rakebackEarned
                    ]
                )
                
                if rakebackEarned > 0 {
                    print("💰 Rakeback earned: \(rakebackEarned) coins")
                }
                
                self.unlockSuccessful = true
                self.uploadEntryAfterBet()
            }
        }
    }
    
    private func uploadEntryAfterBet() {
        guard !isUploading else { return }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            return
        }
        
        isUploading = true
        uploadProgress = 0.0
        
        let rakebackEarned = pricingCalculator.calculateRakeback(entryCost: entryCost)
        let config = pricingCalculator.getCurrentConfig()
        let effectiveHouseEdge = config.houseEdge - (config.houseEdge * config.rakebackPercentage)
                
        EntryUploadManager.shared.uploadParlayEntry(
            image: image,
            competitionId: competitionId,
            userId: userId,
            overlayText: overlayText,
            overlayVerticalPosition: overlayVerticalPosition,
            isFromCamera: isFromCamera,
            themeId: selectedTheme?.id,
            themeName: selectedTheme?.name,
            competition: competition,
            entryCost: entryCost,
            predictions: selectedPredictions,
            potentialPayout: estimatedPayout,
            rakebackAmount: rakebackEarned,
            rakebackPercentage: config.rakebackPercentage,
            effectiveHouseEdge: effectiveHouseEdge,
            onProgress: { progress in
                self.uploadProgress = progress * 100
            },
            onSuccess: { entryId in
                self.fetchUploadedEntry(entryId: entryId, userId: userId)
            },
            onFailure: { error in
                print("Failed to upload parlay entry: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isUploading = false
                }
            }
        )
    }
    
    private func fetchCurrentUserProfilePicture() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(userId).getDocument { document, error in
            if let data = document?.data(),
               let profileUrl = data["profilePictureUrl"] as? String {
                DispatchQueue.main.async {
                    self.currentUserProfilePictureUrl = profileUrl
                }
            }
        }
    }
    
    // Fetch the uploaded entry from Firestore and convert to UserPhoto
    private func fetchUploadedEntry(entryId: String, userId: String) {
        let entryRef = db.collection("competitions").document(competitionId).collection("entries").document(entryId)
        
        entryRef.getDocument(completion: { document, error in
            let workItem = DispatchWorkItem {
                self.isUploading = false
                
                if let error = error {
                    print("Error fetching uploaded entry: \(error)")
                    self.shouldDismissCameraFlow = true
                    return
                }
                
                guard let data = document?.data() else {
                    print("No data in uploaded entry")
                    self.shouldDismissCameraFlow = true
                    return
                }
                
                // Convert Firestore data to UserPhoto
                let photo = UserPhoto(
                    id: entryId,
                    photoUrl: data["imageUrl"] as? String ?? "",
                    stars: data["stars"] as? Int ?? 0,
                    isSuperstar: data["stars"] as? Int ?? 0 >= 4,
                    creationDate: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                    themeName: data["themeName"] as? String,
                    themeId: data["themeId"] as? String,
                    overlayText: data["overlayText"] as? String,
                    overlayVerticalPosition: data["overlayVerticalPosition"] as? CGFloat ?? 0.5,
                    isFromCamera: data["isFromCamera"] as? Bool ?? self.isFromCamera,
                    userId: userId,
                    parlayStatus: data["parlayStatus"] as? String,
                    parlayPredictions: data["predictions"] as? [String: Any],
                    parlayPayout: data["potentialPayout"] as? Int,
                    parlayStake: data["entryCost"] as? Int
                )
                
                // Store the photo and show full screen view
                self.uploadedPhoto = photo
                self.showingUploadedPhoto = true
            }
            
            DispatchQueue.main.async(execute: workItem)
        })
    }
}
