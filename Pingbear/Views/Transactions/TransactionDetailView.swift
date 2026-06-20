import SwiftUI
import AVKit
import AVFoundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import CoreHaptics

// ─────────────────────────────────────────────────────────────
// MARK: - TransactionDetailView
//
// Routes to one of two completely different experiences:
//   .request → RequestDetailView   (accept/decline, record, view, rate)
//   .offer   → OfferDetailView     (blurred tease, countdown, reveal, rate)
// ─────────────────────────────────────────────────────────────

struct TransactionDetailView: View {

    let initialEnriched: EnrichedContentTransaction
    let onDismiss:        () -> Void

    var body: some View {
        switch initialEnriched.transaction.type {
        case .request:
            RequestDetailView(enriched: initialEnriched, onDismiss: onDismiss)
        case .offer:
            OfferDetailView(enriched: initialEnriched, onDismiss: onDismiss)
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - REQUEST DETAIL VIEW
// ═══════════════════════════════════════════════════════════════

struct RequestDetailView: View {

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
    @State private var isInlineVideoLoading = true

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
                    AnalyticsProperty.transactionType: tx.type.rawValue,
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
            if isShowing { inlinePlayer?.pause() }
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

    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func startListening() {
        let txId = tx.id
        listener = db.collection("content_transactions").document(txId)
            .addSnapshotListener { snap, _ in
                guard let data = snap?.data(), let updated = ContentTransaction(id: txId, data: data) else { return }
                tx = updated
            }
    }

    private func stopListening() { listener?.remove(); listener = nil }

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
            return isCreator ? "\(otherName) wants a video from you" : "Waiting for \(otherName) to respond"
        case .accepted:
            return isCreator ? "You accepted — record your video" : "\(otherName) accepted — they're working on it!"
        case .fulfilled:
            return isCreator ? "Video sent! Waiting for them to view" : "\(otherName) sent your video — tap to see it"
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

    private var videoPlayerSection: some View {
        Group {
            if let urlStr = tx.photoUrl, let url = URL(string: urlStr) {
                HStack {
                    Spacer(minLength: 0)

                    ZStack(alignment: .topTrailing) {
                        InlineVideoPlayer(
                            url: url,
                            onPlayerReady: { player in inlinePlayer = player },
                            isLoading: $isInlineVideoLoading
                        )

                        if isInlineVideoLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }

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

// ═══════════════════════════════════════════════════════════════
// MARK: - OFFER DETAIL VIEW
// ═══════════════════════════════════════════════════════════════

struct OfferDetailView: View {

    let initialEnriched: EnrichedContentTransaction
    let onDismiss:        () -> Void

    @State private var tx:           ContentTransaction
    @State private var otherProfile: UserProfile?
    @State private var listener:     ListenerRegistration? = nil

    @State private var isActioning      = false
    @State private var errorMessage:    String? = nil

    @State private var walletBalance:          Double               = 0.0
    @State private var showWalletSheet:        Bool                 = false
    @State private var showInsufficientFunds:  Bool                 = false
    @State private var balanceListener:        ListenerRegistration? = nil

    @State private var showRatingPrompt = false

    @State private var showCountdown:     Bool = false
    @State private var countdownComplete: Bool

    init(enriched: EnrichedContentTransaction, onDismiss: @escaping () -> Void) {
        self.initialEnriched = enriched
        self.onDismiss       = onDismiss
        _tx               = State(initialValue: enriched.transaction)
        _otherProfile     = State(initialValue: enriched.otherProfile)
        _countdownComplete = State(initialValue: enriched.transaction.status == .completed)
    }

    private let functions     = Functions.functions()
    private let db            = Firestore.firestore()
    private let currentUserId = Auth.auth().currentUser?.uid ?? ""

    private var isCreator: Bool { tx.isCreator(currentUserId: currentUserId) }
    private var otherName: String { otherProfile?.name ?? "Someone" }
    private var trimmedOtherName: String { (otherProfile?.name ?? "Someone").trimmingCharacters(in: .whitespaces) }
    private var canAfford: Bool { walletBalance >= tx.price }

    var body: some View {
        ZStack {
            if isCreator {
                creatorView
            } else {
                switch tx.status {
                case .completed where countdownComplete: payerRevealedView
                default:                                 payerLockedView
                }
            }

            if showCountdown {
                CountdownView {
                    countdownComplete = true
                    showCountdown     = false
                    triggerReveal()
                }
                .ignoresSafeArea()
            }
        }
        .onAppear {
            startListening()
            startBalanceListener()
            Analytics.shared.trackScreen(name: "transaction_detail")
            Analytics.shared.track(
                event: AnalyticsEvent.transactionViewed,
                properties: [
                    AnalyticsProperty.transactionId: tx.id,
                    AnalyticsProperty.transactionType: tx.type.rawValue,
                    "status": tx.status.rawValue,
                    "is_creator": isCreator
                ]
            )
        }
        .onDisappear { stopListening(); stopBalanceListener() }
        .fullScreenCover(isPresented: $showWalletSheet) {
            WalletView(onDismiss: { showWalletSheet = false })
        }
        .onChange(of: showWalletSheet) { isShowing in
            if isShowing {
                Analytics.shared.trackTap(elementId: "wallet_sheet_opened", screenName: "transaction_detail")
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
    // MARK: - Payer: Locked view (pending_acceptance)
    // Blurred poster-frame thumbnail of the mystery video — not
    // the video itself, since you can't smoothly blur a playing
    // video without decoding it (wasted bandwidth, worse result
    // than a still). The poster frame is grabbed client-side from
    // the first frame of the video.
    // ─────────────────────────────────────────────────────────

    private var payerLockedView: some View {
        ZStack {

            GeometryReader { geo in
                if let urlStr = tx.photoUrl, let url = URL(string: urlStr) {
                    VideoPosterFrame(url: url)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 40, opaque: true)
                } else {
                    Color.black
                }
            }
            .ignoresSafeArea()

            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(10)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)

                Spacer()

                VStack(spacing: 12) {
                    ProfilePictureView(url: otherProfile?.profilePictureUrl, size: 72)
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))

                    VStack(spacing: 4) {
                        Text(otherName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Text("sent you something")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 80, height: 80)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        if canAfford {
                            Task { await respondThenCountdown() }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                showInsufficientFunds = true
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if isActioning {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.85)
                            } else {
                                Image(systemName: "lock.open.fill")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            Text(isActioning ? "Unlocking..." : "Pay \(trimmedOtherName) $\(String(format: "%.2f", tx.price))")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .cornerRadius(200)
                    }
                    .disabled(isActioning)

                    Button {
                        Task { await respond(accept: false) }
                    } label: {
                        Text("Decline")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.top, 8)
                    }
                    .disabled(isActioning)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 52)
            }

            if showInsufficientFunds {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            showInsufficientFunds = false
                        }
                    }

                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Not enough balance")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("Your current balance is $\(String(format: "%.2f", walletBalance)).")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 12) {
                        Button {
                            showInsufficientFunds = false
                            showWalletSheet = true
                            Analytics.shared.trackTap(elementId: "top_up_from_insufficient_funds", screenName: "transaction_detail")
                        } label: {
                            Text("Top Up Wallet")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .cornerRadius(200)
                        }

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                showInsufficientFunds = false
                            }
                            Analytics.shared.trackTap(elementId: "insufficient_funds_not_now", screenName: "transaction_detail")
                        } label: {
                            Text("Not now")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.top, 6)
                        }
                    }
                }
                .padding(28)
                .background(Color(white: 0.12))
                .cornerRadius(24)
                .padding(.horizontal, 32)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Payer: Revealed view (completed)
    // The reveal swaps from a blurred still to the actual video,
    // already playing, filling the screen — looping muted-off
    // playback via the same player infra used elsewhere.
    // ─────────────────────────────────────────────────────────

    private var payerRevealedView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let urlStr = tx.photoUrl, let url = URL(string: urlStr) {
                RevealedOfferVideoPlayer(url: url)
                    .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(10)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)

                Spacer()

                if showRatingPrompt && tx.rating == nil {
                    RatingCard(transactionId: tx.id, onRated: { })
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Creator view
    // ─────────────────────────────────────────────────────────

    private var creatorView: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        profileHeader
                        statusCard

                        if tx.status == .pendingAcceptance || tx.status == .pendingSignup {
                            creatorWaitingCard
                        }

                        if tx.status == .completed {
                            creatorCompletedCard
                            if let urlStr = tx.photoUrl, let url = URL(string: urlStr) {
                                CreatorOfferVideoPreview(url: url)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .clipped()
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 60)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.iconColor)
                    }
                }
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            ProfilePictureView(url: otherProfile?.profilePictureUrl, size: 64)
            VStack(spacing: 4) {
                Text(otherName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
                if let username = otherProfile?.username, !username.isEmpty {
                    Text("@\(username)")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
            HStack(spacing: 6) {
                Text("🎁 Offer")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.green)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(AppTheme.green.opacity(0.1))
                    .cornerRadius(200)
                Text("$\(String(format: "%.2f", tx.price))")
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(AppTheme.primaryText)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(AppTheme.cardBackground)
                    .cornerRadius(200)
            }
        }
        .padding(.top, 8)
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Circle().fill(statusColor).frame(width: 10, height: 10)
            Text(creatorStatusMessage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.primaryText)
            Spacer()
        }
        .padding(16)
        .background(statusColor.opacity(0.08))
        .cornerRadius(12)
    }

