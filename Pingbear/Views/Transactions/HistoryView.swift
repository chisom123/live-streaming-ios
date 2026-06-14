import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// ─────────────────────────────────────────────────────────────
// MARK: - HistoryViewModel
// ─────────────────────────────────────────────────────────────

@MainActor
final class HistoryViewModel: ObservableObject {

    @Published var transactions: [EnrichedContentTransaction] = []
    @Published var isLoading    = true
    @Published var errorMessage: String? = nil

    private let db            = Firestore.firestore()
    private let currentUserId = Auth.auth().currentUser?.uid ?? ""
    private var profileCache: [String: UserProfile] = [:]

    func load() {
        guard !currentUserId.isEmpty else { return }

        let group = DispatchGroup()
        var all: [ContentTransaction] = []

        let completedStatuses: [String] = [
            TransactionStatus.completed.rawValue,
            TransactionStatus.declined.rawValue,
            TransactionStatus.cancelled.rawValue
        ]

        // Transactions I sent
        group.enter()
        db.collection("content_transactions")
            .whereField("from_user_id", isEqualTo: currentUserId)
            .whereField("status", in: completedStatuses)
            .order(by: "created_at", descending: true)
            .limit(to: 100)
            .getDocuments { snap, _ in
                defer { group.leave() }
                let txs = snap?.documents.compactMap {
                    ContentTransaction(id: $0.documentID, data: $0.data())
                } ?? []
                all.append(contentsOf: txs)
            }

        // Transactions I received
        group.enter()
        db.collection("content_transactions")
            .whereField("to_user_id", isEqualTo: currentUserId)
            .whereField("status", in: completedStatuses)
            .order(by: "created_at", descending: true)
            .limit(to: 100)
            .getDocuments { snap, _ in
                defer { group.leave() }
                let txs = snap?.documents.compactMap {
                    ContentTransaction(id: $0.documentID, data: $0.data())
                } ?? []
                all.append(contentsOf: txs)
            }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let sorted = all.sorted { $0.createdAt > $1.createdAt }
            Task { await self.enrich(txs: sorted) }
        }
    }

    private func enrich(txs: [ContentTransaction]) async {
        var enriched: [EnrichedContentTransaction] = []

        for tx in txs {
            let otherId = tx.otherUserId(currentUserId: currentUserId)
            var profile: UserProfile? = nil

            if let otherId {
                if let cached = profileCache[otherId] {
                    profile = cached
                } else {
                    let fetched = await fetchProfile(userId: otherId)
                    if let fetched { profileCache[otherId] = fetched }
                    profile = fetched
                }
            }
            enriched.append(EnrichedContentTransaction(transaction: tx, otherProfile: profile))
        }

        transactions = enriched
        isLoading    = false
    }

    private func fetchProfile(userId: String) async -> UserProfile? {
        await withCheckedContinuation { continuation in
            db.collection("users").document(userId).getDocument { snap, _ in
                guard let data = snap?.data() else {
                    continuation.resume(returning: nil); return
                }
                continuation.resume(returning: UserProfile(
                    id:                userId,
                    name:              data["name"] as? String ?? "",
                    username:          data["username"] as? String ?? "",
                    profilePictureUrl: data["profilePictureUrl"] as? String,
                    totalEarned:       data["totalEarned"] as? Double ?? 0,
                    averageRating:     data["averageRating"] as? Double ?? 0,
                    ratingCount:       data["ratingCount"] as? Int ?? 0
                ))
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - HistoryView
// ─────────────────────────────────────────────────────────────

struct HistoryView: View {

    @StateObject private var vm           = HistoryViewModel()
    @State private var selectedTransaction: EnrichedContentTransaction? = nil
    @State private var filter:              HistoryFilter = .all

    private let currentUserId = Auth.auth().currentUser?.uid ?? ""

    enum HistoryFilter: String, CaseIterable {
        case all      = "All"
        case requests = "Requests"
        case offers   = "Offers"
    }

    private var filtered: [EnrichedContentTransaction] {
        switch filter {
        case .all:      return vm.transactions
        case .requests: return vm.transactions.filter { $0.transaction.type == .request }
        case .offers:   return vm.transactions.filter { $0.transaction.type == .offer }
        }
    }

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Filter chips
                HStack(spacing: 8) {
                    ForEach(HistoryFilter.allCases, id: \.self) { f in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { filter = f }
                        } label: {
                            Text(f.rawValue)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(filter == f ? .white : AppTheme.secondaryText)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(filter == f ? AppTheme.accent : AppTheme.cardBackground)
                                .cornerRadius(200)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                if vm.isLoading {
                    Spacer()
                    ProgressView().tint(AppTheme.primaryText)
                    Spacer()
                } else if filtered.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, enriched in
                                Button {
                                    selectedTransaction = enriched
                                } label: {
                                    HistoryRow(enriched: enriched, currentUserId: currentUserId)
                                }
                                .buttonStyle(.plain)

                                if index < filtered.count - 1 {
                                    Divider()
                                        .background(AppTheme.divider)
                                        .padding(.leading, 76)
                                }
                            }
                        }
                        .background(AppTheme.cardBackground)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Analytics.shared.trackScreen(name: "history_view")
            vm.load()
        }
        .sheet(item: $selectedTransaction) { enriched in
            HistoryDetailView(
                enriched: enriched,
                currentUserId: currentUserId,
                onDismiss: { selectedTransaction = nil }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.secondaryText.opacity(0.3))
            Text("No history yet")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.primaryText)
            Text("Completed transactions will appear here")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.secondaryText)
            Spacer()
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - HistoryRow
// ─────────────────────────────────────────────────────────────

struct HistoryRow: View {

    let enriched:      EnrichedContentTransaction
    let currentUserId: String

    private var tx: ContentTransaction { enriched.transaction }
    private var isCreator: Bool { tx.isCreator(currentUserId: currentUserId) }
    private var iSentThis: Bool { tx.fromUserId == currentUserId }

    var body: some View {
        HStack(spacing: 14) {

            // Thumbnail if photo exists, otherwise avatar
            ZStack {
                if let photoUrl = tx.photoUrl, tx.status == .completed {
                    AsyncImage(url: URL(string: photoUrl)) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        AppTheme.cardHighlight
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    ProfilePictureView(url: enriched.otherProfile?.profilePictureUrl, size: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Type badge overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(tx.type == .request ? "📸" : "🎁")
                            .font(.system(size: 10))
                            .frame(width: 18, height: 18)
                            .background(AppTheme.pageBackground)
                            .clipShape(Circle())
                            .offset(x: 4, y: 4)
                    }
                }
                .frame(width: 52, height: 52)
            }
            .padding(.leading, 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(enriched.otherProfile?.name ?? "Someone")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)

                Text(tx.description)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.secondaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    statusBadge
                    if let rating = tx.rating {
                        Text("\(rating)⭐")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                // Show earnings for creator, cost for payer
                if isCreator && tx.status == .completed {
                    Text("+$\(String(format: "%.2f", tx.creatorPayout))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.green)
                } else if !isCreator && tx.status == .completed {
                    Text("-$\(String(format: "%.2f", tx.price))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                }

                Text(tx.createdAt.timeAgoShort)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.secondaryText)
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(statusColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.1))
            .cornerRadius(4)
    }

    private var statusText: String {
        switch tx.status {
        case .completed:  return iSentThis ? "Sent" : "Received"
        case .declined:   return "Declined"
        case .cancelled:  return "Cancelled"
        default:          return tx.status.rawValue.capitalized
        }
    }

    private var statusColor: Color {
        switch tx.status {
        case .completed:  return AppTheme.green
        case .declined:   return AppTheme.secondaryText
        case .cancelled:  return .red
        default:          return AppTheme.secondaryText
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - HistoryDetailView
// Full screen view of a completed transaction with photo
// ─────────────────────────────────────────────────────────────

struct HistoryDetailView: View {

    let enriched:      EnrichedContentTransaction
    let currentUserId: String
    let onDismiss:     () -> Void

    @State private var showingFullPhoto = false

    private var tx: ContentTransaction { enriched.transaction }
    private var isCreator: Bool { tx.isCreator(currentUserId: currentUserId) }
    private var otherName: String { enriched.otherProfile?.name ?? "Someone" }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // ── Photo ──────────────────────────────
                        if let photoUrl = tx.photoUrl {
                            Button { showingFullPhoto = true } label: {
                                AsyncImage(url: URL(string: photoUrl)) { img in
                                    img
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 280)
                                        .clipped()
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.black.opacity(0.02))
                                                .overlay(
                                                    VStack {
                                                        Spacer()
                                                        HStack {
                                                            Spacer()
                                                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                                .font(.system(size: 14, weight: .bold))
                                                                .foregroundColor(.white)
                                                                .padding(8)
                                                                .background(Color.black.opacity(0.4))
                                                                .clipShape(Circle())
                                                                .padding(12)
                                                        }
                                                    }
                                                )
                                        )
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(AppTheme.cardBackground)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 280)
                                        .overlay(ProgressView().tint(AppTheme.secondaryText))
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        }

                        // ── People ─────────────────────────────
                        HStack(spacing: 16) {
                            ProfilePictureView(url: enriched.otherProfile?.profilePictureUrl, size: 48)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(otherName)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(AppTheme.primaryText)
                                if let username = enriched.otherProfile?.username {
                                    Text("@\(username)")
                                        .font(.system(size: 13))
                                        .foregroundColor(AppTheme.secondaryText)
                                }
                            }

                            Spacer()

                            // Money summary
                            VStack(alignment: .trailing, spacing: 3) {
                                if isCreator && tx.status == .completed {
                                    Text("+$\(String(format: "%.2f", tx.creatorPayout))")
                                        .font(.system(size: 18, weight: .black))
                                        .foregroundColor(AppTheme.green)
                                    Text("earned")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.secondaryText)
                                } else if !isCreator {
                                    Text("-$\(String(format: "%.2f", tx.price))")
                                        .font(.system(size: 18, weight: .black))
                                        .foregroundColor(AppTheme.primaryText)
                                    Text("paid")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.secondaryText)
                                }
                            }
                        }
                        .padding(16)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)

                        // ── Details card ───────────────────────
                        VStack(spacing: 0) {
                            detailRow(
                                label: "Type",
                                value: tx.type == .request ? "📸 Request" : "🎁 Offer"
                            )
                            Divider().background(AppTheme.divider).padding(.leading, 16)
                            detailRow(
                                label: tx.type == .request ? "The Request" : "The Teaser",
                                value: tx.description
                            )
                            Divider().background(AppTheme.divider).padding(.leading, 16)
                            detailRow(
                                label: "Status",
                                value: tx.status.rawValue
                                    .replacingOccurrences(of: "_", with: " ")
                                    .capitalized
                            )
                            if let rating = tx.rating {
                                Divider().background(AppTheme.divider).padding(.leading, 16)
                                detailRow(label: "Rating", value: "\(rating)⭐")
                            }
                            Divider().background(AppTheme.divider).padding(.leading, 16)
                            detailRow(
                                label: "Date",
                                value: tx.createdAt.formatted(date: .long, time: .shortened)
                            )
                            if let completedAt = tx.completedAt {
                                Divider().background(AppTheme.divider).padding(.leading, 16)
                                detailRow(
                                    label: "Completed",
                                    value: completedAt.formatted(date: .long, time: .shortened)
                                )
                            }
                        }
                        .background(AppTheme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)

                        // Rating card if completed and not yet rated
                        if tx.status == .completed && tx.rating == nil && !isCreator {
                            RatingCard(transactionId: tx.id, onRated: { })
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 40)
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
        .fullScreenCover(isPresented: $showingFullPhoto) {
            if let photoUrl = tx.photoUrl {
                FullScreenPhotoView(photoUrl: photoUrl, onDismiss: { showingFullPhoto = false })
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.secondaryText)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.primaryText)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - FullScreenPhotoView
// ─────────────────────────────────────────────────────────────

struct FullScreenPhotoView: View {

    let photoUrl: String
    let onDismiss: () -> Void

    @State private var scale:  CGFloat = 1.0
    @State private var offset: CGSize  = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: photoUrl)) { img in
                img
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { scale = max(1, $0) }
                            .onEnded   { _ in
                                if scale < 1 { withAnimation { scale = 1; offset = .zero } }
                            }
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { offset = $0.translation }
                            .onEnded { _ in
                                if scale <= 1 { withAnimation { offset = .zero } }
                            }
                    )
            } placeholder: {
                ProgressView().tint(.white)
            }

            // Close button
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
                    .padding(.top, 60)
                    .padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .ignoresSafeArea()
        .onTapGesture { if scale <= 1 { onDismiss() } }
    }
}
