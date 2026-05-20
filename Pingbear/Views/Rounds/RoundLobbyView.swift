import SwiftUI
import FirebaseAuth

struct RoundLobbyView: View {

    @ObservedObject var roundViewModel: RoundViewModel
    let competition: Competition

    @State private var showingThemePicker = false
    @State private var showingPhotoPicker = false
    @State private var pendingImage: IdentifiableImage? = nil
    @State private var pendingEntryFee: Double = 1.00
    @State private var showingLeaveConfirm = false
    @State private var selectedSubmission: RoundSubmission? = nil

    // ── Call prompt ───────────────────────────────────────────
    @State private var showingCallPrompt = false
    @ObservedObject private var callManager: VoiceCallManager = VoiceCallManager.shared

    private let currentUserId = Auth.auth().currentUser?.uid ?? ""

    // Current user's submission always first, then others by join time
    private var orderedSubmissions: [RoundSubmission] {
        let mine = roundViewModel.sortedSubmissions.filter { $0.userId == currentUserId }
        let others = roundViewModel.sortedSubmissions.filter { $0.userId != currentUserId }
        return mine + others
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        // ── Outer VStack mirrors PingbearApp: pill pushes content down ──
        VStack(spacing: 0) {
            CallPillBanner()


            // ── ZStack: lobby content + dim + modal card ──────────
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea(edges: .bottom)

                VStack(spacing: 0) {

                    // ── Header ────────────────────────────────────
                    HStack(spacing: 12) {
                        Button(action: {
                            roundViewModel.dismissRoundCover()
                        }) {
                            Image(systemName: "arrow.left")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 27, height: 27)
                                .foregroundColor(AppTheme.iconColor)
                        }

                        // ── Theme + Pot pill ──────────────────────
                        Button(action: {
                            Analytics.shared.trackTap(
                                elementId: "change_theme",
                                screenName: "round_lobby"
                            )
                            showingThemePicker = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.primaryText)

                                Text(roundViewModel.roundInfo?.themeName ?? "")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(AppTheme.primaryText)
                                    .lineLimit(1)

                                Spacer()

                                Text(roundViewModel.totalPot > 0
                                     ? "$\(String(format: "%.2f", roundViewModel.totalPot))"
                                     : "$0")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.green)
                                    .clipShape(Capsule())
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(AppTheme.cardBackground)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 14)

                    // ── Photo grid ────────────────────────────────
                    GeometryReader { geo in
                        let spacing: CGFloat = 12
                        let hPadding: CGFloat = 20
                        let cardWidth = (geo.size.width - hPadding * 2 - spacing) / 2
                        let imageHeight = cardWidth * 1.25

                        ScrollView {
                            LazyVGrid(columns: columns, spacing: spacing) {
                                if !roundViewModel.currentUserIsInRound {
                                    joinCard(
                                        width: cardWidth,
                                        imageHeight: imageHeight
                                    )
                                }
                                ForEach(orderedSubmissions) { submission in
                                    submissionCard(
                                        submission: submission,
                                        width: cardWidth,
                                        imageHeight: imageHeight
                                    )
                                }
                            }
                            .padding(.horizontal, hPadding)
                            .padding(.bottom, 16)
                        }
                    }

                    // ── Player count / status ─────────────────────
                    Text(playerStatusText)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.secondaryText)
                        .padding(.vertical, 8)

                    // ── Action row ────────────────────────────────
                    HStack(spacing: 10) {

                        if roundViewModel.currentUserIsInRound {
                            Button(action: {
                                Analytics.shared.trackTap(
                                    elementId: "leave_round",
                                    screenName: "round_lobby"
                                )
                                showingLeaveConfirm = true
                            }) {
                                Text("Leave")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppTheme.secondaryText)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 13)
                                    .background(AppTheme.cardBackground)
                                    .cornerRadius(200)
                                    .overlay(Capsule().stroke(AppTheme.divider, lineWidth: 1))
                            }
                            .disabled(roundViewModel.isLeaving)
                        } else {
                            Color.clear.frame(width: 80, height: 46)
                        }

                        Spacer()