    private var creatorStatusMessage: String {
        switch tx.status {
        case .pendingSignup:     return "Waiting for \(otherName) to join SocialStar"
        case .pendingAcceptance: return "Waiting for \(otherName) to unlock your video"
        case .completed:         return tx.rating != nil ? "Completed · \(tx.rating!)⭐" : "Completed ✓"
        case .declined:          return "\(otherName) declined"
        default:                 return ""
        }
    }

    private var statusColor: Color {
        switch tx.status {
        case .pendingAcceptance: return AppTheme.accent
        case .completed:         return AppTheme.green
        default:                 return AppTheme.secondaryText
        }
    }

    private var creatorWaitingCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.system(size: 18))
                .foregroundColor(AppTheme.secondaryText)
            Text(tx.status == .pendingSignup
                 ? "Waiting for \(otherName) to join SocialStar"
                 : "Waiting for \(otherName) to unlock your video")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.secondaryText)
            Spacer()
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    private var creatorCompletedCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(AppTheme.green)
            VStack(alignment: .leading, spacing: 3) {
                Text("Payment received")
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

    private func triggerReveal() {
        guard tx.status == .completed else { return }

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if tx.rating == nil {
                showRatingPrompt = true
                Analytics.shared.track(event: "rating_card_shown", properties: [AnalyticsProperty.transactionId: tx.id])
            }
        }
    }

    private func startListening() {
        let txId = tx.id
        listener = db.collection("content_transactions").document(txId)
            .addSnapshotListener { [self] snap, _ in
                guard let data = snap?.data(),
                      let updated = ContentTransaction(id: txId, data: data)
                else { return }
                tx = updated
            }
    }

    private func stopListening()  { listener?.remove(); listener = nil }

    private func startBalanceListener() {
        guard !currentUserId.isEmpty else { return }
        balanceListener = db.collection("users").document(currentUserId)
            .addSnapshotListener { snap, _ in
                walletBalance = snap?.data()?["wallet_balance"] as? Double ?? 0.0
            }
    }

    private func stopBalanceListener() { balanceListener?.remove(); balanceListener = nil }

    private func respondThenCountdown() async {
        isActioning = true
        do {
            try await functions.httpsCallable("respondToTransaction").call([
                "transactionId": tx.id,
                "accept":        true
            ])
            await MainActor.run {
                isActioning   = false
                Analytics.shared.trackOffer(action: "accepted", transactionId: tx.id)
                Analytics.shared.track(event: "countdown_started", properties: [AnalyticsProperty.transactionId: tx.id])
                showCountdown = true
            }
        } catch {
            await MainActor.run {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                isActioning  = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func respond(accept: Bool) async {
        isActioning = true
        do {
            try await functions.httpsCallable("respondToTransaction").call([
                "transactionId": tx.id,
                "accept":        accept
            ])
            await MainActor.run {
                isActioning = false
                Analytics.shared.trackOffer(action: accept ? "accepted" : "declined", transactionId: tx.id)
                if !accept { onDismiss() }
            }
        } catch {
            await MainActor.run {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                isActioning  = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - VideoPosterFrame
// Grabs the first frame of a remote video and shows it as a
// static image — used for the locked/blurred offer tease so we
// never decode+blur an actual playing video.
// ─────────────────────────────────────────────────────────────

struct VideoPosterFrame: View {
    let url: URL

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.black
            }
        }
        .task { await loadFrame() }
    }

    private func loadFrame() async {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 800, height: 1422)

        do {
            let cgImage = try await generator.image(at: .zero).image
            await MainActor.run { image = UIImage(cgImage: cgImage) }
        } catch {
            // leave as black background on failure — still works, just no thumbnail
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - RevealedOfferVideoPlayer
// Full-screen, looping, autoplaying video for the unlocked offer
// moment. Plays immediately when this view appears — the
// countdown + haptic punch already built the anticipation, so
// the video itself is the payoff with no further delay.
// ─────────────────────────────────────────────────────────────

struct RevealedOfferVideoPlayer: UIViewControllerRepresentable {
    let url: URL

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
            forName: .AVPlayerItemDidPlayToEndTime,
            object:  player.currentItem,
            queue:   .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        player.play()
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

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
// MARK: - CreatorOfferVideoPreview
// Small muted looping preview so the creator can watch back what
// they sent, on the completed offer screen.
// ─────────────────────────────────────────────────────────────

struct CreatorOfferVideoPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(url: url)
        player.isMuted = true

        let vc = AVPlayerViewController()
        vc.player                = player
        vc.showsPlaybackControls = false
        vc.videoGravity          = .resizeAspectFill

        context.coordinator.loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object:  player.currentItem,
            queue:   .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        player.play()
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

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
// MARK: - InlineVideoPlayer (shared — used by request fulfillment views)
// ─────────────────────────────────────────────────────────────

struct InlineVideoPlayer: UIViewControllerRepresentable {
    let url:           URL
    let onPlayerReady: (AVPlayer) -> Void
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(isLoading: $isLoading) }

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

        context.coordinator.statusObserver = player.currentItem?.observe(\.status, options: [.new, .initial]) { item, _ in
            DispatchQueue.main.async {
                context.coordinator.isLoading.wrappedValue = (item.status != .readyToPlay)
            }
        }
        context.coordinator.rateObserver = player.observe(\.timeControlStatus, options: [.new]) { p, _ in
            DispatchQueue.main.async {
                if p.timeControlStatus == .playing {
                    context.coordinator.isLoading.wrappedValue = false
                }
            }
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
        coordinator.statusObserver?.invalidate()
        coordinator.rateObserver?.invalidate()
    }

    class Coordinator {
        var loopObserver:   NSObjectProtocol?
        var statusObserver: NSKeyValueObservation?
        var rateObserver:   NSKeyValueObservation?
        let isLoading: Binding<Bool>
        init(isLoading: Binding<Bool>) { self.isLoading = isLoading }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - FullScreenVideoView (shared)
// ─────────────────────────────────────────────────────────────

struct FullScreenVideoView: View {
    let url:       URL
    let onDismiss: () -> Void

    @State private var player:       AVPlayer?
    @State private var loopObserver: NSObjectProtocol?
    @State private var isLoading     = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                FullScreenFillPlayer(player: player, isLoading: $isLoading)
                    .ignoresSafeArea()
            }

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.3)
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
// MARK: - FullScreenFillPlayer (shared)
// ─────────────────────────────────────────────────────────────

struct FullScreenFillPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(isLoading: $isLoading) }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player                = player
        vc.showsPlaybackControls = false
        vc.videoGravity          = .resizeAspectFill

        context.coordinator.statusObserver = player.currentItem?.observe(\.status, options: [.new, .initial]) { item, _ in
            DispatchQueue.main.async {
                context.coordinator.isLoading.wrappedValue = (item.status != .readyToPlay)
            }
        }
        context.coordinator.rateObserver = player.observe(\.timeControlStatus, options: [.new]) { p, _ in
            DispatchQueue.main.async {
                if p.timeControlStatus == .playing {
                    context.coordinator.isLoading.wrappedValue = false
                }
            }
        }

        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(_ vc: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.statusObserver?.invalidate()
        coordinator.rateObserver?.invalidate()
    }

    class Coordinator {
        var statusObserver: NSKeyValueObservation?
        var rateObserver:   NSKeyValueObservation?
        let isLoading: Binding<Bool>
        init(isLoading: Binding<Bool>) { self.isLoading = isLoading }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - CountdownView (offer accept — unchanged from prior build)
// ─────────────────────────────────────────────────────────────

struct CountdownView: View {

    let onComplete: () -> Void

    @State private var count:        Int            = 3
    @State private var scale:        CGFloat        = 1.0
    @State private var opacity:      Double         = 1.0
    @State private var engine:       CHHapticEngine? = nil
    @State private var countTask:    DispatchWorkItem? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Text("\(count)")
                .font(.system(size: 160, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            startEngine()
            runCountdown()
        }
        .onDisappear {
            countTask?.cancel()
            countTask = nil
            engine?.stop()
            engine = nil
        }
    }

    private func runCountdown() {
        fireCountBeat()
    }

    private func fireCountBeat() {
        scale   = 1.4
        opacity = 1.0

        withAnimation(.easeOut(duration: 0.35)) {
            scale = 1.0
        }
        withAnimation(.easeIn(duration: 0.25).delay(0.65)) {
            opacity = 0.0
        }

        firePunch(count: count)

        let task = DispatchWorkItem {
            if count > 1 {
                count -= 1
                scale   = 1.4
                opacity = 1.0
                fireCountBeat()
            } else {
                engine?.stop()
                engine = nil
                onComplete()
            }
        }
        countTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: task)
    }

    private func startEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            engine?.isAutoShutdownEnabled = false
            try engine?.start()
        } catch {
            print("[CountdownView] Haptic engine failed: \(error)")
        }
    }

    private func firePunch(count: Int) {
        guard let engine, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            let events: [CHHapticEvent]

            switch count {
            case 3:
                events = [
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
                    ], relativeTime: 0),
                    CHHapticEvent(eventType: .hapticContinuous, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
                    ], relativeTime: 0, duration: 0.2),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
                    ], relativeTime: 0.15),
                ]

            case 2:
                events = [
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8),
                    ], relativeTime: 0),
                    CHHapticEvent(eventType: .hapticContinuous, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.0),
                    ], relativeTime: 0, duration: 0.35),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9),
                    ], relativeTime: 0.2),
                ]

            default:
                events = [
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
                    ], relativeTime: 0),
                    CHHapticEvent(eventType: .hapticContinuous, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1),
                    ], relativeTime: 0, duration: 0.5),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
                    ], relativeTime: 0.18),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
                    ], relativeTime: 0.32),
                ]
            }

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player  = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[CountdownView] Haptic pattern failed: \(error)")
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - RatingCard (shared by both flows)
// ─────────────────────────────────────────────────────────────

