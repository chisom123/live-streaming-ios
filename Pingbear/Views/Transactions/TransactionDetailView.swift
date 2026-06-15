import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

struct TransactionDetailView: View {

    let initialEnriched: EnrichedContentTransaction
    let onDismiss:        () -> Void

    @State private var tx:           ContentTransaction
    @State private var otherProfile: UserProfile?
    @State private var listener:     ListenerRegistration? = nil

    @State private var isActioning      = false
    @State private var errorMessage:    String? = nil
    @State private var showingFullPhoto = false

    @State private var walletBalance:   Double               = 0.0
    @State private var showWalletSheet: Bool                 = false
    @State private var balanceListener: ListenerRegistration? = nil

    private let functions     = Functions.functions()
    private let db            = Firestore.firestore()
    private let currentUserId = Auth.auth().currentUser?.uid ?? ""

    private var isCreator: Bool { tx.isCreator(currentUserId: currentUserId) }
    private var otherName: String { otherProfile?.name ?? "Someone" }
    private var canAfford: Bool { walletBalance >= tx.price }

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

                        // Payer accepts/declines
                        if tx.toUserId == currentUserId && tx.status == .pendingAcceptance {
                            acceptDeclineButtons
                        }

                        // Creator waiting
                        if isCreator && (tx.status == .pendingAcceptance || tx.status == .pendingSignup) {
                            creatorWaitingCard
                        }

                        // Payer views photo after completing
                        if !isCreator && tx.status == .completed {
                            viewPhotoCard
                        }

                        // Creator sees earnings
                        if isCreator && tx.status == .completed {
                            creatorCompletedCard
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
        .onAppear {
            startListening()
            startBalanceListener()
            Analytics.shared.track(
                event: AnalyticsEvent.transactionViewed,
                properties: [AnalyticsProperty.transactionId: tx.id, "status": tx.status.rawValue, "is_creator": isCreator]
            )
        }
        .onDisappear { stopListening(); stopBalanceListener() }
        .sheet(isPresented: $showWalletSheet) { WalletView(onDismiss: { showWalletSheet = false }) }
        .fullScreenCover(isPresented: $showingFullPhoto) {
            if let photoUrl = tx.photoUrl {
                FullScreenPhotoView(photoUrl: photoUrl, onDismiss: { showingFullPhoto = false })
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
    // MARK: - Listeners
    // ─────────────────────────────────────────────────────────

    private func startListening() {
        let txId = tx.id
        listener = db.collection("content_transactions").document(txId)
            .addSnapshotListener { [self] snap, _ in
                guard let data = snap?.data(), let updated = ContentTransaction(id: txId, data: data) else { return }
                tx = updated
            }
    }

    private func stopListening() { listener?.remove(); listener = nil }

    private func startBalanceListener() {
        guard !currentUserId.isEmpty else { return }
        balanceListener = db.collection("users").document(currentUserId)
            .addSnapshotListener { snap, _ in
                walletBalance = snap?.data()?["wallet_balance"] as? Double ?? 0.0
            }
    }

    private func stopBalanceListener() { balanceListener?.remove(); balanceListener = nil }

    // ─────────────────────────────────────────────────────────
    // MARK: - Profile header
    // ─────────────────────────────────────────────────────────

    private var profileHeader: some View {
        VStack(spacing: 12) {
            ProfilePictureView(url: otherProfile?.profilePictureUrl, size: 64)
            VStack(spacing: 4) {
                Text(otherName).font(.system(size: 18, weight: .bold)).foregroundColor(AppTheme.primaryText)
                if let username = otherProfile?.username, !username.isEmpty {
                    Text("@\(username)").font(.system(size: 14)).foregroundColor(AppTheme.secondaryText)
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

    // ─────────────────────────────────────────────────────────
    // MARK: - Status card
    // ─────────────────────────────────────────────────────────

    private var statusCard: some View {
        HStack(spacing: 12) {
            Circle().fill(statusColor).frame(width: 10, height: 10)
            Text(statusMessage).font(.system(size: 14, weight: .semibold)).foregroundColor(AppTheme.primaryText)
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
                ? "Waiting for \(otherName) to unlock your photo"
                : "\(otherName) sent you a mystery photo 🎁 — pay to unlock"
        case .completed:
            return tx.rating != nil ? "Completed · \(tx.rating!)⭐" : "Completed ✓"
        case .declined:
            return isCreator ? "\(otherName) declined" : "You declined"
        }
    }

    private var statusColor: Color {
        switch tx.status {
        case .pendingAcceptance: return AppTheme.accent
        case .completed:         return AppTheme.green
        default:                 return AppTheme.secondaryText
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Accept / Decline
    // ─────────────────────────────────────────────────────────

    private var acceptDeclineButtons: some View {
        VStack(spacing: 12) {
            offerBalanceView
            HStack(spacing: 12) {
                Button { Task { await respond(accept: false) } } label: {
                    Text("Decline")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(200)
                }
                .disabled(isActioning)

                Button { Task { await respond(accept: true) } } label: {
                    HStack(spacing: 6) {
                        if isActioning {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.85)
                        }
                        Text("Unlock for $\(String(format: "%.2f", tx.price))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isActioning || !canAfford ? AppTheme.disabledBackground : AppTheme.accent)
                    .cornerRadius(200)
                }
                .disabled(isActioning || !canAfford)
            }
        }
    }

    private var offerBalanceView: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "wallet.pass.fill").font(.system(size: 14))
                    .foregroundColor(canAfford ? AppTheme.green : .red)
                Text("Your balance").font(.system(size: 13)).foregroundColor(AppTheme.secondaryText)
                Spacer()
                Text("$\(String(format: "%.2f", walletBalance))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(canAfford ? AppTheme.green : .red)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background((canAfford ? AppTheme.green : Color.red).opacity(0.08))
            .cornerRadius(10)

            if !canAfford {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 13)).foregroundColor(.red)
                        Text("You need $\(String(format: "%.2f", max(0, tx.price - walletBalance))) more to unlock this")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.red)
                        Spacer()
                    }
                    Button {
                        showWalletSheet = true
                        Analytics.shared.trackTap(elementId: "top_up_from_offer_detail", screenName: "transaction_detail")
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill").font(.system(size: 15))
                            Text("Top Up Wallet").font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(AppTheme.green).cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color.red.opacity(0.06)).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.2), lineWidth: 1))
            }
        }
        .background(AppTheme.cardBackground).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(canAfford ? AppTheme.divider : Color.red.opacity(0.3), lineWidth: 1))
    }

