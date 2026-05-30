import SwiftUI
import FirebaseAuth
import FirebaseFunctions

struct SessionView: View {

    let sessionId: String
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm: SessionViewModel
    @StateObject private var callManager = VoiceCallManager.shared

    private let currentUserId = Auth.auth().currentUser?.uid ?? ""
    @State private var showingWallet     = false
    @State private var showingCallSheet  = false

    init(sessionId: String) {
        self.sessionId = sessionId
        _vm = StateObject(wrappedValue: SessionViewModel(sessionId: sessionId))
    }

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            lobbyView

            cameraOverlay
        }
        .animation(.easeInOut(duration: 0.2), value: phaseKey)
        .animation(.easeInOut(duration: 0.2), value: cameraStepKey)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingWallet) {
            WalletView(onDismiss: { showingWallet = false })
        }
        .sheet(isPresented: $showingCallSheet) {
            CallSheet(
                sessionId: sessionId,
                sessionVM: vm,
                callManager: callManager,
                onHangUp: { showingCallSheet = false; hangUp() }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // Typed error alert — handles top-up prompt separately
        .alert(item: Binding(
            get: { vm.error },
            set: { if $0 == nil { vm.clearError() } }
        )) { error in
            if error.requiresTopUp {
                return Alert(
                    title: Text("Insufficient Balance"),
                    message: Text(error.errorDescription ?? ""),
                    primaryButton: .default(Text("Top Up")) { showingWallet = true },
                    secondaryButton: .cancel(Text("OK")) { vm.clearError() }
                )
            }
            return Alert(
                title: Text("Something went wrong"),
                message: Text(error.errorDescription ?? ""),
                dismissButton: .default(Text("OK")) { vm.clearError() }
            )
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "session")
            vm.start()
        }
        .onDisappear {
            vm.stopListening()
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Camera overlay
    // ─────────────────────────────────────────────────────────

    @ViewBuilder
    private var cameraOverlay: some View {
        switch vm.cameraStep {
        case .hidden:
            EmptyView()

        case .camera:
            RoundCameraView(
                onPhotoSelected: { image, isFromCamera in
                    vm.onPhotoSelected(image: image, isFromCamera: isFromCamera)
                },
                onCancel: { vm.onCameraCancel() }
            )
            .ignoresSafeArea()
            .transition(.opacity)
            .zIndex(1)

        case .preview(let image, let isFromCamera):
            RoundPhotoPreview(
                image: image,
                isFromCamera: isFromCamera,
                onConfirm: { confirmedImage in
                    vm.onPreviewConfirmed(image: confirmedImage, isFromCamera: isFromCamera)
                },
                onRetake: { vm.onPreviewRetake() }
            )
            .ignoresSafeArea()
            .transition(.opacity)
            .zIndex(1)

        case .entryFee(let image, let isFromCamera):
            EntryFeeSheet(
                image: image,
                isFromCamera: isFromCamera,
                sessionId: sessionId,
                onJoin: { photoUrl, fee in
                    vm.joinRound(photoUrl: photoUrl, entryFee: fee, isFromCamera: isFromCamera)
                },
                onCancel: { vm.onCameraCancel() }
            )
            .transition(.move(edge: .bottom))
            .zIndex(1)
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Lobby view
    // ─────────────────────────────────────────────────────────

    @ViewBuilder
    private var lobbyView: some View {
        switch vm.phase {
        case .judging:
            RoundJudgingView()
                .ignoresSafeArea()
                .transition(.opacity)

        case .results(let round, let submissions, let profiles):
            RoundResultsView(
                round: round,
                submissions: submissions,
                userProfiles: profiles,
                isCreatingRound: vm.isCreatingRound,
                onPlayAgain: {
                    Analytics.shared.trackTap(elementId: "play_again", screenName: "round_results")
                    vm.playAgain()
                },
                onDismiss: {
                    Analytics.shared.trackTap(elementId: "dismiss_results", screenName: "round_results")
                    vm.dismissResults()
                }
            )
            .transition(.opacity)

        default:
            mainLobbyContent
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Main lobby content
    // ─────────────────────────────────────────────────────────

    private var mainLobbyContent: some View {
        VStack(spacing: 0) {
            topBar

            potPill
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            GeometryReader { geo in
                let spacing:    CGFloat = 10
                let hPad:       CGFloat = 20
                let cardWidth   = (geo.size.width - hPad * 2 - spacing) / 2
                let imageHeight = cardWidth * 1.25

                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: spacing),
                            GridItem(.flexible(), spacing: spacing)
                        ],
                        spacing: spacing
                    ) {
                        if shouldShowJoinCard {
                            joinGridCard(width: cardWidth, imageHeight: imageHeight)
                        }

                        ForEach(orderedSubmissions, id: \.photoUrl) { submission in
                            SubmissionCard(
                                submission: submission,
                                profile: vm.profile(for: submission.userId),
                                isCurrentUser: submission.userId == currentUserId,
                                width: cardWidth,
                                imageHeight: imageHeight
                            )
                        }
                    }
                    .padding(.horizontal, hPad)
                    .padding(.bottom, 12)
                }
            }

            statusLabel.padding(.vertical, 6)

            bottomBar
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Top bar
    // ─────────────────────────────────────────────────────────

    private var topBar: some View {
        HStack {
            Button { showingWallet = true } label: {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppTheme.primaryText)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.cardBackground)
                    .clipShape(Circle())
            }

            Spacer()

            CallButton(
                participantCount: callManager.participants.count,
                isMuted: callManager.isMuted,
                anyoneSpeaking: callManager.participants.contains { $0.isSpeaking }
            ) {
                Analytics.shared.trackTap(elementId: "call_button", screenName: "session")
                showingCallSheet = true
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Pot pill
    // ─────────────────────────────────────────────────────────

    private var livePotTotal: Double {
        vm.submissions.reduce(0.0) { $0 + $1.entryFee }
    }

    @ViewBuilder
    private var potPill: some View {
        if livePotTotal > 0 {
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.green)
                Text("$\(String(format: "%.2f", livePotTotal)) in the pot")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AppTheme.cardBackground)
            .clipShape(Capsule())
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Join grid card
    // ─────────────────────────────────────────────────────────

    private func joinGridCard(width: CGFloat, imageHeight: CGFloat) -> some View {
        let isJoining: Bool = {
            if case .joining = vm.phase { return true }
            return false
        }()

        return Button {
            guard let round = vm.currentRound, round.isWaiting, !isJoining else { return }
            vm.openCamera()
        } label: {
            VStack(spacing: 10) {
                if isJoining {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accent))
                        .scaleEffect(1.2)
                    Text("Joining...")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(AppTheme.accent)
                    Text("Join Round")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                }
            }
            .frame(width: width, height: imageHeight)
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundColor(AppTheme.accent.opacity(0.4))
            )
        }
        .buttonStyle(.plain)
        .disabled(isJoining)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Computed helpers
    // ─────────────────────────────────────────────────────────

    private var shouldShowJoinCard: Bool {
        guard let round = vm.currentRound, round.isWaiting else { return false }
        switch vm.phase {
        case .lobby, .joining: return true
        default:               return false
        }
    }

    private var orderedSubmissions: [Submission] {
        let mine   = vm.submissions.filter { $0.userId == currentUserId }
        let others = vm.submissions.filter { $0.userId != currentUserId }
        return mine + others
    }

    private var statusLabel: some View {
        let count = vm.submissions.count
        let text: String = {
            switch vm.phase {
            case .idle:    return "Preparing round..."
            case .joining: return "Joining round..."
            default:
                if count == 0 { return "Waiting for players..." }
                if count == 1 { return "Waiting for 1 more..." }
                return "\(count) players ready"
            }
        }()
        return Text(text)
            .font(.system(size: 13))
            .foregroundColor(AppTheme.secondaryText)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Bottom bar
    // ─────────────────────────────────────────────────────────

    @ViewBuilder
    private var bottomBar: some View {
        if let round = vm.currentRound, round.isWaiting {
            HStack(spacing: 12) {
                if case .joined = vm.phase {
                    Button { vm.leaveRound() } label: {
                        Text(vm.isLeavingRound ? "Leaving..." : "Leave")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.secondaryText)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(AppTheme.cardBackground)
                            .cornerRadius(200)
                            .overlay(Capsule().stroke(AppTheme.divider, lineWidth: 1))
                    }
                    .disabled(vm.isLeavingRound)
                } else {
                    Color.clear.frame(width: 80, height: 46)
                }

                Spacer()

                Button { vm.startRound() } label: {
                    HStack(spacing: 6) {
                        if vm.isStartingRound {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(startButtonLabel)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(vm.canStart ? AppTheme.accent : AppTheme.disabledBackground)
                    .cornerRadius(200)
                }
                .disabled(!vm.canStart)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        } else if vm.isCreatingRound {
            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.secondaryText))
                    .scaleEffect(0.8)
                Text("Preparing round...")
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.secondaryText)
            }
            .padding(.bottom, 40)
        }
    }

    private var startButtonLabel: String {
        if vm.isStartingRound { return "Starting..." }
        let count = vm.submissions.count
        if count < 2 { return "Need \(2 - count) more" }
        return "Start Round"
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Keys for animation
    // ─────────────────────────────────────────────────────────

    private var phaseKey: String {
        switch vm.phase {
        case .idle:    return "idle"
        case .lobby:   return "lobby"
        case .joining: return "joining"
        case .joined:  return "joined"
        case .judging: return "judging"
        case .results: return "results"
        }
    }

    private var cameraStepKey: String {
        switch vm.cameraStep {
        case .hidden:   return "hidden"
        case .camera:   return "camera"
        case .preview:  return "preview"
        case .entryFee: return "entryFee"
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Hang up
    // ─────────────────────────────────────────────────────────

    private func hangUp() {
        Analytics.shared.trackTap(elementId: "hang_up", screenName: "session")
        CallKitManager.shared.endActiveCall(reason: .remoteEnded)
        VoiceCallManager.shared.leaveCall()
        Functions.functions().httpsCallable("endSession").call(["sessionId": sessionId]) { _, _ in }
        dismiss()
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - CallButton
// ─────────────────────────────────────────────────────────────

struct CallButton: View {
    let participantCount: Int
    let isMuted: Bool
    let anyoneSpeaking: Bool
    let action: () -> Void

    @State private var pulsing = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    if anyoneSpeaking {
                        Circle()
                            .stroke(AppTheme.green.opacity(0.5), lineWidth: 2)
                            .frame(width: 50, height: 50)
                            .scaleEffect(pulsing ? 1.25 : 1.0)
                            .opacity(pulsing ? 0.0 : 1.0)
                            .animation(
                                .easeOut(duration: 0.9).repeatForever(autoreverses: false),
                                value: pulsing
                            )
                    }

                    Circle()
                        .fill(anyoneSpeaking ? AppTheme.green.opacity(0.15) : AppTheme.cardBackground)
                        .frame(width: 44, height: 44)

                    Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 17))
                        .foregroundColor(isMuted ? .red : AppTheme.primaryText)
                }

                if participantCount > 0 {
                    Text("\(participantCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 17, height: 17)
                        .background(AppTheme.accent)
                        .clipShape(Circle())
                        .offset(x: 2, y: -2)
                }
            }
        }
        .onAppear { pulsing = true }
        .onChange(of: anyoneSpeaking) { speaking in
            if speaking { pulsing = true }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - CallSheet
// ─────────────────────────────────────────────────────────────

struct CallSheet: View {
    let sessionId: String
    @ObservedObject var sessionVM: SessionViewModel
    @ObservedObject var callManager: VoiceCallManager
    let onHangUp: () -> Void

    @State private var showingInviteMore = false

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("On this call")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(callManager.participants) { participant in
                            ParticipantBubble(participant: participant)
                        }

                        ForEach(sessionVM.pendingParticipantIds, id: \.self) { userId in
                            PendingParticipantBubble(
                                profile: sessionVM.profile(for: userId),
                                onRingAgain: { sessionVM.inviteMore(friendIds: [userId]) }
                            )
                        }

                        Button { showingInviteMore = true } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.cardBackground)
                                        .frame(width: 52, height: 52)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(
                                                    style: StrokeStyle(lineWidth: 1.5, dash: [5])
                                                )
                                                .foregroundColor(AppTheme.accent.opacity(0.5))
                                        )
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(AppTheme.accent)
                                }
                                Text("Add")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(AppTheme.secondaryText)
                            }
                            .frame(width: 60)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 90)

                Divider()
                    .background(AppTheme.divider)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)

                Button { callManager.toggleMute() } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(callManager.isMuted
                                      ? Color.red.opacity(0.12)
                                      : AppTheme.cardBackground)
                                .frame(width: 44, height: 44)
                            Image(systemName: callManager.isMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 18))
                                .foregroundColor(callManager.isMuted ? .red : AppTheme.primaryText)
                        }

                        Text(callManager.isMuted ? "Unmute" : "Mute")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.primaryText)

                        Spacer()

                        if callManager.isMuted {
                            Text("You're muted")
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onHangUp) {
                    HStack(spacing: 8) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("End Call")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .cornerRadius(200)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showingInviteMore) {
            InviteMoreSheet(sessionVM: sessionVM, isPresented: $showingInviteMore)
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - ParticipantBubble
// ─────────────────────────────────────────────────────────────

struct ParticipantBubble: View {
    let participant: CallParticipant

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                ProfilePictureView(url: participant.profilePictureUrl, size: 52)
                    .overlay(
                        Circle()
                            .stroke(
                                participant.isSpeaking ? AppTheme.green : Color.clear,
                                lineWidth: 2.5
                            )
                    )
                    .scaleEffect(participant.isSpeaking ? 1.06 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: participant.isSpeaking)

                if participant.isMuted {
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 2, y: 2)
                }
            }

            Text(participant.isCurrentUser ? "You" : participant.username)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.secondaryText)
                .lineLimit(1)
        }
        .frame(width: 60)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - PendingParticipantBubble
