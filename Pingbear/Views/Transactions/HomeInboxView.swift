import SwiftUI
import FirebaseAuth
import FirebaseFunctions
import UserNotifications

struct HomeInboxView: View {

    @StateObject private var vm = InboxViewModel()
    @State private var showingNewTransaction     = false
    @State private var selectedTransaction:       EnrichedContentTransaction? = nil
    @State private var showingNotificationPrompt = false

    private let currentUserId = Auth.auth().currentUser?.uid ?? ""
    private let functions     = Functions.functions()

    // ── Section logic ─────────────────────────────────────────

    private var yourTurn: [EnrichedContentTransaction] {
        (vm.incoming + vm.outgoing)
            .filter { needsAction($0) }
            .sorted { $0.transaction.createdAt > $1.transaction.createdAt }
    }

    private var inProgress: [EnrichedContentTransaction] {
        (vm.incoming + vm.outgoing)
            .filter { isInProgress($0) }
            .sorted { $0.transaction.createdAt > $1.transaction.createdAt }
    }

    private var recent: [EnrichedContentTransaction] {
        (vm.incoming + vm.outgoing)
            .filter { isRecent($0) }
            .sorted { $0.transaction.createdAt > $1.transaction.createdAt }
    }

    private func needsAction(_ e: EnrichedContentTransaction) -> Bool {
        let tx           = e.transaction
        let iAmCreator   = tx.toUserId == currentUserId
        let iAmPayer     = tx.fromUserId == currentUserId
        switch tx.status {
        case .pendingAcceptance: return iAmCreator
        case .accepted:          return iAmCreator
        case .fulfilled:         return iAmPayer
        default:                 return false
        }
    }

    private func isInProgress(_ e: EnrichedContentTransaction) -> Bool {
        let tx       = e.transaction
        let iAmPayer = tx.fromUserId == currentUserId
        switch tx.status {
        case .pendingSignup:     return true
        case .pendingAcceptance: return iAmPayer
        case .accepted:          return iAmPayer
        case .fulfilled:         return !iAmPayer
        default:                 return false
        }
    }

    private func isRecent(_ e: EnrichedContentTransaction) -> Bool {
        switch e.transaction.status {
        case .completed, .declined, .cancelled: return true
        default: return false
        }
    }

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar

                if vm.isLoading {
                    Spacer()
                    ProgressView().tint(AppTheme.primaryText)
                    Spacer()
                } else if yourTurn.isEmpty && inProgress.isEmpty && recent.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            if !yourTurn.isEmpty {
                                sectionHeader("Your Turn", count: yourTurn.count, color: AppTheme.accent)
                                VStack(spacing: 10) {
                                    ForEach(yourTurn) { enriched in
                                        transactionCard(enriched, style: .urgent)
                                            .contextMenu { contextMenuItems(enriched) }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }

                            if !inProgress.isEmpty {
                                sectionHeader("In Progress", count: nil, color: AppTheme.secondaryText)
                                VStack(spacing: 10) {
                                    ForEach(inProgress) { enriched in
                                        transactionCard(enriched, style: .normal)
                                            .contextMenu { contextMenuItems(enriched) }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }

                            if !recent.isEmpty {
                                sectionHeader("Recent", count: nil, color: AppTheme.secondaryText)
                                VStack(spacing: 10) {
                                    ForEach(recent) { enriched in
                                        transactionCard(enriched, style: .dimmed)
                                            .contextMenu { contextMenuItems(enriched) }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 100)
                    }
                }
            }

            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        Analytics.shared.trackTap(elementId: "new_request_fab", screenName: "home_inbox")
                        showingNewTransaction = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(AppTheme.accent)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 40)
                }
            }

