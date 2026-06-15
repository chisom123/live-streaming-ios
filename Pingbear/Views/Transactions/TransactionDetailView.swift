import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

// ─────────────────────────────────────────────────────────────
// MARK: - TransactionDetailView
//
// ROLE DEFINITIONS:
//   Request: creator  = toUserId   (person being asked)
//            payer    = fromUserId (person who sent request)
//   Offer:   creator  = fromUserId (person who made offer)
//            payer    = toUserId   (person who pays to unlock)
//
// MONEY FLOW:
//   Request: escrow on send → pay creator at fulfillment
//   Offer:   pay creator when payer accepts
//
// STATUS FLOW:
//   Request: pending_acceptance → accepted → fulfilled → completed
//   Offer:   pending_acceptance → completed
// ─────────────────────────────────────────────────────────────

struct TransactionDetailView: View {

    let initialEnriched: EnrichedContentTransaction
    let onDismiss:        () -> Void

    @State private var tx:             ContentTransaction
    @State private var otherProfile:   UserProfile?
    @State private var listener:       ListenerRegistration? = nil

    @State private var isActioning     = false
    @State private var isCancelling    = false
    @State private var errorMessage:   String? = nil
    @State private var showingCamera   = false
    @State private var capturedImage:  UIImage? = nil
    @State private var uploadProgress: Double = 0

    // Wallet balance (live listener — needed for offer balance check)
    @State private var walletBalance:   Double               = 0.0
    @State private var showWalletSheet: Bool                 = false
    @State private var balanceListener: ListenerRegistration? = nil

    private let functions     = Functions.functions()
    private let db            = Firestore.firestore()
    private let currentUserId = Auth.auth().currentUser?.uid ?? ""

    private var isCreator:    Bool { tx.isCreator(currentUserId: currentUserId) }
    private var iAmResponder: Bool { tx.toUserId == currentUserId }
    private var iSentThis:    Bool { tx.fromUserId == currentUserId }
    private var otherName:    String { otherProfile?.name ?? "Someone" }

    // For offers, the payer is the responder — check they can afford it
    private var canAffordOffer: Bool { walletBalance >= tx.price }

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