// ─────────────────────────────────────────────────────────────

struct PendingParticipantBubble: View {
    let profile: UserProfile?
    let onRingAgain: () -> Void

    @State private var pulsing = false

    var body: some View {
        Button(action: onRingAgain) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(AppTheme.accent.opacity(0.4), lineWidth: 2)
                        .frame(width: 56, height: 56)
                        .scaleEffect(pulsing ? 1.15 : 1.0)
                        .opacity(pulsing ? 0.0 : 0.6)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: false),
                            value: pulsing
                        )

                    ProfilePictureView(url: profile?.profilePictureUrl, size: 52)
                        .opacity(0.6)
                        .overlay(Circle().stroke(AppTheme.accent.opacity(0.5), lineWidth: 2))
                }

                Text(profile?.name ?? "...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(width: 60)
        }
        .buttonStyle(.plain)
        .onAppear { pulsing = true }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - InviteMoreSheet
// ─────────────────────────────────────────────────────────────

struct InviteMoreSheet: View {
    @ObservedObject var sessionVM: SessionViewModel
    @Binding var isPresented: Bool

    @StateObject private var friendsVM = FriendsViewModel()
    @State private var selectedIds: Set<String> = []

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.iconColor)
                    }
                    Spacer()
                    Text("Add to Call")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                    Spacer()
                    Color.clear.frame(width: 28, height: 28)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                if friendsVM.isLoading {
                    Spacer()
                    ProgressView().tint(AppTheme.primaryText)
                    Spacer()
                } else {
                    let available = friendsVM.friends.filter { !sessionVM.invitedIds.contains($0.id) }

                    if available.isEmpty {
                        Spacer()
                        Text("All your friends are already in the call")
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(available) { friend in
                                    FriendCell(
                                        friend: friend,
                                        isSelected: selectedIds.contains(friend.id),
                                        onTap: {
                                            if selectedIds.contains(friend.id) {
                                                selectedIds.remove(friend.id)
                                            } else {
                                                selectedIds.insert(friend.id)
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            }
                                        }
                                    )
                                    if friend.id != available.last?.id {
                                        Divider().background(AppTheme.divider)
                                    }
                                }
                            }
                            .background(AppTheme.cardBackground)
                            .cornerRadius(14)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        }
                    }
                }

                if !selectedIds.isEmpty {
                    Button {
                        sessionVM.inviteMore(friendIds: Array(selectedIds))
                        isPresented = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("Call \(selectedIds.count == 1 ? "1 Person" : "\(selectedIds.count) People")")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.accent)
                        .cornerRadius(200)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .padding(.top, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedIds.isEmpty)
        .onAppear { friendsVM.fetchFriends() }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - SubmissionCard
// ─────────────────────────────────────────────────────────────

struct SubmissionCard: View {
    let submission: Submission
    let profile: UserProfile?
    let isCurrentUser: Bool
    let width: CGFloat
    let imageHeight: CGFloat

    @State private var showingFullScreen = false

    var body: some View {
        Button { showingFullScreen = true } label: {
            ZStack(alignment: .topLeading) {
                AsyncImage(url: URL(string: submission.photoUrl)) { image in
                    image.resizable().scaledToFill()
                        .frame(width: width, height: imageHeight).clipped()
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.pageBackground)
                        .frame(width: width, height: imageHeight)
                        .overlay(ProgressView())
                }
                .id(submission.photoUrl) // force fresh view when URL changes (e.g. after leave + rejoin)

                // Gradient overlays
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.black.opacity(0.4), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: imageHeight * 0.35)
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.4)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: imageHeight * 0.35)
                }
                .frame(width: width, height: imageHeight)

                // Name top-left
                Text(isCurrentUser ? "You" : (profile?.name ?? "..."))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.top, 9)

                // Fee badge bottom-right
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(submission.entryFee > 0
                             ? "$\(String(format: "%.2f", submission.entryFee))"
                             : "Free")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(submission.entryFee > 0
                                        ? AppTheme.green
                                        : AppTheme.disabledBackground)
                            .cornerRadius(200)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 9)
                }
                .frame(width: width, height: imageHeight)
            }
            .frame(width: width, height: imageHeight)
            .cornerRadius(12)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showingFullScreen) {
            SubmissionFullScreenView(submission: submission)
        }
    }
}