    private var creatorWaitingCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill").font(.system(size: 18)).foregroundColor(AppTheme.secondaryText)
            Text(tx.status == .pendingSignup
                 ? "Waiting for \(otherName) to join SocialStar"
                 : "Waiting for \(otherName) to unlock your photo")
                .font(.system(size: 14)).foregroundColor(AppTheme.secondaryText)
            Spacer()
        }
        .padding(16).background(AppTheme.cardBackground).cornerRadius(12)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - View photo card (payer)
    // ─────────────────────────────────────────────────────────

    private var viewPhotoCard: some View {
        VStack(spacing: 16) {
            if let photoUrl = tx.photoUrl {
                Button { showingFullPhoto = true } label: {
                    AsyncImage(url: URL(string: photoUrl)) { img in
                        img.resizable().scaledToFill()
                            .frame(maxWidth: .infinity).frame(height: 260)
                            .clipped().cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.02))
                                    .overlay(VStack { Spacer(); HStack { Spacer()
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                            .padding(8).background(Color.black.opacity(0.4)).clipShape(Circle()).padding(12)
                                    }})
                            )
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12).fill(AppTheme.cardBackground)
                            .frame(maxWidth: .infinity).frame(height: 260)
                            .overlay(ProgressView().tint(AppTheme.secondaryText))
                    }
                }
                .buttonStyle(.plain)
            }

            if tx.status == .completed && tx.rating == nil {
                RatingCard(transactionId: tx.id, onRated: { })
            }

            if let rating = tx.rating {
                HStack {
                    Text("You rated this").font(.system(size: 14)).foregroundColor(AppTheme.secondaryText)
                    Spacer()
                    Text("\(rating)⭐").font(.system(size: 14, weight: .bold)).foregroundColor(AppTheme.primaryText)
                }
                .padding(14).background(AppTheme.cardBackground).cornerRadius(12)
            }
        }
    }

    private var creatorCompletedCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundColor(AppTheme.green)
            VStack(alignment: .leading, spacing: 3) {
                Text("Payment received").font(.system(size: 14, weight: .bold)).foregroundColor(AppTheme.primaryText)
                Text("+$\(String(format: "%.2f", tx.creatorPayout)) added to your wallet")
                    .font(.system(size: 13)).foregroundColor(AppTheme.green)
            }
            Spacer()
        }
        .padding(16).background(AppTheme.green.opacity(0.08)).cornerRadius(12)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Actions
    // ─────────────────────────────────────────────────────────

    private func respond(accept: Bool) async {
        isActioning = true
        do {
            try await functions.httpsCallable("respondToTransaction").call(["transactionId": tx.id, "accept": accept])
            await MainActor.run {
                isActioning = false
                Analytics.shared.trackOffer(action: accept ? "accepted" : "declined", transactionId: tx.id)
                if !accept { onDismiss() }
            }
        } catch {
            await MainActor.run { isActioning = false; errorMessage = error.localizedDescription }
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
            Text("Rate the photo").font(.system(size: 16, weight: .bold)).foregroundColor(AppTheme.primaryText)

            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= selectedRating ? "star.fill" : "star")
                        .font(.system(size: 32))
                        .foregroundColor(star <= selectedRating ? AppTheme.gold : AppTheme.secondaryText.opacity(0.3))
                        .onTapGesture { UIImpactFeedbackGenerator(style: .light).impactOccurred(); selectedRating = star }
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: selectedRating)
                }
            }

            if selectedRating > 0 {
                Button { Task { await submitRating() } } label: {
                    HStack(spacing: 6) {
                        if isSubmitting { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.85) }
                        Text(isSubmitting ? "Submitting..." : "Submit Rating")
                            .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(isSubmitting ? AppTheme.disabledBackground : AppTheme.accent)
                    .cornerRadius(200)
                }
                .disabled(isSubmitting)
            }

            if let errorMessage {
                Text(errorMessage).font(.system(size: 13)).foregroundColor(.red)
            }
        }
        .padding(20).background(AppTheme.cardBackground).cornerRadius(16)
    }

    private func submitRating() async {
        isSubmitting = true
        do {
            try await functions.httpsCallable("rateTransaction").call(["transactionId": transactionId, "rating": selectedRating])
            Analytics.shared.track(event: AnalyticsEvent.contentRated, properties: [AnalyticsProperty.transactionId: transactionId, AnalyticsProperty.rating: selectedRating])
            await MainActor.run { onRated() }
        } catch {
            await MainActor.run { isSubmitting = false; errorMessage = error.localizedDescription }
        }
    }
}
