import SwiftUI
import AVKit
import AVFoundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

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
    @State private var isDeclining      = false
    @State private var isCancelling     = false
    @State private var errorMessage:    String? = nil
    @State private var showingCamera    = false
    @State private var showingFullVideo  = false
    @State private var isInlineVideoLoading = true

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
                            if isCreator && tx.status == .accepted {
                                fulfillCard
                            }
                            if isPayer && (tx.status == .fulfilled || tx.status == .completed) {
                                viewVideoCard
                            }
                            if isCreator && tx.status == .fulfilled {
                                videoPlayerSection
                            }
                            if isCreator && tx.status == .completed {
                                videoPlayerSection
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
                    onDismiss: { showingFullVideo = false }
                )
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

    // ─────────────────────────────────────────────────────────
    // MARK: - Cards
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
            return isCreator ? "\(otherName) wants a video from you" : "Waiting for \(otherName) to respond"
        case .accepted:
            return isCreator ? "You accepted — record your video" : "\(otherName) accepted — they're working on it!"
        case .fulfilled:
            return isCreator ? "Video sent! Waiting for them to view" : "\(otherName) sent your video — tap to see it"
        case .completed:
            if let rating = tx.rating {
                return "Completed · \(rating) \(rating == 1 ? "star" : "stars")"
            }
            return "Completed"
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
                    HStack(spacing: 6) {
                        if isDeclining {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.disabledText))
                                .scaleEffect(0.85)
                        }
                        Text("Decline")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isDeclining || isActioning ? AppTheme.disabledText : AppTheme.primaryText)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(isDeclining || isActioning ? AppTheme.disabledBackground : AppTheme.cardBackground)
                    .cornerRadius(200)
                }
                .disabled(isDeclining || isActioning)

                Button {
                    Analytics.shared.trackTap(elementId: "accept_request", screenName: "transaction_detail")
                    Task { await respond(accept: true) }
                } label: {
                    HStack(spacing: 6) {
                        if isActioning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.disabledText))
                                .scaleEffect(0.85)
                        }
                        Text("Accept")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isActioning || isDeclining ? AppTheme.disabledText : .white)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(isActioning || isDeclining ? AppTheme.disabledBackground : AppTheme.accent)
                    .cornerRadius(200)
                }
                .disabled(isActioning || isDeclining)
            }
        }
    }

    private var feeBreakdownCard: some View {
        VStack(spacing: 0) {
            feeRow(label: "Reward",             value: "$\(String(format: "%.2f", tx.price))",         color: AppTheme.primaryText)
            Divider().background(AppTheme.divider)
            feeRow(label: "Platform fee (20%)", value: "-$\(String(format: "%.2f", tx.platformFee))",  color: AppTheme.primaryText)
            Divider().background(AppTheme.divider)
            feeRow(label: "You get",            value: "$\(String(format: "%.2f", tx.creatorPayout))", color: AppTheme.green, valueSize: 20)
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

    private var fulfillCard: some View {
        Button {
            Analytics.shared.trackTap(elementId: "record_video", screenName: "transaction_detail")
            showingCamera = true
        } label: {
            Text("Record Video")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(AppTheme.accent).cornerRadius(200)
        }
    }

    private var videoPlayerSection: some View {
        Group {
            if let urlStr = tx.photoUrl, let url = URL(string: urlStr) {
                HStack {
                    Spacer(minLength: 0)

                    ZStack(alignment: .topTrailing) {
                        InlineVideoPlayer(
                            url: url,
                            isActive: Binding(get: { !showingFullVideo }, set: { _ in }),
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

    private var cancelButton: some View {
        Button {
            Analytics.shared.trackTap(elementId: "cancel_request", screenName: "transaction_detail")
            Task { await cancelRequest() }
        } label: {
            HStack(spacing: 6) {
                if isCancelling {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.secondaryText))
                        .scaleEffect(0.8)
                }
                Text(isCancelling ? "Cancelling..." : "Cancel Request")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText)
            }
        }
        .padding(.top, 8)
        .disabled(isCancelling)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Actions
    // ─────────────────────────────────────────────────────────

    private func respond(accept: Bool) async {
        if accept { isActioning = true } else { isDeclining = true }
        do {
            try await functions.httpsCallable("respondToTransaction").call([
                "transactionId": tx.id,
                "accept":        accept
            ])
            await MainActor.run {
                isActioning = false
                isDeclining = false
                Analytics.shared.trackRequest(
                    action: accept ? "accepted" : "declined",
                    transactionId: tx.id
                )
                if accept { showingCamera = true }
                if !accept { onDismiss() }
            }
        } catch {
            await MainActor.run {
                isActioning = false
                isDeclining = false
                errorMessage = error.localizedDescription
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
