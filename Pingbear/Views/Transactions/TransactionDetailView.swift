import SwiftUI
import AVKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

// ─────────────────────────────────────────────────────────────
// MARK: - TransactionDetailView
//
// ROLES:
//   payer   = fromUserId (sent the request, pays)
//   creator = toUserId   (records the video, earns)
//
// STATUS FLOW:
//   pending_signup → pending_acceptance → accepted → fulfilled → completed
//                                       → declined
//   cancelled (payer cancels before fulfilled)
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
    @State private var capturedVideoURL: URL?   = nil
    @State private var uploadProgress:  Double  = 0
    @State private var showingFullVideo  = false

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

                            // Creator: respond to pending request
                            if isCreator && tx.status == .pendingAcceptance {
                                creatorAcceptDeclineButtons
                            }

                            // Payer: waiting for response
                            if isPayer && tx.status == .pendingAcceptance {
                                waitingCard("Waiting for \(otherName) to respond")
                            }

                            // Payer: waiting while pending signup
                            if isPayer && tx.status == .pendingSignup {
                                waitingCard("Waiting for \(otherName) to join SocialStar")
                            }

                            // Creator: accepted — record the video
                            if isCreator && tx.status == .accepted {
                                fulfillCard
                            }

                            // Payer: waiting for video
                            if isPayer && tx.status == .accepted {
                                waitingCard("\(otherName) accepted — they're working on it!")
                            }

                            // Payer: video arrived — tap to view
                            if isPayer && (tx.status == .fulfilled || tx.status == .completed) {
                                viewVideoCard
                            }

                            // Creator: waiting for payer to view
                            if isCreator && tx.status == .fulfilled {
                                waitingCard("Video sent — waiting for them to view")
                            }

                            // Creator: completed
                            if isCreator && tx.status == .completed {
                                creatorCompletedCard
                            }

                            // Payer: cancel button (before fulfilled)
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
        // Camera for creator to record their video
        .fullScreenCover(isPresented: $showingCamera) {
            RequestCameraView(
                onVideoTaken: { url in
                    showingCamera    = false
                    capturedVideoURL = url
                },
                onCancel: { showingCamera = false }
            )
        }
        // Full-screen playback for payer
        .fullScreenCover(isPresented: $showingFullVideo) {
            if let urlStr = tx.photoUrl, let url = URL(string: urlStr) {
                FullScreenVideoView(url: url, onDismiss: { showingFullVideo = false })
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
        .onChange(of: capturedVideoURL) { url in
            guard let url else { return }
            Task { await fulfillRequest(videoURL: url) }
        }
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
                ? "You accepted — record your video 🎥"
                : "\(otherName) accepted — they're working on it!"
        case .fulfilled:
            return isCreator
                ? "Video sent! Waiting for them to view"
                : "\(otherName) sent your video — tap to see it 👀"
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
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppTheme.secondaryText)
                .textCase(.uppercase)
            Text(tx.description)
                .font(.system(size: 16))
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
            HStack(spacing: 12) {
                Button { Task { await respond(accept: false) } } label: {
                    Text("Decline")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(AppTheme.cardBackground).cornerRadius(200)
                }
                .disabled(isActioning)

                Button { Task { await respond(accept: true) } } label: {
                    HStack(spacing: 6) {
                        if isActioning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.85)
                        }
                        Text("Accept & Earn $\(String(format: "%.2f", tx.creatorPayout))")
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
            feeRow(label: "Request price",      value: "$\(String(format: "%.2f", tx.price))",          color: AppTheme.primaryText,   bold: false)
            Divider().background(AppTheme.divider)
            feeRow(label: "Platform fee (20%)", value: "-$\(String(format: "%.2f", tx.platformFee))",   color: AppTheme.secondaryText, bold: false)
            Divider().background(AppTheme.divider)
            feeRow(label: "You earn",           value: "$\(String(format: "%.2f", tx.creatorPayout))",  color: AppTheme.green,         bold: true)
        }
        .background(AppTheme.cardBackground).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.divider, lineWidth: 1))
    }

    private func feeRow(label: String, value: String, color: Color, bold: Bool) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(AppTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: bold ? .bold : .regular))
                .foregroundColor(color)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
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
    // ─────────────────────────────────────────────────────────

    private var fulfillCard: some View {
        VStack(spacing: 16) {
            if let url = capturedVideoURL {
                // Thumbnail preview of recorded clip
                VideoThumbnailView(url: url)
                    .frame(maxWidth: .infinity).frame(height: 220)
                    .cornerRadius(12).clipped()

                if uploadProgress > 0 && uploadProgress < 1 {
                    VStack(spacing: 6) {
                        ProgressView(value: uploadProgress).tint(AppTheme.accent)
                        Text("\(Int(uploadProgress * 100))% uploaded")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }

                Button { Task { await fulfillRequest(videoURL: url) } } label: {
                    HStack(spacing: 8) {
                        if isActioning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.85)
                        }
                        Text(isActioning
                             ? "Sending..."
                             : "Send Video — Earn $\(String(format: "%.2f", tx.creatorPayout))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(isActioning ? AppTheme.disabledBackground : AppTheme.accent)
                    .cornerRadius(200)
                }
                .disabled(isActioning)

                Button {
                    capturedVideoURL = nil
                    showingCamera    = true
                } label: {
                    Text("Retake")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.secondaryText)
                }

            } else {
                feeBreakdownCard

                Button { showingCamera = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "video.fill").font(.system(size: 18))
                        Text("Record the video").font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(AppTheme.accent).cornerRadius(200)
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - View video card (payer)
    // ─────────────────────────────────────────────────────────

    private var viewVideoCard: some View {
        VStack(spacing: 16) {
            if let urlStr = tx.photoUrl, let url = URL(string: urlStr) {
                // Inline player
                InlineVideoPlayer(url: url)
                    .frame(maxWidth: .infinity).frame(height: 300)
                    .cornerRadius(12).clipped()
                    .onAppear { Task { await markViewed() } }

                // Full screen button
                Button {
                    showingFullVideo = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 13, weight: .bold))
                        Text("Full screen")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.secondaryText)
                }
            }

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
        Button { Task { await cancelRequest() } } label: {
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

    private func fulfillRequest(videoURL: URL) async {
        guard !isActioning else { return }
        isActioning = true
        do {
            let downloadURL = try await VideoUploadManager.shared.upload(
                videoURL:   videoURL,
                folderPath: "fulfilled/\(currentUserId)/\(tx.id)",
                onProgress: { p in DispatchQueue.main.async { uploadProgress = p } }
            )
            // Clean up local temp file
            try? FileManager.default.removeItem(at: videoURL)

            try await functions.httpsCallable("fulfillRequest").call([
                "transactionId": tx.id,
                "photoUrl":      downloadURL   // field name unchanged in backend
            ])
            await MainActor.run {
                isActioning      = false
                uploadProgress   = 0
                capturedVideoURL = nil
                Analytics.shared.trackRequest(action: "fulfilled", transactionId: tx.id)
            }
        } catch {
            await MainActor.run {
                isActioning    = false
                uploadProgress = 0
                errorMessage   = error.localizedDescription
            }
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
// MARK: - VideoThumbnailView
// Shows the first frame of a local video file with a play badge.
// ─────────────────────────────────────────────────────────────

struct VideoThumbnailView: View {
    let url: URL
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            if let img = thumbnail {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(AppTheme.cardBackground)
                    .overlay(ProgressView().tint(AppTheme.secondaryText))
            }
            // Play badge overlay
            Image(systemName: "play.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 4)
        }
        .onAppear { generateThumbnail() }
    }

    private func generateThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: url)
            let gen   = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 720, height: 720)
            if let cgImg = try? gen.copyCGImage(at: .zero, actualTime: nil) {
                let img = UIImage(cgImage: cgImg)
                DispatchQueue.main.async { thumbnail = img }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - InlineVideoPlayer
// AVPlayerViewController wrapped for SwiftUI.
// Loops, shows system controls, fills the frame.
// ─────────────────────────────────────────────────────────────

struct InlineVideoPlayer: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(url: url)
        let vc     = AVPlayerViewController()
        vc.player                = player
        vc.showsPlaybackControls = true
        vc.videoGravity          = .resizeAspectFill

        // Loop
        context.coordinator.loopObserver = NotificationCenter.default.addObserver(
            forName:  .AVPlayerItemDidPlayToEndTime,
            object:   player.currentItem,
            queue:    .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        player.play()
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
// Pinch-to-zoom, tap-to-dismiss, same pattern as the old
// FullScreenPhotoView but for video.
// ─────────────────────────────────────────────────────────────

struct FullScreenVideoView: View {
    let url:       URL
    let onDismiss: () -> Void

    @State private var player:        AVPlayer?
    @State private var loopObserver:  NSObjectProtocol?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.top, 60).padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .onAppear { setupPlayer() }
        .onDisappear { teardown() }
    }

    private func setupPlayer() {
        let p = AVPlayer(url: url)
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
// MARK: - RatingCard (unchanged)
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