struct RatingCard: View {

    let transactionId: String
    let onRated:       () -> Void

    @State private var selectedRating:  Int     = 0
    @State private var tappedStar:      Int     = 0
    @State private var isSubmitted:     Bool    = false
    @State private var errorMessage:    String? = nil

    private let functions = Functions.functions()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: "star.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .scaleEffect(tappedStar == star ? 1.3 : 1.0)
                        .onTapGesture {
                            guard !isSubmitted else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedRating = star
                            withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                                tappedStar = star
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                    tappedStar = 0
                                }
                                withAnimation(.easeOut(duration: 0.2)) {
                                    isSubmitted = true
                                }
                                Task { await submitRating() }
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.black)
            .ignoresSafeArea(edges: .bottom)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.bottom, 8)
                    .background(Color.black)
            }
        }
    }

    private func submitRating() async {
        do {
            try await functions.httpsCallable("rateTransaction").call([
                "transactionId": transactionId,
                "rating":        selectedRating
            ])
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Analytics.shared.track(
                event: AnalyticsEvent.contentRated,
                properties: [
                    AnalyticsProperty.transactionId: transactionId,
                    AnalyticsProperty.rating: selectedRating
                ]
            )
            await MainActor.run { onRated() }
        } catch {
            await MainActor.run {
                isSubmitted    = false
                selectedRating = 0
                errorMessage   = error.localizedDescription
            }
        }
    }
}