                        Button(action: {
                            Analytics.shared.trackTap(
                                elementId: "start_round",
                                screenName: "round_lobby"
                            )
                            roundViewModel.startRound { _ in }
                        }) {
                            HStack(spacing: 6) {
                                if roundViewModel.isStartingRound {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(startButtonLabel)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 13)
                            .background(roundViewModel.canStart
                                         ? AppTheme.accent
                                         : AppTheme.disabledBackground)
                            .cornerRadius(200)
                        }
                        .disabled(!roundViewModel.canStart)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }

                // ── Dim scrim ─────────────────────────────────────
                if showingCallPrompt {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            Analytics.shared.trackTap(
                                elementId: "call_prompt_dismiss_scrim",
                                screenName: "round_lobby"
                            )
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingCallPrompt = false
                            }
                        }

                    // ── Centred modal card ────────────────────────
                    CallPromptCard(
                        onJoin: {
                            Analytics.shared.trackTap(
                                elementId: "call_prompt_join",
                                screenName: "round_lobby"
                            )
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingCallPrompt = false
                            }
                            callManager.joinCall(
                                competitionId:   competition.id,
                                competitionName: competition.description
                            ) { _ in }
                        },
                        onSkip: {
                            Analytics.shared.trackTap(
                                elementId: "call_prompt_skip",
                                screenName: "round_lobby"
                            )
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingCallPrompt = false
                            }
                        }
                    )
                    .padding(.horizontal, 32)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingCallPrompt)
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .onAppear {
            Analytics.shared.trackScreen(name: "round_lobby")
            if callManager.callState == .idle {
                showingCallPrompt = true
            }
        }
        // Re-prompt if they leave the call while still in the lobby
        .onChange(of: callManager.callState) { state in
            if state == .idle {
                showingCallPrompt = true
            }
        }
        .sheet(isPresented: $showingThemePicker) {
            ThemePickerSheet(competition: competition) { themeId, themeName in
                showingThemePicker = false
                roundViewModel.updateTheme(themeId: themeId, themeName: themeName)
            }
        }
        .fullScreenCover(item: $pendingImage) { identifiableImage in
            if let roundId = roundViewModel.roundInfo?.roundId {
                EntryFeeSheet(
                    entryFee: $pendingEntryFee,
                    image: identifiableImage.image,
                    isFromCamera: true,
                    competition: competition,
                    themeName: roundViewModel.roundInfo?.themeName ?? "",
                    onSuccess: { photoUrl in
                        pendingImage = nil
                        roundViewModel.joinRound(
                            roundId: roundId,
                            photoUrl: photoUrl,
                            entryFee: pendingEntryFee,
                            isFromCamera: identifiableImage.isFromCamera
                        ) { _ in }
                    },
                    onCancel: {
                        pendingImage = nil
                    }
                )
            }
        }
        .fullScreenCover(item: $selectedSubmission) { submission in
            SubmissionFullScreenView(submission: submission)
        }
        .confirmationDialog(
            "Leave Round?",
            isPresented: $showingLeaveConfirm,
            titleVisibility: .visible
        ) {
            Button("Leave", role: .destructive) {
                Analytics.shared.trackTap(
                    elementId: "leave_round_confirm",
                    screenName: "round_lobby"
                )
                roundViewModel.leaveRound { _ in }
            }
            Button("Cancel", role: .cancel) {
                Analytics.shared.trackTap(
                    elementId: "leave_round_cancel",
                    screenName: "round_lobby"
                )
            }
        } message: {
            let fee = roundViewModel.currentUserSubmission?.entryFee ?? 0
            Text(fee > 0
                 ? "You'll be removed from the lobby. Your $\(String(format: "%.2f", fee)) entry will be refunded."
                 : "You'll be removed from the lobby.")
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Computed labels
    // ─────────────────────────────────────────────────────────────

    private var playerStatusText: String {
        let count = roundViewModel.submissions.count
        if count == 0 { return "Waiting for players..." }
        if count == 1 { return "Waiting for at least 1 more player..." }
        return "\(count) players ready"
    }

    private var startButtonLabel: String {
        if roundViewModel.isStartingRound { return "Starting..." }
        if !roundViewModel.currentUserIsInRound && roundViewModel.submissions.count >= 2 { return "Join to Start" }
        let count = roundViewModel.submissions.count
        if count == 0 { return "Need Players" }
        if count == 1 { return "Need 1 More" }
        return "Start Round"
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Submission Card
    // ─────────────────────────────────────────────────────────────

    private func submissionCard(
        submission: RoundSubmission,
        width: CGFloat,
        imageHeight: CGFloat
    ) -> some View {
        let profile = roundViewModel.profile(for: submission.userId)
        let isMe = submission.userId == currentUserId

        return Button(action: {
            Analytics.shared.trackEntry(
                action: "view",
                entryId: submission.userId,
                competitionId: competition.id
            )
            selectedSubmission = submission
        }) {
            ZStack(alignment: .topLeading) {
                AsyncImage(url: URL(string: submission.photoUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: imageHeight)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.pageBackground)
                        .frame(width: width, height: imageHeight)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.secondaryText))
                        )
                }

                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.black.opacity(0.45), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: imageHeight * 0.35)

                    Spacer()

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.45)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: imageHeight * 0.35)
                }
                .frame(width: width, height: imageHeight)

                Text(isMe ? "You" : (profile?.username ?? "..."))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.top, 9)

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        if submission.entryFee > 0 {
                            Text("$\(String(format: "%.2f", submission.entryFee))")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(AppTheme.green)
                                .cornerRadius(200)
                        } else {
                            Text("Free")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(AppTheme.disabledBackground)
                                .cornerRadius(200)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 9)
                }
                .frame(width: width, height: imageHeight)
            }
            .frame(width: width, height: imageHeight)
            .background(isMe ? AppTheme.cardHighlight : AppTheme.cardBackground)
            .cornerRadius(12)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Join Card
    // ─────────────────────────────────────────────────────────────

    private func joinCard(width: CGFloat, imageHeight: CGFloat) -> some View {
        return Button(action: {
            Analytics.shared.trackEntry(
                action: "create",
                competitionId: competition.id
            )
            showingPhotoPicker = true
        }) {
            VStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(AppTheme.accent)
                Text("Join Round")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
            }
            .frame(width: width, height: imageHeight)
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1.5, dash: [6])
                    )
                    .foregroundColor(AppTheme.accent.opacity(0.4))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(roundViewModel.isJoining)
        .fullScreenCover(isPresented: $showingPhotoPicker) {
            RoundCameraView(
                competition: competition,
                themeName: roundViewModel.roundInfo?.themeName ?? "",
                onPhotoSelected: { image, isFromCamera in
                    showingPhotoPicker = false
                    pendingImage = IdentifiableImage(image: image, isFromCamera: isFromCamera)
                },
                onCancel: {
                    showingPhotoPicker = false
                }
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Call Prompt Card
//
// Centred modal card floating over the dimmed lobby.
// Tapping the scrim (handled by RoundLobbyView) also dismisses.
// ─────────────────────────────────────────────────────────────

struct CallPromptCard: View {

    let onJoin: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // ── Icon ─────────────────────────────────────────────
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.12))
                    .frame(width: 72, height: 72)

                Image(systemName: "mic.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
            }
            .padding(.top, 32)
            .padding(.bottom, 20)

            // ── Heading ───────────────────────────────────────────
            Text("Jump on a call")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppTheme.primaryText)
                .padding(.bottom, 8)

            // ── Subtitle ─────────────────────────────────────────
            Text("Chat with your group while you play.\nMore fun, less typing.")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)

            // ── Buttons ───────────────────────────────────────────
            VStack(spacing: 10) {
                Button(action: onJoin) {
                    Text("Join Call")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.accent)
                        .cornerRadius(200)
                }

                Button(action: onSkip) {
                    Text("Not now")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(AppTheme.cardBackground)
        .cornerRadius(20)
        // Absorb taps so they don't fall through to the scrim dismiss
        .onTapGesture {}
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - IdentifiableImage
// ─────────────────────────────────────────────────────────────

struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
    let isFromCamera: Bool
}

// ─────────────────────────────────────────────────────────────
// MARK: - Submission Full Screen View
// ─────────────────────────────────────────────────────────────

struct SubmissionFullScreenView: View {

    let submission: RoundSubmission
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                AsyncImage(url: URL(string: submission.photoUrl)) { image in
                    image
                        .resizable()
                        .if(submission.isFromCamera) { $0.scaledToFill() }
                        .if(!submission.isFromCamera) { $0.scaledToFit() }
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } placeholder: {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .contentShape(Rectangle())
            .onTapGesture { dismiss() }
        }
        .ignoresSafeArea()
    }
}
