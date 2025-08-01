import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct UnlockView: View {
    @StateObject private var payViewModel = PayViewModel()
    @State private var shouldDismissCameraFlow = false
    @State private var userCoins: Int = 0
    @State private var isLoadingCoins = true
    @State private var showPayView = false
    @State private var unlockSuccessful = false
    @State private var isUnlocking = false
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0.0
    @State private var isLoadingGroupSize = false
    @State private var customStakeAmount: String = "" // Changed: Start with empty string
    @State private var showStakeEditor: Bool = false
    @StateObject private var membersViewModel = MembersViewModel()
    
    // Parlay betting state
    @State private var selectedPredictions: [String: Int] = [:]
    @State private var showPredictionSelector = false
    @State private var selectedRaterId = ""
    
    private var entryCost: Int {
        if !customStakeAmount.isEmpty, let customAmount = Int(customStakeAmount), customAmount > 0 {
            return customAmount
        }
        return 0 // Changed: Return 0 when no amount is set
    }
    
    private var estimatedPayout: Int {
        guard !selectedPredictions.isEmpty && entryCost > 0 else { return 0 } // Added entryCost > 0 check
        return CompetitionPricingCalculator.shared.calculateParlayPayout(
            entryCost: entryCost,
            predictions: selectedPredictions
        )
    }
    
    private var parlayMultiplier: Double {
        guard !selectedPredictions.isEmpty else { return 0 }
        return CompetitionPricingCalculator.shared.getParlayMultiplier(
            numberOfPredictions: selectedPredictions.count
        )
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
    
    init(competition: Competition, competitionId: String, image: UIImage, overlayText: String, overlayVerticalPosition: CGFloat, isFromCamera: Bool, selectedTheme: Theme?) {
        self.competition = competition
        self.competitionId = competitionId
        self.image = image
        self.overlayText = overlayText
        self.overlayVerticalPosition = overlayVerticalPosition
        self.isFromCamera = isFromCamera
        self.selectedTheme = selectedTheme
        
        // Removed: Default value initialization
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
                    // Always refresh data when sheet appears
                    membersViewModel.fetchMembersDetails(for: competition)
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
        ZStack {
            HStack {
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
                
                Text("Balance")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.trailing, 5)
                
                Button(action: {
                    showPayView = true
                    Analytics.shared.track(event: "coins_button_tapped")
                }) {
                    HStack(spacing: 5) {
                        Image("coin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                        
                        if isLoadingCoins {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("\(userCoins)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Image(systemName: "plus.circle")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        (!isLoadingCoins && entryCost > 0 && userCoins < entryCost)
                            ? Color(hex: "#F85149").opacity(0.3)
                            : Color(hex: "#2A3255")
                    )
                    .cornerRadius(200)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color(hex: "#1A2245"))
    }
    
    private var parlayBettingView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                // Predictions Section (now first)
                predictionsSection
                
                stakeSectionView
                
                payoutSection
                
                // Submit Button
                submitButtonView
                
                // Insufficient Coins Warning
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
                            .frame(width: 16, height: 16)
                        
                        // Changed: Show placeholder text when no amount is set
                        if entryCost > 0 {
                            Text("\(entryCost)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        } else {
                            Text("Set Amount")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(!selectedPredictions.isEmpty ? .white : .white.opacity(0.7))
                        }
                        
                        Image("pencil")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(!selectedPredictions.isEmpty ? .white : .white.opacity(0.7))
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 15, height: 15)
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
            
            if availableRaters.isEmpty {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack {
                    Text("Make Your Predictions")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
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
                
                if let rating = selectedRating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 15))
                                .foregroundColor(star <= rating ? Color(hex: "#FFD700") : Color.white.opacity(0.3))
                        }
                    }
                } else {
                    Text("Tap to predict")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
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
            
            // Multiplier Display
            HStack {
                Text("Multiplier")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Text("\(String(format: "%.1fx", parlayMultiplier))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Potential Payout
            HStack {
                Text("To Win")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                HStack(spacing: 6) {
                    Text("\(estimatedPayout)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Image("coin")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                }
            }
            
            // Profit Display
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
            
            // Win Probability - removed as it's not accurate without friend behavior data
        }
    }
    
    private var submitButtonView: some View {
        // Changed: Now requires both predictions and stake amount
        let canSubmit = userCoins >= entryCost && !selectedPredictions.isEmpty && entryCost > 0 && !isLoadingCoins && !isUnlocking
        
        // Changed: Better button text logic
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
            // Header
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
            
            // Amount Display
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
                
                // Quick Select Amounts
                let suggestedAmounts = generateSuggestedAmounts()
                
                HStack(spacing: 0) {
                    ForEach(suggestedAmounts, id: \.self) { amount in
                        Button(action: {
                            customStakeAmount = String(amount)
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
            
            // Custom Number Pad
            VStack(spacing: 1) {
                // Row 1: 1, 2, 3
                HStack(spacing: 1) {
                    ForEach(1...3, id: \.self) { number in
                        NumberPadButton(number: "\(number)") {
                            appendNumber("\(number)")
                        }
                    }
                }
                
                // Row 2: 4, 5, 6
                HStack(spacing: 1) {
                    ForEach(4...6, id: \.self) { number in
                        NumberPadButton(number: "\(number)") {
                            appendNumber("\(number)")
                        }
                    }
                }
                
                // Row 3: 7, 8, 9
                HStack(spacing: 1) {
                    ForEach(7...9, id: \.self) { number in
                        NumberPadButton(number: "\(number)") {
                            appendNumber("\(number)")
                        }
                    }
                }
                
                // Row 4: Clear, 0, Backspace
                HStack(spacing: 1) {
                    // Clear Button
                    Button(action: {
                        clearAmount()
                    }) {
                        Text("C")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.white.opacity(0.1))
                    }
                    
                    // Zero Button
                    NumberPadButton(number: "0") {
                        appendNumber("0")
                    }
                    
                    // Backspace Button
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
        .ignoresSafeArea(.keyboard) // Add this to handle keyboard if needed
    }

    // Custom Number Button Component
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

    // Helper Methods (add these to your view or view model)
    private func appendNumber(_ digit: String) {
        // Prevent leading zeros and limit reasonable length
        if customStakeAmount == "0" {
            customStakeAmount = digit
        } else if customStakeAmount.count < 8 { // Reasonable limit for betting amounts
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
            // Header remains the same
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
            
            // Content area with loading states
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
                            .lineLimit(1)
                    }
                    
                    VStack(spacing: 16) {
                        ForEach((1...5).reversed(), id: \.self) { rating in
                            let isSelected = selectedPredictions[selectedRaterId] == rating
                            
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
                                            Image(systemName: star <= rating ? "star.fill" : "star")
                                                .font(.system(size: 20))
                                                .foregroundColor(star <= rating ? Color(hex: "#FFD700") : Color.white.opacity(0.3))
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(rating) Star\(rating == 1 ? "" : "s")")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
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
                
                if let coins = document.data()?["coins"] as? Int {
                    self.userCoins = coins
                } else {
                    print("Coins field not found or invalid type, defaulting to 0")
                    self.userCoins = 0
                }
            }
        }
    }
    
    // Removed: updateStakeAmountForNewGroupSize method since we don't auto-update
    
    private func placeParlayBet() {
        guard userCoins >= entryCost && !selectedPredictions.isEmpty && entryCost > 0 && !isUnlocking else { return } // Added entryCost > 0 check
        
        isUnlocking = true
        
        guard let currentUser = Auth.auth().currentUser else {
            print("No authenticated user found")
            isUnlocking = false
            return
        }
        
        let db = Firestore.firestore()
        
        let memberDocRef = db.collection("competitions").document(competitionId).collection("members").document(currentUser.uid)
        
        memberDocRef.updateData(["coins": userCoins - entryCost]) { error in
            DispatchQueue.main.async {
                self.isUnlocking = false
                
                if let error = error {
                    print("Error deducting coins: \(error)")
                    Analytics.shared.trackError(
                        message: "Parlay bet coin deduction failed",
                        properties: ["error": error.localizedDescription]
                    )
                    return
                }
                
                self.userCoins -= entryCost
                Analytics.shared.track(
                    event: "parlay_bet_placed",
                    properties: [
                        "stake": entryCost,
                        "predictions_count": selectedPredictions.count,
                        "potential_payout": estimatedPayout,
                        "multiplier": parlayMultiplier
                    ]
                )
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
            onProgress: { progress in
                self.uploadProgress = progress * 100
            },
            onSuccess: { entryId in
                DispatchQueue.main.async {
                    self.shouldDismissCameraFlow = true
                }
            },
            onFailure: { error in
                print("Failed to upload parlay entry: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isUploading = false
                }
            }
        )
    }
}
