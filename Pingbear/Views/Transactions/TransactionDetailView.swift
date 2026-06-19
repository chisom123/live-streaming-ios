import SwiftUI
import AVKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

// ─────────────────────────────────────────────────────────────
// MARK: - TransactionDetailView
// ─────────────────────────────────────────────────────────────

struct TransactionDetailView: View {

    let initialEnriched: EnrichedContentTransaction
    let onDismiss:        () -> Void

    @State private var tx:              ContentTransaction
    @State private var otherProfile:    UserProfile?
    @State private var listener:        ListenerRegistration? = nil
    @State private var isActioning      = false
    @State private var isCancelling     = false
    @State private var errorMessage:    String? = nil
    @State private var showingCamera    = false
    @State private var showingFullVideo  = false

    // Shared player so inline and fullscreen stay in sync
    @State private var inlinePlayer:    AVPlayer? = nil

    private let functions     = Functions.functions()
    private let db            = Firestore.firestore()
    private let currentUserId = Auth.auth().currentUser?.uid ?? ""

    private var isCreator: Bool { tx.isCreator(currentUserId: currentUserId) }
    private var isPayer:   Bool { tx.isPayer(currentUserId: currentUserId) }
    private var otherName: String { otherProfile?.name ?? "Someone" }

    init(enriched: EnrichedContentTransaction, onDismiss: @escaping () -> Void) {
        self.initialEnriched = enriched
        self.onDismiss       = onDismiss
        _tx           = State(initialValue: enriched.transaction)
        _otherProfile = State(initialValue: enriched.otherProfile)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    // MARK: - Navigation Bar
                    HStack {
                        Button(action: {
                            if isPayer && tx.status == .fulfilled { Task { await markViewed() } }
                            onDismiss()
                        }) {
                            Image(systemName: "arrow.left")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 27, height: 27)
                                .foregroundColor(AppTheme.iconColor)
                        }

                        Spacer()

                        Text(otherName)
                            .font(.system(size: 18, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(AppTheme.primaryText)
                            .padding(.horizontal)

                        Spacer()

                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .opacity(0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)

                    ScrollView {
                        VStack(spacing: 20) {
                            statusCard
                            descriptionCard

                            if isCreator && tx.status == .pendingAcceptance {
                                creatorAcceptDeclineButtons
                            }
                            if isPayer && tx.status == .pendingAcceptance {
                                waitingCard("Waiting for \(otherName) to respond")
                            }
                            if isPayer && tx.status == .pendingSignup {
                                waitingCard("Waiting for \(otherName) to join SocialStar")
                            }
                            if isCreator && tx.status == .accepted {
                                fulfillCard
                            }
                            if isPayer && tx.status == .accepted {
                                waitingCard("\(otherName) accepted — they're working on it!")
                            }
                            if isPayer && (tx.status == .fulfilled || tx.status == .completed) {
                                viewVideoCard
                            }
                            if isCreator && tx.status == .fulfilled {
                                creatorVideoCard
                                waitingCard("Video sent — waiting for them to view")
                            }
                            if isCreator && tx.status == .completed {
                                creatorVideoCard
                                creatorCompletedCard
                            }
                            if isPayer && [.pendingSignup, .pendingAcceptance, .accepted].contains(tx.status) {
                                cancelButton
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 60)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            startListening()
            setupAudioSession()
            Analytics.shared.trackScreen(name: "transaction_detail")
            Analytics.shared.track(
                event: AnalyticsEvent.transactionViewed,
                properties: [
                    AnalyticsProperty.transactionId: tx.id,
                    "status":     tx.status.rawValue,
                    "is_creator": isCreator
                ]
            )
        }
        .onDisappear { stopListening() }
        .fullScreenCover(isPresented: $showingCamera) {
            RequestCameraView(
                transactionId: tx.id,
                onFulfilled: { showingCamera = false },
                onCancel:    { showingCamera = false }
            )
        }
        .fullScreenCover(isPresented: $showingFullVideo) {
            if let urlStr = tx.photoUrl, let url = URL(string: urlStr) {
                FullScreenVideoView(
                    url: url,
                    onDismiss: {
                        showingFullVideo = false
                        inlinePlayer?.play()
                    }
                )
            }
        }
        .onChange(of: showingFullVideo) { isShowing in
            if isShowing {
                inlinePlayer?.pause()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Audio session
    // ─────────────────────────────────────────────────────────

    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Listener
    // ─────────────────────────────────────────────────────────

    private func startListening() {
        let txId = tx.id
        listener = db.collection("content_transactions").document(txId)
            .addSnapshotListener { snap, _ in
                guard let data = snap?.data(),
                      let updated = ContentTransaction(id: txId, data: data)
                else { return }
                tx = updated
            }
    }

    private func stopListening() { listener?.remove(); listener = nil }

    // ─────────────────────────────────────────────────────────
    // MARK: - Status card
    // ─────────────────────────────────────────────────────────

    private var statusCard: some View {
        HStack(spacing: 12) {
            Circle().fill(statusColor).frame(width: 10, height: 10)
            Text(statusMessage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.primaryText)
            Spacer()
        }
        .padding(16)
        .background(statusColor.opacity(0.08))
        .cornerRadius(12)
    }

    private var statusMessage: String {
        switch tx.status {
        case .pendingSignup:
            return "Waiting for \(otherName) to join SocialStar"
        case .pendingAcceptance:
            return isCreator
                ? "\(otherName) wants a video from you"
                : "Waiting for \(otherName) to respond"
        case .accepted:
            return isCreator
                ? "You accepted — record your video"
                : "\(otherName) accepted — they're working on it!"
        case .fulfilled:
            return isCreator
                ? "Video sent! Waiting for them to view"
                : "\(otherName) sent your video — tap to see it"
        case .completed:
            return tx.rating != nil ? "Completed · \(tx.rating!)⭐" : "Completed ✓"
        case .declined:
            return isCreator ? "You declined" : "\(otherName) declined"
        case .cancelled:
            return isPayer ? "You cancelled this request" : "\(otherName) cancelled"
        }
    }

    private var statusColor: Color {
        switch tx.status {
        case .pendingAcceptance: return AppTheme.accent
        case .accepted:          return AppTheme.gold
        case .fulfilled:         return AppTheme.green
        case .completed:         return AppTheme.green
        default:                 return AppTheme.secondaryText
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Description card
    // ─────────────────────────────────────────────────────────

    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The Request")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText)
            Text(tx.description)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Creator accept / decline
    // ─────────────────────────────────────────────────────────

    private var creatorAcceptDeclineButtons: some View {
        VStack(spacing: 12) {
            feeBreakdownCard
                .padding(.bottom)

            HStack(spacing: 12) {
                Button {
                    Analytics.shared.trackTap(elementId: "decline_request", screenName: "transaction_detail")
                    Task { await respond(accept: false) }
                } label: {
                    Text("Decline")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(AppTheme.cardBackground).cornerRadius(200)
                }
                .disabled(isActioning)

                Button {
                    Analytics.shared.trackTap(elementId: "accept_request", screenName: "transaction_detail")
                    Task { await respond(accept: true) }
                } label: {
                    HStack(spacing: 6) {
                        if isActioning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.85)
                        }
                        Text("Accept")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(isActioning ? AppTheme.disabledBackground : AppTheme.accent)
                    .cornerRadius(200)
                }
                .disabled(isActioning)
            }
        }
    }

    private var feeBreakdownCard: some View {
        VStack(spacing: 0) {
            feeRow(label: "Reward",      value: "$\(String(format: "%.2f", tx.price))",         color: AppTheme.primaryText)
            Divider().background(AppTheme.divider)
            feeRow(label: "Platform fee (20%)", value: "-$\(String(format: "%.2f", tx.platformFee))",  color: AppTheme.primaryText)
            Divider().background(AppTheme.divider)
            feeRow(label: "You get",           value: "$\(String(format: "%.2f", tx.creatorPayout))", color: AppTheme.green, valueSize: 20)
        }
        .background(AppTheme.cardBackground).cornerRadius(12)
    }

    private func feeRow(label: String, value: String, color: Color, valueSize: CGFloat = 13) -> some View {
        HStack {
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundColor(AppTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: valueSize, weight: .bold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 16).padding(.vertical, 16)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Waiting card
    // ─────────────────────────────────────────────────────────

    private func waitingCard(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.system(size: 18))
                .foregroundColor(AppTheme.secondaryText)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.secondaryText)
            Spacer()
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Fulfill card (creator records video)
    // Recording, preview, upload, and the fulfillRequest call all now
    // happen inside RequestCameraView — this just launches it.
    // ─────────────────────────────────────────────────────────

    private var fulfillCard: some View {
        VStack(spacing: 16) {
            feeBreakdownCard

            Button {
                Analytics.shared.trackTap(elementId: "record_video", screenName: "transaction_detail")
                showingCamera = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "video.fill").font(.system(size: 18))
                    Text("Record the video").font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(AppTheme.accent).cornerRadius(200)
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Video player section (shared between payer & creator)
    // Sized like an actual mobile video — a tall vertical rectangle —
    // and tappable anywhere to open full screen. The expand icon
    // top-right is just a visual affordance; tapping it also opens
    // full screen since it sits on top of the same tappable area.
    // ─────────────────────────────────────────────────────────

    private var videoPlayerSection: some View {
        Group {
            if let urlStr = tx.photoUrl, let url = URL(string: urlStr) {
                HStack {
                    Spacer(minLength: 0)

                    ZStack(alignment: .topTrailing) {
                        InlineVideoPlayer(url: url, onPlayerReady: { player in
                            inlinePlayer = player
                        })

                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(7)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                            .padding(8)
                            .allowsHitTesting(false)
                    }
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .frame(width: 170)
                    .background(Color.black)
                    .cornerRadius(16)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Analytics.shared.trackTap(elementId: "fullscreen_video", screenName: "transaction_detail")
                        showingFullVideo = true
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - View video card (payer)
    // ─────────────────────────────────────────────────────────

    private var viewVideoCard: some View {
        VStack(spacing: 16) {
            videoPlayerSection
                .onAppear { Task { await markViewed() } }

            if tx.status == .completed && tx.rating == nil {
                RatingCard(transactionId: tx.id, onRated: { })
            }

            if let rating = tx.rating {
                HStack {
                    Text("You rated this")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.secondaryText)
                    Spacer()
                    Text("\(rating)⭐")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                }
                .padding(14)
                .background(AppTheme.cardBackground)
                .cornerRadius(12)
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Creator's own video card
    // Lets the creator watch back what they sent. No markViewed
    // call here — that's only for when the payer watches it.
    // ─────────────────────────────────────────────────────────

    private var creatorVideoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your video")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText)
            videoPlayerSection
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Creator completed card
    // ─────────────────────────────────────────────────────────

    private var creatorCompletedCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(AppTheme.green)
            VStack(alignment: .leading, spacing: 3) {
                Text("Video sent & payment received")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
                Text("+$\(String(format: "%.2f", tx.creatorPayout)) added to your wallet")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.green)
            }
            Spacer()
        }
        .padding(16)
        .background(AppTheme.green.opacity(0.08))
        .cornerRadius(12)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Cancel button (payer)
    // ─────────────────────────────────────────────────────────

    private var cancelButton: some View {
        Button {
            Analytics.shared.trackTap(elementId: "cancel_request", screenName: "transaction_detail")
            Task { await cancelRequest() }
        } label: {
            HStack(spacing: 6) {
                if isCancelling {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .red))
                        .scaleEffect(0.8)
                }
                Text(isCancelling ? "Cancelling..." : "Cancel Request")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.red)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Color.red.opacity(0.08)).cornerRadius(200)
        }
        .disabled(isCancelling)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Actions
    // ─────────────────────────────────────────────────────────

    private func respond(accept: Bool) async {
        isActioning = true
        do {
            try await functions.httpsCallable("respondToTransaction").call([
                "transactionId": tx.id,
                "accept":        accept
            ])
            await MainActor.run {
                isActioning = false
                Analytics.shared.trackRequest(
                    action: accept ? "accepted" : "declined",
                    transactionId: tx.id
                )
                if !accept { onDismiss() }
            }
        } catch {
            await MainActor.run { isActioning = false; errorMessage = error.localizedDescription }
        }
    }

    private func markViewed() async {
        do {
            try await functions.httpsCallable("markTransactionViewed")
                .call(["transactionId": tx.id])
        } catch {
            print("markViewed error: \(error.localizedDescription)")
        }
    }

    private func cancelRequest() async {
        isCancelling = true
        do {
            try await functions.httpsCallable("cancelRequest")
                .call(["transactionId": tx.id])
            await MainActor.run {
                isCancelling = false
                Analytics.shared.trackRequest(action: "cancelled", transactionId: tx.id)
                onDismiss()
            }
        } catch {
            await MainActor.run { isCancelling = false; errorMessage = error.localizedDescription }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - InlineVideoPlayer
// ─────────────────────────────────────────────────────────────

struct InlineVideoPlayer: UIViewControllerRepresentable {
    let url:           URL
    let onPlayerReady: (AVPlayer) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        let player = AVPlayer(url: url)
        player.isMuted = false

        let vc = AVPlayerViewController()
        vc.player                = player
        vc.showsPlaybackControls = false
        vc.videoGravity          = .resizeAspectFill

        context.coordinator.loopObserver = NotificationCenter.default.addObserver(
            forName:  .AVPlayerItemDidPlayToEndTime,
            object:   player.currentItem,
            queue:    .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        player.play()

        DispatchQueue.main.async { onPlayerReady(player) }

        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(_ vc: AVPlayerViewController, coordinator: Coordinator) {
        vc.player?.pause()
        if let obs = coordinator.loopObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    class Coordinator {
        var loopObserver: NSObjectProtocol?
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - FullScreenVideoView
// ─────────────────────────────────────────────────────────────

struct FullScreenVideoView: View {
    let url:       URL
    let onDismiss: () -> Void

    @State private var player:       AVPlayer?
    @State private var loopObserver: NSObjectProtocol?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                FullScreenFillPlayer(player: player)
                    .ignoresSafeArea()
            }
        }
        .onAppear { setupPlayer() }
        .onDisappear { teardown() }
        .onTapGesture { onDismiss() }
    }

    private func setupPlayer() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        let p = AVPlayer(url: url)
        p.isMuted = false
        player = p

        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object:  p.currentItem,
            queue:   .main
        ) { _ in p.seek(to: .zero); p.play() }

        p.play()
    }

    private func teardown() {
        player?.pause()
        player = nil
        if let obs = loopObserver {
            NotificationCenter.default.removeObserver(obs)
            loopObserver = nil
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - FullScreenFillPlayer
// ─────────────────────────────────────────────────────────────

struct FullScreenFillPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player                = player
        vc.showsPlaybackControls = false
        vc.videoGravity          = .resizeAspectFill
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}
}

// ─────────────────────────────────────────────────────────────
// MARK: - RatingCard
// ─────────────────────────────────────────────────────────────

struct RatingCard: View {

    let transactionId: String
    let onRated:       () -> Void

    @State private var selectedRating = 0
    @State private var isSubmitting   = false
    @State private var errorMessage:  String? = nil

    private let functions = Functions.functions()

    var body: some View {
        VStack(spacing: 16) {
            Text("Rate the video")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.primaryText)

            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= selectedRating ? "star.fill" : "star")
                        .font(.system(size: 32))
                        .foregroundColor(star <= selectedRating ? AppTheme.gold : AppTheme.secondaryText.opacity(0.3))
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedRating = star
                        }
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: selectedRating)
                }
            }

            if selectedRating > 0 {
                Button { Task { await submitRating() } } label: {
                    HStack(spacing: 6) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.85)
                        }
                        Text(isSubmitting ? "Submitting..." : "Submit Rating")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(isSubmitting ? AppTheme.disabledBackground : AppTheme.accent)
                    .cornerRadius(200)
                }
                .disabled(isSubmitting)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
            }
        }
        .padding(20)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }

    private func submitRating() async {
        isSubmitting = true
        do {
            try await functions.httpsCallable("rateTransaction").call([
                "transactionId": transactionId,
                "rating":        selectedRating
            ])
            Analytics.shared.track(
                event: AnalyticsEvent.contentRated,
                properties: [
                    AnalyticsProperty.transactionId: transactionId,
                    AnalyticsProperty.rating:        selectedRating
                ]
            )
            await MainActor.run { onRated() }
        } catch {
            await MainActor.run { isSubmitting = false; errorMessage = error.localizedDescription }
        }
    }
}