                ScrollView {
                    VStack(spacing: 20) {
                        profileHeader

                        statusCard

                        descriptionCard

                        // Responder (toUserId) accepts/declines
                        if iAmResponder && tx.status == .pendingAcceptance {
                            acceptDeclineButtons
                        }

                        // Sender waits during pending acceptance
                        if iSentThis && tx.status == .pendingAcceptance {
                            senderWaitingCard
                        }

                        // Sender waits during pending signup
                        if iSentThis && tx.status == .pendingSignup {
                            senderWaitingCard
                        }

                        // Request creator fulfills after accepting
                        if isCreator && tx.type == .request && tx.status == .accepted {
                            fulfillCard
                        }

                        // Request sender waits while accepted
                        if iSentThis && tx.type == .request && tx.status == .accepted {
                            senderWaitingCard
                        }

                        // Request sender views fulfilled photo
                        if iSentThis && tx.type == .request && tx.status == .fulfilled {
                            viewPhotoCard
                        }

                        // Creator sees fulfilled state
                        if isCreator && tx.type == .request && tx.status == .fulfilled {
                            creatorFulfilledCard
                        }

                        // Offer completed — payer can view from here or history
                        if !isCreator && tx.type == .offer && tx.status == .completed {
                            viewPhotoCard
                        }

                        // Sender can cancel anytime before fulfilled
                        if iSentThis && tx.type == .request &&
                           (tx.status == .pendingAcceptance ||
                            tx.status == .pendingSignup ||
                            tx.status == .accepted) {
                            cancelButton
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 60)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if tx.type == .request && tx.status == .fulfilled && iSentThis {
                            Task { await markViewed() }
                        }
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.iconColor)
                    }
                }
            }
        }
        .onAppear {
            startListening()
            startBalanceListener()
            Analytics.shared.track(
                event: AnalyticsEvent.transactionViewed,
                properties: [
                    AnalyticsProperty.transactionId:   tx.id,
                    AnalyticsProperty.transactionType: tx.type.rawValue,
                    "status":     tx.status.rawValue,
                    "is_creator": isCreator
                ]
            )
        }
        .onDisappear {
            stopListening()
            stopBalanceListener()
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CompetitionCameraView(
                onPhotoTaken: { image in
                    showingCamera = false
                    capturedImage = image
                },
                onCancel: { showingCamera = false }
            )
        }
        // Wallet top-up sheet — balance listener means the UI updates
        // automatically once they return with a higher balance
        .sheet(isPresented: $showWalletSheet) {
            WalletView(onDismiss: { showWalletSheet = false })
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: capturedImage) { image in
            guard let image else { return }
            Task { await fulfillRequest(image: image) }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Live listeners
    // ─────────────────────────────────────────────────────────

    private func startListening() {
        let txId = tx.id
        listener = db.collection("content_transactions").document(txId)
            .addSnapshotListener { [self] snap, _ in
                guard let data    = snap?.data(),
                      let updated = ContentTransaction(id: txId, data: data) else { return }
                tx = updated
            }
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
    }

    private func startBalanceListener() {
        guard !currentUserId.isEmpty else { return }
        balanceListener = db.collection("users").document(currentUserId)
            .addSnapshotListener { snap, _ in
                walletBalance = snap?.data()?["wallet_balance"] as? Double ?? 0.0
            }
    }

    private func stopBalanceListener() {
        balanceListener?.remove()
        balanceListener = nil
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Profile header
    // ─────────────────────────────────────────────────────────

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
                Text(tx.type == .request ? "📸 Request" : "🎁 Offer")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(tx.type == .request ? AppTheme.accent : AppTheme.green)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background((tx.type == .request ? AppTheme.accent : AppTheme.green).opacity(0.1))
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
            if tx.type == .request {
                return iAmResponder
                    ? "\(otherName) wants a photo from you — respond below"
                    : "Waiting for \(otherName) to respond"
            } else {
                return iAmResponder
                    ? "\(otherName) sent you a mystery photo 🎁 — pay to unlock"
                    : "Waiting for \(otherName) to unlock your photo"
            }
        case .accepted:
            return isCreator
                ? "You accepted — shoot your photo and send it 📸"
                : "\(otherName) accepted — they're working on it!"
        case .fulfilled:
            return isCreator
                ? "Photo sent! You've been paid 💰"
                : "\(otherName) sent your photo — tap to see it 👀"
        case .completed:
            return tx.rating != nil
                ? "Completed · \(tx.rating!)⭐"
                : "Completed ✓"
        case .declined:
            return "\(otherName) declined"
        case .cancelled:
            return "You cancelled this request"
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
            Text(tx.type == .request ? "The Request" : "The Teaser")
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
    // MARK: - Accept / Decline
    //
    // Request responder: show fee breakdown (they earn money)
    // Offer responder:   show balance check (they spend money)
    // ─────────────────────────────────────────────────────────

    private var acceptDeclineButtons: some View {
        VStack(spacing: 12) {

            if tx.type == .request {
                // Recipient earns — show what they'll pocket
                FeeBreakdownView(price: tx.price, type: tx.type)
            } else {
                // Payer spends — show balance and warn if insufficient
                offerBalanceView
            }

            HStack(spacing: 12) {
                Button {
                    Task { await respond(accept: false) }
                } label: {
                    Text("Decline")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(200)
                }
                .disabled(isActioning)

                Button {
                    Task { await respond(accept: true) }
                } label: {
                    HStack(spacing: 6) {
                        if isActioning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.85)
                        }
                        Text(tx.type == .offer
                             ? "Accept & Pay $\(String(format: "%.2f", tx.price))"
                             : "Accept & Earn $\(String(format: "%.2f", tx.price * 0.80))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(acceptButtonBackground)
                    .cornerRadius(200)
                }
                // Disable accept if it's an offer and they can't afford it
                .disabled(isActioning || (tx.type == .offer && !canAffordOffer))
            }
        }
    }

    // The accept button is greyed out when balance is insufficient for offers
    private var acceptButtonBackground: Color {
        if isActioning { return AppTheme.disabledBackground }
        if tx.type == .offer && !canAffordOffer { return AppTheme.disabledBackground }
        return AppTheme.accent
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Offer balance view
    //
    // Shown above the accept/decline buttons for offers.
    // Live balance via Firestore listener — updates automatically
    // when the user tops up in WalletView and returns.
    // ─────────────────────────────────────────────────────────

    private var offerBalanceView: some View {
        VStack(spacing: 10) {

            // Balance row
            HStack {
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 14))
                    .foregroundColor(canAffordOffer ? AppTheme.green : .red)
                Text("Your balance")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.secondaryText)
                Spacer()
                Text("$\(String(format: "%.2f", walletBalance))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(canAffordOffer ? AppTheme.green : .red)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background((canAffordOffer ? AppTheme.green : Color.red).opacity(0.08))
            .cornerRadius(10)

            // Insufficient funds warning + Top Up button
            if !canAffordOffer {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                        Text("You need $\(String(format: "%.2f", max(0, tx.price - walletBalance))) more to unlock this")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.red)
                        Spacer()
                    }

                    Button {
                        showWalletSheet = true
                        Analytics.shared.trackTap(
                            elementId:  "top_up_from_offer_detail",
                            screenName: "transaction_detail"
                        )
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 15))
                            Text("Top Up Wallet")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.green)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color.red.opacity(0.06))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(canAffordOffer ? AppTheme.divider : Color.red.opacity(0.3), lineWidth: 1)
        )
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Sender waiting card
    // ─────────────────────────────────────────────────────────

    private var senderWaitingCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.system(size: 18))
                .foregroundColor(AppTheme.secondaryText)
            Text(waitingMessage)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.secondaryText)
            Spacer()
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    private var waitingMessage: String {
        switch tx.status {
        case .pendingSignup:     return "Waiting for \(otherName) to join SocialStar"
        case .pendingAcceptance: return "Waiting for \(otherName) to respond"
        case .accepted:          return "\(otherName) accepted — they're working on it!"
        default:                 return "Waiting..."
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Fulfill card (request creator)
    // ─────────────────────────────────────────────────────────

    private var fulfillCard: some View {
        VStack(spacing: 16) {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .frame(maxWidth: .infinity).frame(height: 220)
                    .clipped().cornerRadius(12)

                if uploadProgress > 0 && uploadProgress < 1 {
                    ProgressView(value: uploadProgress).tint(AppTheme.accent)
                }

                Button {
                    Task { await fulfillRequest(image: image) }
                } label: {
                    HStack(spacing: 8) {
                        if isActioning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.85)
                        }
                        Text(isActioning ? "Sending..." : "Send Photo — Earn $\(String(format: "%.2f", tx.creatorPayout))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isActioning ? AppTheme.disabledBackground : AppTheme.accent)
                    .cornerRadius(200)
                }
                .disabled(isActioning)
            } else {
                FeeBreakdownView(price: tx.price, type: tx.type)

                Button { showingCamera = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.fill").font(.system(size: 18))
                        Text("Take the photo")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent)
                    .cornerRadius(200)
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Creator fulfilled card
    // ─────────────────────────────────────────────────────────

    private var creatorFulfilledCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(AppTheme.green)
            VStack(alignment: .leading, spacing: 3) {
                Text("Photo sent & payment received")
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
    // MARK: - View photo card (payer)
    // ─────────────────────────────────────────────────────────

    private var viewPhotoCard: some View {
        VStack(spacing: 16) {
            if let photoUrl = tx.photoUrl {
                AsyncImage(url: URL(string: photoUrl)) { img in
                    img.resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 260)
                        .clipped().cornerRadius(12)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.cardBackground)
                        .frame(maxWidth: .infinity).frame(height: 260)
                        .overlay(ProgressView().tint(AppTheme.secondaryText))
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
    // MARK: - Cancel button
    // ─────────────────────────────────────────────────────────

    private var cancelButton: some View {
        Button {
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
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red.opacity(0.08))
            .cornerRadius(200)
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
                let action  = accept ? "accepted" : "declined"
                if tx.type == .request {
                    Analytics.shared.trackRequest(action: action, transactionId: tx.id)
                } else {
                    Analytics.shared.trackOffer(action: action, transactionId: tx.id)
                }
                if !accept { onDismiss() }
            }
        } catch {
            await MainActor.run {
                isActioning  = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func fulfillRequest(image: UIImage) async {
        guard tx.type == .request else { return }
        isActioning = true
        do {
            let photoUrl = try await UploadManager.shared.upload(
                image:      image,
                folderPath: "fulfilled/\(currentUserId)/\(tx.id)",
                onProgress: { progress in
                    DispatchQueue.main.async { uploadProgress = progress }
                }
            )
            try await functions.httpsCallable("fulfillRequest").call([
                "transactionId": tx.id,
                "photoUrl":      photoUrl
            ])
            await MainActor.run {
                isActioning    = false
                uploadProgress = 0
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
            try await functions.httpsCallable("markTransactionViewed").call([
                "transactionId": tx.id
            ])
            Analytics.shared.track(
                event:      AnalyticsEvent.contentUnlocked,
                properties: [AnalyticsProperty.transactionId: tx.id]
            )
        } catch {
            print("markViewed error: \(error.localizedDescription)")
        }
    }

    private func cancelRequest() async {
        isCancelling = true
        do {
            try await functions.httpsCallable("cancelRequest").call([
                "transactionId": tx.id
            ])
            await MainActor.run {
                isCancelling = false
                Analytics.shared.trackRequest(action: "cancelled", transactionId: tx.id)
                onDismiss()
            }
        } catch {
            await MainActor.run {
                isCancelling = false
                errorMessage = error.localizedDescription
            }
        }
    }
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
            Text("Rate the photo")
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
                Button {
                    Task { await submitRating() }
                } label: {
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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
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
                event:      AnalyticsEvent.contentRated,
                properties: [
                    AnalyticsProperty.transactionId: transactionId,
                    AnalyticsProperty.rating:        selectedRating
                ]
            )
            await MainActor.run { onRated() }
        } catch {
            await MainActor.run {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