            if showingNotificationPrompt {
                NotificationPermissionPrompt(
                    onAllow: { requestNotifications(); showingNotificationPrompt = false },
                    onDeny: {
                        Analytics.shared.track(event: AnalyticsEvent.notificationPermissionDenied, properties: ["screen": "home_inbox"])
                        showingNotificationPrompt = false
                    }
                )
                .zIndex(100)
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "home_inbox")
            vm.start()
            checkNotificationStatus()
        }
        .onDisappear { vm.stop() }
        .fullScreenCover(isPresented: $showingNewTransaction) {
            NewTransactionView(onDismiss: { showingNewTransaction = false })
        }
        .fullScreenCover(item: $selectedTransaction) { enriched in
            TransactionDetailView(enriched: enriched, onDismiss: { selectedTransaction = nil })
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Nav bar
    // ─────────────────────────────────────────────────────────

    private var navBar: some View {
        HStack {
            Text("SocialStar")
                .font(.system(size: 22, weight: .black))
                .foregroundColor(AppTheme.primaryText)
            Spacer()
            NavigationLink { HistoryView() } label: {
                Image(systemName: "clock.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.iconColor)
                    .padding(.leading, 6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func sectionHeader(_ title: String, count: Int?, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
                .textCase(.uppercase)
            if let count {
                Text("\(count)")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.white)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(AppTheme.accent)
                    .clipShape(Circle())
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Cards
    // ─────────────────────────────────────────────────────────

    enum CardStyle { case urgent, normal, dimmed }

    private func transactionCard(_ enriched: EnrichedContentTransaction, style: CardStyle) -> some View {
        Button {
            Analytics.shared.track(event: AnalyticsEvent.transactionViewed,
                                   properties: [AnalyticsProperty.transactionId: enriched.id])
            selectedTransaction = enriched
        } label: {
            InboxCard(enriched: enriched, currentUserId: currentUserId, style: style)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func contextMenuItems(_ enriched: EnrichedContentTransaction) -> some View {
        if isRecent(enriched) {
            Button(role: .destructive) {
                Task { await dismiss(enriched) }
            } label: {
                Label("Remove from Inbox", systemImage: "xmark")
            }
        }
        Button { selectedTransaction = enriched } label: {
            Label("View Details", systemImage: "eye")
        }
    }

    private func dismiss(_ enriched: EnrichedContentTransaction) async {
        do {
            try await functions.httpsCallable("dismissTransaction").call(["transactionId": enriched.id])
            Analytics.shared.track(event: AnalyticsEvent.transactionDismissed,
                                   properties: [AnalyticsProperty.transactionId: enriched.id])
        } catch {
            vm.errorMessage = error.localizedDescription
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(AppTheme.accent.opacity(0.1)).frame(width: 80, height: 80)
                    Image(systemName: "camera.fill").font(.system(size: 32)).foregroundColor(AppTheme.accent)
                }
                Text("Nothing here yet")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
                Text("Tap + to request a video from a friend")
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .notDetermined {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showingNotificationPrompt = true }
                }
            }
        }
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    Analytics.shared.track(event: AnalyticsEvent.notificationPermissionGranted,
                                           properties: ["screen": "home_inbox"])
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - InboxCard
// ─────────────────────────────────────────────────────────────

struct InboxCard: View {

    let enriched:      EnrichedContentTransaction
    let currentUserId: String
    let style:         HomeInboxView.CardStyle

    private var tx: ContentTransaction { enriched.transaction }
    private var iAmCreator: Bool { tx.toUserId == currentUserId }
    private var iAmPayer:   Bool { tx.fromUserId == currentUserId }
    private var isDimmed:   Bool { style == .dimmed }

    var body: some View {
        HStack(spacing: 14) {

            ProfilePictureView(url: enriched.otherProfile?.profilePictureUrl, size: 48)
                .opacity(isDimmed ? 0.5 : 1)

            VStack(alignment: .leading, spacing: 5) {
                Text(enriched.otherProfile?.name ?? "Someone")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(isDimmed ? AppTheme.secondaryText : AppTheme.primaryText)

                Text(tx.description)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.secondaryText)
                    .lineLimit(1)

                Text(statusLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(statusLabelColor)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("$\(String(format: "%.2f", tx.price))")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(isDimmed ? AppTheme.secondaryText : AppTheme.primaryText)

                directionBadge

                Text(tx.createdAt.timeAgoShort)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.secondaryText)
            }
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(style == .urgent ? AppTheme.accent.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .opacity(isDimmed ? 0.7 : 1)
    }

    private var cardBackground: Color {
        style == .urgent ? AppTheme.accent.opacity(0.04) : AppTheme.cardBackground
    }

    private var directionBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: iAmPayer ? "arrow.up.right" : "arrow.down.left")
                .font(.system(size: 9, weight: .bold))
            Text(iAmPayer ? "Sent" : "Received")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(iAmPayer ? AppTheme.secondaryText : AppTheme.accent)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background((iAmPayer ? AppTheme.secondaryText : AppTheme.accent).opacity(0.08))
        .cornerRadius(200)
    }

    private var statusLabel: String {
        switch tx.status {
        case .pendingSignup:
            return "Waiting for them to join"
        case .pendingAcceptance:
            return iAmCreator ? "Tap to respond 📸" : "Waiting for response"
        case .accepted:
            return iAmCreator ? "Tap to send your video 📸" : "They're working on it..."
        case .fulfilled:
            return iAmPayer ? "Tap to see your video 👀" : "Video sent — waiting for them to view"
        case .completed:
            if let rating = tx.rating { return "Completed · \(rating)⭐" }
            return "Completed ✓"
        case .declined:
            return iAmPayer ? "\(enriched.otherProfile?.name ?? "They") declined" : "You declined"
        case .cancelled:
            return iAmPayer ? "You cancelled" : "\(enriched.otherProfile?.name ?? "They") cancelled"
        }
    }

    private var statusLabelColor: Color {
        switch tx.status {
        case .pendingAcceptance: return style == .urgent ? AppTheme.accent : AppTheme.secondaryText
        case .accepted:          return style == .urgent ? AppTheme.accent : AppTheme.secondaryText
        case .fulfilled:         return style == .urgent ? AppTheme.green  : AppTheme.secondaryText
        default:                 return AppTheme.secondaryText
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - NotificationPermissionPrompt
// ─────────────────────────────────────────────────────────────

struct NotificationPermissionPrompt: View {

    let onAllow: () -> Void
    let onDeny:  () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 24) {
                ZStack {
                    Circle().fill(AppTheme.accent.opacity(0.15)).frame(width: 80, height: 80)
                    Image(systemName: "bell.badge.fill").font(.system(size: 36)).foregroundColor(AppTheme.accent)
                }
                VStack(spacing: 8) {
                    Text("Don't miss a thing")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                    Text("Get notified when friends respond to your requests and when videos are ready")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                VStack(spacing: 10) {
                    Button(action: onAllow) {
                        Text("Allow Notifications")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.accent)
                            .cornerRadius(200)
                    }
                    Button(action: onDeny) {
                        Text("Not now").font(.system(size: 15)).foregroundColor(AppTheme.secondaryText)
                    }
                }
            }
            .padding(28)
            .background(AppTheme.pageBackground)
            .cornerRadius(24)
            .padding(.horizontal, 32)
        }
    }
}

extension Date {
    var timeAgoShort: String {
        let seconds = Int(-timeIntervalSinceNow)
        if seconds < 60    { return "now" }
        if seconds < 3600  { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86400)d"
    }
}
