import SwiftUI
import Kingfisher
import FirebaseAuth
import FirebaseFirestore

extension Notification.Name {
    static let showUserPhotosAfterUpload = Notification.Name("showUserPhotosAfterUpload")
}

struct FullScreenPhotoView: View {
    let photo: UserPhoto
    let userName: String
    let competitionId: String?
    let userProfilePictureUrl: String?
    @Environment(\.dismiss) private var dismiss

    @State private var currentStarCount: Int
    @State private var spinResults: [SlotMachineUtils.SpinResult] = []
    @State private var isSpinning: Bool = false
    @State private var hasStartedSpinning: Bool = false
    @State private var spinsRemaining: Int = 3
    @State private var selectedRatingIndex: Int? = nil
    @State private var hasAlreadyVoted: Bool = false
    @State private var isLoadingSpinState: Bool = false
    @State private var isEntryCreator = false
    @State private var parlayStatus: String? = nil
    @State private var parlayPredictions: [String: Any] = [:]
    @State private var parlayPayout: Int = 0
    @State private var parlayStake: Int = 0
    @State private var isLoadingParlayStatus = false
    @State private var pendingUsernamesCache: [String: String] = [:]
    @State private var pendingUserProfiles: [String: (username: String, profilePictureUrl: String?)] = [:]
    @State private var showingPredictionsView = false
    @StateObject private var interactionService = PhotoInteractionService()
    @State private var showingMessageComposer = false
    @StateObject private var chatViewModel: ChatViewModel
    let shouldShowUserPhotosOnBack: Bool
    @State private var isDismissing = false
    let onDismiss: ((Int) -> Void)?

    init(photo: UserPhoto, userName: String, competitionId: String?, userProfilePictureUrl: String? = nil, onDismiss: ((Int) -> Void)? = nil, shouldShowUserPhotosOnBack: Bool = false) {
        self.photo = photo; self.userName = userName; self.competitionId = competitionId
        self.userProfilePictureUrl = userProfilePictureUrl; self.onDismiss = onDismiss
        self._currentStarCount = State(initialValue: photo.stars)
        self._chatViewModel = StateObject(wrappedValue: ChatViewModel(competitionId: competitionId ?? ""))
        self.shouldShowUserPhotosOnBack = shouldShowUserPhotosOnBack
    }

    private let db = Firestore.firestore()

    var body: some View {
        ZStack {
            ZStack {
                GeometryReader { geometry in
                    PhotoMainImageView(photoUrl: photo.photoUrl, overlayText: photo.overlayText,
                        overlayVerticalPosition: photo.overlayVerticalPosition, isTransitioning: false,
                        slideDirection: .left, screenWidth: geometry.size.width)
                }
                VStack {
                    PhotoNavigationBar(onBack: { handleBackNavigation() }, userName: userName,
                        userProfilePictureUrl: userProfilePictureUrl, themeName: photo.themeName,
                        themeId: photo.themeId, competitionId: competitionId ?? "",
                        onMessage: { showingMessageComposer = true })
                    Spacer()
                }
                if isEntryCreator {
                    if parlayStatus != nil && parlayStake > 0 { entryCreatorBottomSheet }
                    else { alreadyVotedFooter }
                } else {
                    if hasAlreadyVoted { alreadyVotedFooter }
                    else { slotMachineFooter }
                }
            }
            if isDismissing { AppTheme.pageBackground.ignoresSafeArea() }
        }
        .background(AppTheme.pageBackground)
        .sheet(isPresented: $showingMessageComposer) {
            MessageComposerView(photo: photo, userName: userName, competitionId: competitionId ?? "", onSend: { message in sendPhotoMessage(text: message) })
        }
        .onAppear {
            checkVotingStatus()
            if let currentUserId = Auth.auth().currentUser?.uid { isEntryCreator = (photo.userId == currentUserId) }
            if let competitionId = competitionId {
                interactionService.loadRatingData(competitionId: competitionId, entryId: photo.id)
                interactionService.fetchInteractions(competitionId: competitionId, entryId: photo.id)
            }
            if isEntryCreator { loadParlayStatus() }
        }
    }

