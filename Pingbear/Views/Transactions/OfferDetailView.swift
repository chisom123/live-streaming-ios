import SwiftUI
import AVKit
import AVFoundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

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

    @State private var walletBalance:          Double                = 0.0
    @State private var showWalletSheet:        Bool                  = false
    @State private var showInsufficientFunds:  Bool                  = false
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

    // ─────────────────────────────────────────────────────────
    // MARK: - Actions
    // ─────────────────────────────────────────────────────────

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