    private var alreadyVotedFooter: some View {
        UltraSmoothBottomSheet(minHeight: PhotoViewConstants.minHeight, midHeight: UIScreen.main.bounds.height * 0.35,
            maxHeight: PhotoViewConstants.maxHeight(withFooter: false), bottomPadding: 0) {
            VStack(spacing: 0) {
                VStack { RoundedRectangle(cornerRadius: 200).fill(AppTheme.divider).frame(width: 40, height: 5) }
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical)
                HStack {
                    Text("Ratings").font(.system(size: 16, weight: .bold)).foregroundColor(AppTheme.primaryText)
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.bottom, 12)
                ScrollView {
                    VStack(spacing: 0) {
                        let currentUserId = Auth.auth().currentUser?.uid
                        let sorted = interactionService.interactions.sorted { a, _ in a.userId == currentUserId }
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { index, interaction in
                            let isCurrentUser = interaction.userId == currentUserId
                            HStack(spacing: 15) {
                                ProfilePictureView(url: interaction.profilePictureUrl, size: 40)
                                Text(isCurrentUser ? "Me" : interaction.userName).font(.system(size: 16, weight: .bold))
                                    .truncationMode(.tail).foregroundColor(AppTheme.primaryText).lineLimit(1)
                                Spacer()
                                HStack(spacing: 8) {
                                    Text("\(interaction.rating)").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                                    Image(systemName: "star.fill").resizable().scaledToFit().frame(width: 18, height: 18).foregroundColor(.white)
                                }
                                .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                                .background(AppTheme.gold).cornerRadius(200)
                            }
                            .padding(.horizontal, 20).padding(.vertical, 14)
                            if index < sorted.count - 1 { Divider().background(AppTheme.divider).padding(.horizontal, 20) }
                        }
                    }
                }
                Spacer()
            }
        }
    }

    private var slotMachineFooter: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Text(instructionText).font(.system(size: 17, weight: .semibold)).foregroundColor(AppTheme.primaryText).multilineTextAlignment(.center)
                HStack(spacing: 15) { ForEach(0..<3, id: \.self) { index in spinSlotView(index: index) } }.frame(minHeight: 70)
                Button(action: handleSpin) {
                    Text(spinButtonText).font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 56)
                    .background(spinButtonColor).cornerRadius(200)
                }
                .disabled(!canSpin)
            }
            .padding(20).padding(.bottom, 20)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedCorner(radius: 20, corners: [.topLeft, .topRight]))
            .background(VStack(spacing: 0) { Color.clear.frame(height: 20); AppTheme.cardBackground })
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func spinSlotView(index: Int) -> some View {
        Button(action: {
            if hasStartedSpinning && !isSpinning && selectedRatingIndex == nil && spinsRemaining == 0 { handleSelectRating(index: index) }
        }) {
            VStack(spacing: 2) {
                if index < spinResults.count {
                    let result = spinResults[index]
                    Text("\(result.stars)").font(.system(size: 24, weight: .bold)).foregroundColor(AppTheme.primaryText)
                    Image(systemName: "star.fill").font(.system(size: 14)).foregroundColor(AppTheme.gold)
                } else { Text("").font(.system(size: 24, weight: .bold)) }
            }
            .frame(width: 60, height: 60).background(slotBackgroundColor(index: index)).cornerRadius(5)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(slotBorderColor(index: index), lineWidth: selectedRatingIndex == index ? 2 : 0))
            .scaleEffect(selectedRatingIndex == index ? 1.1 : 1.0).animation(.easeInOut(duration: 0.3), value: selectedRatingIndex)
        }
        .disabled(!hasStartedSpinning || isSpinning || selectedRatingIndex != nil || spinsRemaining > 0)
    }

    private var instructionText: String {
        if isLoadingSpinState { return "Loading..." } else if !hasStartedSpinning { return "Tap spin" }
        else if isSpinning { return "Spinning..." } else if selectedRatingIndex != nil { return "Submitting..." }
        else if hasStartedSpinning && spinsRemaining == 0 { return "Pick a rating" } else { return "Submitting..." }
    }
    private var spinButtonText: String { isSpinning ? "Spinning..." : "Spin" }
    private var spinButtonColor: Color { canSpin ? AppTheme.accent : AppTheme.disabledBackground }
    private var canSpin: Bool { !isSpinning && !isLoadingSpinState && spinsRemaining > 0 && !hasAlreadyVoted && userName != "Me" }
    private func slotBackgroundColor(index: Int) -> Color {
        hasStartedSpinning && spinsRemaining == 0 && selectedRatingIndex == nil ? AppTheme.cardHighlight : AppTheme.cardHighlight.opacity(0.6)
    }
    private func slotBorderColor(index: Int) -> Color {
        hasStartedSpinning && spinsRemaining == 0 && selectedRatingIndex == nil ? AppTheme.divider : .clear
    }

    private func handleSpin() {
        guard canSpin else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task { await performSequentialSpins() }
    }

    private func fetchMyPredictedRating(competitionId: String, userId: String) async -> Int? {
        return await withCheckedContinuation { continuation in
            db.collection("competitions").document(competitionId).collection("entries").document(photo.id)
                .getDocument { document, _ in
                    guard let predictions = document?.data()?["predictions"] as? [String: Any],
                          let myPrediction = predictions[userId] as? [String: Any],
                          let predictedRating = myPrediction["predictedRating"] as? Int
                    else { continuation.resume(returning: nil); return }
                    continuation.resume(returning: predictedRating)
                }
        }
    }

    private func performSequentialSpins() async {
        isSpinning = true; hasStartedSpinning = true
        let totalToSpin = spinsRemaining; let startingIndex = 3 - spinsRemaining
        let guaranteedRating: Int; let guaranteedSlot: Int
        if let competitionId = competitionId, let currentUserId = Auth.auth().currentUser?.uid,
           let prediction = await fetchMyPredictedRating(competitionId: competitionId, userId: currentUserId) {
            guaranteedRating = prediction
        } else { guaranteedRating = Int.random(in: 4...5) }
        guaranteedSlot = startingIndex + Int.random(in: 0..<totalToSpin)
        var usedRatings = spinResults.map { $0.stars }; usedRatings.append(guaranteedRating)
        for i in 0..<totalToSpin {
            let slotIndex = startingIndex + i; let isGuaranteedSlot = slotIndex == guaranteedSlot
            let finalResult = await runSingleSpin(slotIndex: slotIndex, usedRatings: isGuaranteedSlot ? [] : usedRatings, forcedRating: isGuaranteedSlot ? guaranteedRating : nil)
            if !isGuaranteedSlot { usedRatings.append(finalResult.stars) }
            await MainActor.run { spinsRemaining -= 1 }
            if i < totalToSpin - 1 { try? await Task.sleep(nanoseconds: 600_000_000) }
        }
        saveSpinState(); isSpinning = false
    }

    private func runSingleSpin(slotIndex: Int, usedRatings: [Int], forcedRating: Int? = nil) async -> SlotMachineUtils.SpinResult {
        var spinCount = 0
        while spinCount < 10 {
            let tempResult = SlotMachineUtils.SpinResult(stars: Int.random(in: 1...5), multiplier: 1, points: 0)
            await MainActor.run {
                if slotIndex < spinResults.count { spinResults[slotIndex] = tempResult } else { spinResults.append(tempResult) }
            }
            try? await Task.sleep(nanoseconds: 100_000_000); spinCount += 1
        }
        var finalRating: Int
        if let forced = forcedRating { finalRating = forced }
        else { var attempts = 0; repeat { finalRating = Int.random(in: 1...5); attempts += 1 } while usedRatings.contains(finalRating) && attempts < 100 }
        let multiplier = SlotMachineUtils.getWeightedMultiplier()
        let finalResult = SlotMachineUtils.SpinResult(stars: finalRating, multiplier: multiplier, points: SlotMachineUtils.calculatePoints(stars: finalRating, multiplier: multiplier))
        await MainActor.run {
            if slotIndex < spinResults.count { spinResults[slotIndex] = finalResult } else { spinResults.append(finalResult) }
        }
        return finalResult
    }

    private func handleSelectRating(index: Int) {
        guard index < spinResults.count, selectedRatingIndex == nil else { return }
        selectedRatingIndex = index
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.submitRating(stars: self.spinResults[index].stars) }
    }

    private var entryCreatorBottomSheet: some View {
        UltraSmoothBottomSheet(minHeight: PhotoViewConstants.minHeight, midHeight: UIScreen.main.bounds.height * 0.5,
            maxHeight: PhotoViewConstants.maxHeight(withFooter: false), bottomPadding: 0) {
            VStack(spacing: 0) {
                VStack { RoundedRectangle(cornerRadius: 200).fill(AppTheme.divider).frame(width: 40, height: 5) }
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical)
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 12) {
                            HStack {
                                Text("My Predictions").font(.system(size: 16, weight: .bold)).foregroundColor(AppTheme.primaryText)
                                Spacer()
                                parlayStatusBadge
                            }
                            .padding(.bottom, 8)
                            if parlayStatus == "pending" { parlayProgressViewInline }
                            else if parlayStatus == "won" { parlayWonViewInline }
                            else if parlayStatus == "lost" { parlayLostViewInline }
                            let predictedUserIds = Set(parlayPredictions.keys)
                            let otherRatings = interactionService.interactions.filter { !predictedUserIds.contains($0.userId) }
                            if !otherRatings.isEmpty {
                                VStack(spacing: 0) {
                                    Divider().background(AppTheme.divider).padding(.bottom, 12)
                                    HStack {
                                        Text("Other Ratings (\(otherRatings.count))").foregroundColor(AppTheme.primaryText)
                                            .font(.system(size: 15, weight: .bold)).padding(.top, 5).padding(.bottom, 10)
                                        Spacer()
                                    }
                                    VStack(spacing: 0) {
                                        ForEach(otherRatings) { interaction in
                                            VStack(spacing: 0) {
                                                HStack(spacing: 5) {
                                                    ProfilePictureView(url: interaction.profilePictureUrl, size: 36)
                                                    Text(interaction.userName).font(.system(size: 15, weight: .semibold))
                                                        .foregroundColor(AppTheme.primaryText).lineLimit(1).padding(.leading, 10)
                                                    Spacer()
                                                    HStack(spacing: 6) {
                                                        Text("\(interaction.rating)").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                                                        Image(systemName: "star.fill").resizable().frame(width: 15, height: 15).foregroundColor(.white)
                                                    }
                                                    .padding(.horizontal, 10).padding(.vertical, 5).background(AppTheme.gold).cornerRadius(20)
                                                }
                                                .padding(.horizontal, 0).padding(.vertical, 15)
                                                if interaction.id != otherRatings.last?.id { Divider().background(AppTheme.divider) }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding().background(AppTheme.cardHighlight).cornerRadius(12).padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func handleBackNavigation() {
        if shouldShowUserPhotosOnBack {
            isDismissing = true
            NotificationCenter.default.post(name: .dismissCameraFlow, object: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.dismiss() }
        } else { onDismiss?(currentStarCount); dismiss() }
    }

    private var parlayStatusBadge: some View {
        HStack(spacing: 6) {
            Circle().fill(parlayStatusColor).frame(width: 8, height: 8)
            Text(parlayStatusText).font(.system(size: 14, weight: .bold)).foregroundColor(parlayStatusColor)
        }
        .padding(.horizontal, 12).padding(.vertical, 6).background(parlayStatusColor.opacity(0.15)).cornerRadius(20)
    }

    private var parlayStatusColor: Color {
        switch parlayStatus { case "won": return AppTheme.green; case "lost": return .red; default: return AppTheme.gold }
    }
    private var parlayStatusText: String {
        switch parlayStatus { case "won": return "Win"; case "lost": return "Lost"; default: return "In Progress" }
    }

    private var parlayProgressViewInline: some View {
        VStack(spacing: 8) {
            predictionsList
            Divider().background(AppTheme.divider).padding(.vertical, 5)
            parlayStatsRows(showWin: true)
        }
    }
    private var parlayWonViewInline: some View {
        VStack(spacing: 8) {
            predictionsList
            Divider().background(AppTheme.divider).padding(.vertical, 5)
            parlayStatsRows(showWin: true)
        }
    }
    private var parlayLostViewInline: some View {
        VStack(spacing: 8) {
            predictionsList
            Divider().background(AppTheme.divider).padding(.vertical, 5)
            VStack(spacing: 8) {
                parlayStatRow(label: "Entry", value: "\(parlayStake)")
                parlayStatRow(label: "Win", value: "0")
            }
        }
    }

    private func parlayStatsRows(showWin: Bool) -> some View {
        VStack(spacing: 8) {
            parlayStatRow(label: "Entry", value: "\(parlayStake)")
            parlayStatRow(label: showWin ? "To Win" : "Win", value: "\(parlayPayout)")
            let profit = parlayPayout - parlayStake
            if profit > 0 {
                HStack {
                    Text("Profit").font(.system(size: 15, weight: .semibold)).foregroundColor(AppTheme.secondaryText)
                    Spacer()
                    Text("+\(profit)").font(.system(size: 18, weight: .bold)).foregroundColor(AppTheme.green)
                }
            }
        }
    }

    private func parlayStatRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 15, weight: .semibold)).foregroundColor(AppTheme.secondaryText)
            Spacer()
            HStack(spacing: 6) {
                Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(AppTheme.primaryText)
                Image("coin").resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20)
            }
        }
    }

    private var predictionsList: some View {
        VStack(spacing: 0) {
            if !parlayPredictions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(parlayPredictions.keys.sorted()), id: \.self) { userId in
                        predictionRow(for: userId)
                        if userId != Array(parlayPredictions.keys.sorted()).last { Divider().background(AppTheme.divider).padding(.leading, 50) }
                    }
                }
            }
        }
    }

    private func predictionRow(for userId: String) -> some View {
        guard let predictionData = parlayPredictions[userId] as? [String: Any],
              let predictedRating = predictionData["predictedRating"] as? Int else { return AnyView(EmptyView()) }
        let actualRating = predictionData["actualRating"] as? Int
        let isCorrect = predictionData["correct"] as? Bool ?? false
        let interaction = interactionService.interactions.first { $0.userId == userId }
        let userName: String; let profilePictureUrl: String?
        if let interaction = interaction { userName = interaction.userName; profilePictureUrl = interaction.profilePictureUrl }
        else if let cachedProfile = pendingUserProfiles[userId] { userName = cachedProfile.username; profilePictureUrl = cachedProfile.profilePictureUrl }
        else { userName = "Friend"; profilePictureUrl = nil; fetchUserProfileForPendingUser(userId: userId) }
        return AnyView(
            HStack(spacing: 12) {
                ProfilePictureView(url: profilePictureUrl, size: 36)
                VStack(alignment: .leading, spacing: 5) {
                    Text(userName).font(.system(size: 15, weight: .semibold)).foregroundColor(AppTheme.primaryText).lineLimit(1)
                    if let actualRating = actualRating {
                        HStack(alignment: .center, spacing: 0) {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill").font(.system(size: 12)).foregroundColor(.white)
                                Text("\(predictedRating)").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                            }
                            .frame(height: 28).padding(.horizontal, 8)
                            .background((isCorrect ? AppTheme.green : Color.red)
                                .clipShape(RoundedCorner(radius: 6, corners: isCorrect ? [.topLeft, .bottomLeft, .topRight, .bottomRight] : [.topLeft, .bottomLeft])))
                            if !isCorrect {
                                HStack(spacing: 4) { Text("\(actualRating)").font(.system(size: 14, weight: .bold)).foregroundColor(AppTheme.secondaryText) }
                                    .frame(height: 28).padding(.horizontal, 8)
                                    .background(AppTheme.buttonBackground.clipShape(RoundedCorner(radius: 6, corners: [.topRight, .bottomRight])))
                            }
                        }
                    } else {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill").font(.system(size: 12)).foregroundColor(.white)
                            Text("\(predictedRating)").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        }
                        .frame(height: 28).padding(.horizontal, 8)
                        .background(AppTheme.gold.clipShape(RoundedCorner(radius: 6, corners: [.topLeft, .bottomLeft, .topRight, .bottomRight])))
                    }
                }
                Spacer()
                if actualRating != nil {
                    Text(isCorrect ? "✓" : "✗").font(.system(size: 17, weight: .bold)).foregroundColor(isCorrect ? AppTheme.green : .red)
                } else {
                    Image(systemName: "clock.fill").font(.system(size: 17)).foregroundColor(AppTheme.gold)
                }
            }
            .padding(.vertical, 8)
        )
    }

    private func fetchUserProfileForPendingUser(userId: String) {
        guard pendingUserProfiles[userId] == nil else { return }
        db.collection("users").document(userId).getDocument { document, error in
            if let data = document?.data(), let name = data["name"] as? String {
                let profilePictureUrl = data["profilePictureUrl"] as? String
                DispatchQueue.main.async { self.pendingUserProfiles[userId] = (username: name, profilePictureUrl: profilePictureUrl) }
            }
        }
    }

    private func loadParlayStatus() {
        guard let competitionId = competitionId else { return }
        isLoadingParlayStatus = true
        db.collection("competitions").document(competitionId).collection("entries").document(photo.id).getDocument { document, error in
            DispatchQueue.main.async {
                self.isLoadingParlayStatus = false
                guard let data = document?.data() else { return }
                self.parlayStatus = data["parlayStatus"] as? String
                self.parlayPredictions = data["predictions"] as? [String: Any] ?? [:]
                self.parlayPayout = data["potentialPayout"] as? Int ?? 0
                self.parlayStake = data["entryCost"] as? Int ?? 0
                for userId in self.parlayPredictions.keys {
                    if !self.interactionService.interactions.contains(where: { $0.userId == userId }) { self.fetchUserProfileForPendingUser(userId: userId) }
                }
            }
        }
    }

    private func sendPhotoMessage(text: String) {
        chatViewModel.sendPhotoMessage(photo: photo, text: text)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if let userId = Auth.auth().currentUser?.uid, let competitionId = competitionId {
            let competitionRef = db.collection("competitions").document(competitionId)
            let userRef = db.collection("users").document(userId)
            let group = DispatchGroup()
            var competitionDescription = "Competition"; var username = "Someone"
            group.enter(); competitionRef.getDocument { compDoc, _ in competitionDescription = compDoc?.data()?["description"] as? String ?? "Competition"; group.leave() }
            group.enter(); userRef.getDocument { userDoc, _ in username = userDoc?.data()?["name"] as? String ?? "Someone"; group.leave() }
            group.notify(queue: .main) {
                NotificationQueueManager.shared.queueGroupNotification(competitionId: competitionId, title: competitionDescription, body: "\(username) sent a message", senderId: userId, excludeUsers: [userId])
                NotificationQueueManager.shared.processQueuedNotifications()
            }
        }
    }

    private func checkVotingStatus() {
        guard let currentUserId = Auth.auth().currentUser?.uid, let competitionId = competitionId, userName != "Me" else { return }
        db.collection("groupMemberships").document(currentUserId).collection("competitions").document(competitionId).collection("votes").document(photo.id)
            .getDocument { document, error in
                DispatchQueue.main.async {
                    self.hasAlreadyVoted = document?.exists ?? false
                    if !self.hasAlreadyVoted { self.loadSpinState() }
                }
            }
    }

    private func loadSpinState() {
        guard let competitionId = competitionId, userName != "Me" else { return }
        isLoadingSpinState = true
        SpinStateManager.shared.loadSpinState(competitionId: competitionId, entryId: photo.id) { savedResults in
            DispatchQueue.main.async {
                self.isLoadingSpinState = false
                if !savedResults.isEmpty { self.spinResults = savedResults; self.hasStartedSpinning = true; self.spinsRemaining = max(0, 3 - savedResults.count) }
            }
        }
    }

    private func saveSpinState() {
        guard let competitionId = competitionId else { return }
        SpinStateManager.shared.saveSpinState(competitionId: competitionId, entryId: photo.id, spinResults: spinResults) { success in
            if !success { print("Failed to save spin state for photo \(photo.id)") }
        }
    }

    private func submitRating(stars: Int) {
        guard let competitionId = competitionId, let currentUserId = Auth.auth().currentUser?.uid, !hasAlreadyVoted else { return }
        Analytics.shared.trackEntry(action: "rate", entryId: photo.id, competitionId: competitionId, properties: ["rating": stars, "location": "fullscreen_view"])
        ParlayManager.shared.handleRating(competitionId: competitionId, entryId: photo.id, userId: currentUserId, rating: stars) { [self] success in
            DispatchQueue.main.async {
                if success {
                    self.currentStarCount += stars
                    RaceManager.shared.handleRatingReceived(competitionId: competitionId, photoOwnerId: photo.userId, stars: stars) { _ in }
                    if self.isEntryCreator { self.loadParlayStatus() }
                    self.interactionService.submitRating(competitionId: competitionId, entryId: self.photo.id, rating: stars, points: 0) { interactionSuccess in
                        if interactionSuccess {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.interactionService.fetchInteractions(competitionId: competitionId, entryId: self.photo.id) }
                        }
                    }
                    self.hasAlreadyVoted = true
                } else {
                    self.selectedRatingIndex = nil; self.spinResults = []; self.hasStartedSpinning = false; self.spinsRemaining = 3
                }
            }
        }
    }
}
