import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import MessageUI
import Contacts
import PhotosUI
import AVFoundation
import UserNotifications

// ─────────────────────────────────────────────────────────────
// MARK: - NewTransactionView
//
// Step 1: Type (Request vs Offer)
// Request path: Description → Friends → Reward
// Offer path:   Record video → Friends → Reward
// ─────────────────────────────────────────────────────────────

struct NewTransactionView: View {

    let onDismiss: () -> Void

    // The flow is normally Type → Content → Friends → Price. The
    // Notifications step is spliced in between Friends and Price only
    // when iOS notification permission is still undetermined — checked
    // once on appear and cached, so the step count (and progress bar)
    // stays stable for the rest of the session instead of changing
    // shape mid-flow.
    private enum FlowStep: Equatable { case type, content, friends, notifications, price }

    @State private var step:                 Int             = 1
    @State private var selectedType:         TransactionType = .request

    // Request-only
    @State private var description:          String          = ""

    // Offer-only
    @State private var capturedVideoURL:     URL?            = nil
    @State private var showingCamera:        Bool            = false

    // Shared
    @State private var price:                String      = ""
    @State private var selectedFriendIds:    Set<String> = []
    @State private var selectedOnAppIds:     Set<String> = []
    @State private var selectedOffAppHashes: Set<String> = []
    @State private var isSending:            Bool        = false
    @State private var errorMessage:         String?     = nil
    @State private var showingComposer:      Bool        = false
    @State private var showWalletSheet:      Bool        = false
    @State private var offAppNumbers:        [String]    = []
    @State private var offAppMessage:        String      = ""
    @State private var friendsSearchText:    String      = ""

    @State private var walletBalance:   Double                = 0.0
    @State private var balanceListener: ListenerRegistration? = nil

    // nil = not checked yet (treated as "skip the step" so we never block
    // step 1 on this async check). Set once on appear; not re-checked
    // mid-flow so the step list can't change shape after the user starts.
    @State private var notificationPermissionUndetermined: Bool? = nil

    // Offer upload state, shown as a full-screen takeover (mirrors
    // VideoPreviewConfirmView's upload UX from the request fulfillment flow)
    @State private var offerUploadProgress: Double = 0

    @StateObject private var contactVM = ContactViewModel()

    private let presetPrices  = ["0.50", "1.00", "2.00", "5.00", "10.00"]
    private let suggestionPool = [
        "Tell me a joke",
        "Go sing happy birthday to someone",
        "Scream super loud",
        "Shave your head"
    ]
    @State private var suggestions: [String] = []
    private let functions     = Functions.functions()
    private let currentUserId = Auth.auth().currentUser?.uid ?? ""
    private let db            = Firestore.firestore()

    // Step numbering differs slightly by type, and conditionally includes
    // the Notifications step — see activeSteps below.
    private var activeSteps: [FlowStep] {
        var steps: [FlowStep] = [.type, .content, .friends]
        if notificationPermissionUndetermined == true { steps.append(.notifications) }
        steps.append(.price)
        return steps
    }

    private var currentFlowStep: FlowStep { activeSteps[min(step, activeSteps.count) - 1] }
    private var totalSteps: Int { activeSteps.count }

    private var totalSelected: Int {
        selectedFriendIds.count + selectedOnAppIds.count + selectedOffAppHashes.count
    }

    private var priceDouble:  Double { Double(price) ?? 0 }
    private var priceValid:   Bool   { priceDouble >= 0.50 && priceDouble <= 20.00 }

    // Requests escrow reward × recipients; offers move no money on send.
    private var totalEscrow:  Double { selectedType == .request ? priceDouble * Double(totalSelected) : 0 }
    private var hasSufficientBalance: Bool { selectedType == .offer || walletBalance >= totalEscrow }

    private var step2Valid: Bool {
        selectedType == .request
            ? !description.trimmingCharacters(in: .whitespaces).isEmpty
            : capturedVideoURL != nil
    }
    private var step3Valid: Bool { totalSelected > 0 }
    private var step4Valid: Bool { priceValid && hasSufficientBalance }
    private var canSend:    Bool { step4Valid && !isSending }

    private var filteredFriends: [FriendContact] {
        guard !friendsSearchText.isEmpty else { return contactVM.friends }
        return contactVM.friends.filter {
            $0.name.localizedCaseInsensitiveContains(friendsSearchText) ||
            $0.username.localizedCaseInsensitiveContains(friendsSearchText)
        }
    }

    private var filteredOnAppContacts: [Contact] {
        guard !friendsSearchText.isEmpty else { return contactVM.onAppContacts }
        return contactVM.onAppContacts.filter {
            $0.fullName.localizedCaseInsensitiveContains(friendsSearchText) ||
            $0.username.localizedCaseInsensitiveContains(friendsSearchText)
        }
    }

    private var filteredOffAppContacts: [Contact] {
        guard !friendsSearchText.isEmpty else { return contactVM.offAppContacts }
        return contactVM.offAppContacts.filter { $0.fullName.localizedCaseInsensitiveContains(friendsSearchText) }
    }

    private var hasNoSearchResults: Bool {
        !friendsSearchText.isEmpty && filteredFriends.isEmpty && filteredOnAppContacts.isEmpty && filteredOffAppContacts.isEmpty
    }

    private var selectedRecipients: [(name: String, isOffApp: Bool)] {
        var result: [(String, Bool)] = []
        for f in contactVM.friends where selectedFriendIds.contains(f.id) { result.append((f.name, false)) }
        for c in contactVM.onAppContacts where selectedOnAppIds.contains(c.phoneNumber) { result.append((c.fullName, false)) }
        for c in contactVM.offAppContacts where selectedOffAppHashes.contains(c.phoneHash) { result.append((c.fullName, true)) }
        return result
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Body
    // ─────────────────────────────────────────────────────────

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                progressBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                ZStack {
                    if currentFlowStep == .type          { typeStep          .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                    if currentFlowStep == .content        { contentStep      .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                    if currentFlowStep == .friends         { friendsStep     .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                    if currentFlowStep == .notifications  { notificationsStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                    if currentFlowStep == .price          { priceStep        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                }
                .animation(.easeInOut(duration: 0.25), value: step)
            }
            VStack { Spacer(); bottomButton }

            // Offer upload takeover
            if offerSendState == .uploading {
                VideoUploadStatusView(progress: offerUploadProgress, statusText: "Uploading your video")
                    .ignoresSafeArea()
            } else if offerSendState == .finalizing {
                VideoUploadStatusView(progress: 1.0, statusText: "Almost done...")
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "new_transaction_step_1")
            contactVM.fetchFriendsFromFirestore()
            startBalanceListener()
            checkNotificationPermission()
        }
        .onDisappear { stopBalanceListener() }
        .fullScreenCover(isPresented: $showingCamera) {
            OfferRecordCameraView(
                onRecorded: { url in
                    capturedVideoURL = url
                    showingCamera    = false
                },
                onCancel: { showingCamera = false }
            )
        }
        .sheet(isPresented: $showingComposer) {
            if !offAppNumbers.isEmpty {
                OffAppInviteComposer(
                    recipients: offAppNumbers,
                    body: offAppMessage,
                    onFinish: { result in
                        switch result {
                        case .sent:
                            Analytics.shared.track(
                                event: AnalyticsEvent.invitesSent,
                                properties: [AnalyticsProperty.recipientCount: offAppNumbers.count]
                            )
                        case .cancelled:
                            Analytics.shared.track(event: AnalyticsEvent.inviteComposerCancelled)
                        case .failed:
                            Analytics.shared.track(event: AnalyticsEvent.inviteComposerFailed)
                        @unknown default:
                            break
                        }
                        showingComposer = false
                        onDismiss()
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showWalletSheet) {
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
    }

    private enum OfferSendState { case idle, uploading, finalizing }
    @State private var offerSendState: OfferSendState = .idle

    // ─────────────────────────────────────────────────────────
    // MARK: - Notifications step support
    //
    // Checked once on appear and cached in notificationPermissionUndetermined.
    // If still undetermined, activeSteps splices the Notifications step in
    // between Friends and Price. Its primary button fires the real system
    // prompt and advances regardless of outcome; "Skip for now" advances
    // without touching the OS dialog at all (so it'll be offered again
    // next time, same as ignoring it would).
    // ─────────────────────────────────────────────────────────

    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationPermissionUndetermined = (settings.authorizationStatus == .notDetermined)
            }
        }
    }

    private func requestNotificationsAndAdvance() {
        Analytics.shared.trackTap(elementId: "allow_notifications", screenName: "new_transaction_notifications")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    Analytics.shared.track(event: AnalyticsEvent.notificationPermissionGranted,
                                           properties: ["screen": "new_transaction_notifications"])
                } else {
                    Analytics.shared.track(event: AnalyticsEvent.notificationPermissionDenied,
                                           properties: ["screen": "new_transaction_notifications"])
                }
                advance()
            }
        }
    }

    private func skipNotifications() {
        Analytics.shared.trackTap(elementId: "skip_notifications", screenName: "new_transaction_notifications")
        advance()
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Balance listener
    // ─────────────────────────────────────────────────────────

    private func startBalanceListener() {
        guard !currentUserId.isEmpty else { return }
        balanceListener = db.collection("users").document(currentUserId)
            .addSnapshotListener { snap, _ in
                walletBalance = snap?.data()?["wallet_balance"] as? Double ?? 0.0
            }
    }

    private func stopBalanceListener() { balanceListener?.remove(); balanceListener = nil }

    // ─────────────────────────────────────────────────────────
    // MARK: - Header
    // ─────────────────────────────────────────────────────────

    private var header: some View {
        HStack {
            Button {
                if step > 1 { withAnimation { step -= 1 } }
                else { onDismiss() }
            } label: {
                Image(systemName: step > 1 ? "arrow.left" : "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.iconColor)
            }
            Spacer()
            Text(headerTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.primaryText)
            Spacer()
            Color.clear.frame(width: 24, height: 24)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var headerTitle: String {
        switch currentFlowStep {
        case .type:          return "New Video"
        case .content:       return selectedType == .request ? "Your Request" : "Your Video"
        case .friends:       return "Pick Friends"
        case .notifications: return "Notifications"
        case .price:         return selectedType == .request ? "Request Reward" : "Video Price"
        }
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(1...totalSteps, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= step ? AppTheme.accent : AppTheme.divider)
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.25), value: step)
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Step 1: Type
    // ─────────────────────────────────────────────────────────

    private var typeStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What do you want to do?")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(AppTheme.primaryText)
                }

                typeCard(
                    type: .request, icon: "clipboard-pen", title: "Request a Video",
                    subtitle: "Ask a friend to record something for you. You set the reward and they decide if it's worth it."
                )

                typeCard(
                    type: .offer, icon: "send", title: "Send a Video",
                    subtitle: "Record a video and send it to friends. They pay to unlock and see what's inside."
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }

    private func typeCard(type: TransactionType, icon: String, title: String, subtitle: String) -> some View {
        Button {
            selectedType = type
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 16) {
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(selectedType == type ? AppTheme.accent : AppTheme.secondaryText)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .frame(width: 56, height: 56)
                    .background(.clear)
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: selectedType == type ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(selectedType == type ? AppTheme.accent : AppTheme.secondaryText.opacity(0.3))
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selectedType)
            }
            .padding(20)
            .background(selectedType == type ? AppTheme.accent.opacity(0.06) : AppTheme.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selectedType == type ? AppTheme.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Step 2: Content (branches by type)
    // ─────────────────────────────────────────────────────────

    @ViewBuilder
    private var contentStep: some View {
        if selectedType == .request {
            descriptionStep
        } else {
            offerVideoStep
        }
    }

    // ── Request: description ──────────────────────────────────

    private var descriptionStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What's your video request?")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(AppTheme.primaryText)
                }

                TextField("e.g. Go sing happy birthday to someone", text: $description, axis: .vertical)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
                    .lineLimit(5...10)
                    .padding(14)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .tint(AppTheme.accent)
                    .onChange(of: description) { if $0.count > 120 { description = String($0.prefix(120)) } }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Need ideas?")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.secondaryText)
                        .textCase(.uppercase)
                        .padding(.leading, 4)

                    suggestionChips
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
        .onAppear { suggestions = suggestionPool.shuffled() }
    }

    private var suggestionChips: some View {
        FlowLayout(spacing: 8) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    description = suggestion
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text(suggestion)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(description == suggestion ? .white : AppTheme.primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(description == suggestion ? AppTheme.accent : AppTheme.cardBackground)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // ── Offer: record the mystery video ────────────────────────

    private var offerVideoStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Record your video")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(AppTheme.primaryText)
                }

                Button {
                    Analytics.shared.trackTap(elementId: "record_offer_video", screenName: "new_transaction_step_2")
                    showingCamera = true
                } label: {
                    HStack {
                        Spacer(minLength: 0)
                        ZStack {
                            if let url = capturedVideoURL {
                                OfferVideoThumbnail(
                                    url: url,
                                    isActive: Binding(get: { !showingCamera }, set: { _ in })
                                )
                                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                                .frame(maxWidth: 280)
                                .clipped()
                                .cornerRadius(16)
                                .overlay(
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            Label("Retake", systemImage: "arrow.triangle.2.circlepath")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(.ultraThinMaterial)
                                                .cornerRadius(20)
                                            Spacer()
                                        }
                                        .padding(.bottom, 12)
                                    }
                                )
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(AppTheme.cardBackground)
                                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                                    .frame(maxWidth: 280)
                                    .overlay(
                                        VStack(spacing: 10) {
                                            Image(systemName: "video.fill")
                                                .font(.system(size: 28))
                                                .foregroundColor(AppTheme.secondaryText)
                                            Text("Tap to record your video")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(AppTheme.secondaryText)
                                        }
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(AppTheme.divider, lineWidth: 1)
                                    )
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Step 3: Friends
    // ─────────────────────────────────────────────────────────

    private var friendsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(selectedType == .request ? "Who should do this?" : "Who gets this?")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(AppTheme.primaryText)
                    Spacer()
                    if totalSelected > 0 {
                        Text("\(totalSelected) selected")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                    }
                }

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.secondaryText).padding(.leading, 12)
                    TextField("Search friends and contacts", text: $friendsSearchText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.primaryText)
                        .tint(AppTheme.accent)
                        .padding(.vertical, 10)
                    if !friendsSearchText.isEmpty {
                        Button { friendsSearchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(AppTheme.secondaryText)
                        }
                        .padding(.trailing, 12)
                    }
                }
                .background(AppTheme.cardBackground)
                .cornerRadius(10)

                if hasNoSearchResults {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.system(size: 32)).foregroundColor(AppTheme.secondaryText)
                        Text("No results for \"\(friendsSearchText)\"")
                            .font(.system(size: 15, weight: .semibold)).foregroundColor(AppTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
                } else {
                    if !filteredFriends.isEmpty {
                        sectionLabel("Friends")
                        VStack(spacing: 0) {
                            ForEach(filteredFriends) { friend in
                                friendRow(name: friend.name, subtitle: "@\(friend.username)",
                                          imageUrl: friend.profilePictureUrl,
                                          isSelected: selectedFriendIds.contains(friend.id))
                                { toggle(&selectedFriendIds, id: friend.id) }
                                if friend.id != filteredFriends.last?.id { Divider().background(AppTheme.divider) }
                            }
                        }
                        .background(AppTheme.cardBackground).cornerRadius(12)
                    }
                    contactsSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
        .onAppear {
            let status = CNContactStore.authorizationStatus(for: .contacts)
            if status == .authorized { contactVM.requestContactAccess() }
        }
    }

    @ViewBuilder
    private var contactsSection: some View {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .authorized {
            if contactVM.isLoading {
                HStack { Spacer(); ProgressView().tint(AppTheme.primaryText); Spacer() }.padding(.vertical, 24)
            } else {
                if !filteredOnAppContacts.isEmpty {
                    sectionLabel("On SocialStar")
                    VStack(spacing: 0) {
                        ForEach(filteredOnAppContacts) { contact in
                            friendRow(name: contact.fullName, subtitle: "@\(contact.username)",
                                      imageUrl: contact.profileImageUrl,
                                      isSelected: selectedOnAppIds.contains(contact.phoneNumber))
                            { toggle(&selectedOnAppIds, id: contact.phoneNumber) }
                            if contact.id != filteredOnAppContacts.last?.id { Divider().background(AppTheme.divider) }
                        }
                    }
                    .background(AppTheme.cardBackground).cornerRadius(12)
                }
                if !filteredOffAppContacts.isEmpty {
                    sectionLabel("Invite to SocialStar")
                    VStack(spacing: 0) {
                        ForEach(filteredOffAppContacts) { contact in
                            friendRow(name: contact.fullName, subtitle: "Not on the app yet",
                                      imageUrl: nil,
                                      isSelected: selectedOffAppHashes.contains(contact.phoneHash))
                            { toggle(&selectedOffAppHashes, id: contact.phoneHash) }
                            if contact.phoneHash != filteredOffAppContacts.last?.phoneHash { Divider().background(AppTheme.divider) }
                        }
                    }
                    .background(AppTheme.cardBackground).cornerRadius(12)
                }
            }
        } else if status == .denied || status == .restricted {
            emptyStateBox(
                icon: "lock.fill",
                title: "Contacts Access Needed",
                subtitle: "Enable contacts access in Settings to find friends who are already on SocialStar.",
                buttonTitle: "Enable in Settings"
            ) {
                Analytics.shared.trackTap(elementId: "enable_contacts_settings", screenName: "new_transaction_step_3")
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
        } else {
            emptyStateBox(
                icon: "person.crop.circle.badge.plus",
                title: "Find Friends from Contacts",
                subtitle: "We'll match your contacts with people already on SocialStar — your contacts stay private.",
                buttonTitle: "Allow Access"
            ) {
                Analytics.shared.trackTap(elementId: "find_friends_contacts", screenName: "new_transaction_step_3")
                contactVM.requestContactAccess()
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Notifications (conditional — only when permission is
    // still undetermined; see activeSteps)
    // ─────────────────────────────────────────────────────────

    private var notificationsStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(AppTheme.accent.opacity(0.15)).frame(width: 80, height: 80)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 36))
                        .foregroundColor(AppTheme.accent)
                }
                .padding(.top, 40)

                VStack(spacing: 10) {
                    Text("Get notified when your friends respond")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                        .multilineTextAlignment(.center)
                    Text(notificationsSubtext)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }

    private var notificationsSubtext: String {
        let names = selectedRecipients.map { $0.name }
        switch (selectedType, names.count) {
        case (.request, 1):
            return "We'll let you know the moment \(names[0]) responds."
        case (.request, let n) where n > 1:
            return "We'll let you know the moment any of your \(n) friends respond."
        case (.offer, 1):
            return "We'll let you know the moment \(names[0]) unlocks it."
        case (.offer, let n) where n > 1:
            return "We'll let you know the moment any of your \(n) friends unlock it."
        default:
            return selectedType == .request
                ? "We'll let you know the moment they respond."
                : "We'll let you know the moment they unlock it."
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Step 4: Reward / Price
    // ─────────────────────────────────────────────────────────

    private var priceStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedType == .request ? "What's the reward?" : "What's the unlock price?")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(AppTheme.primaryText)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                    ForEach(presetPrices, id: \.self) { preset in
                        Button {
                            price = preset
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text("$\(preset)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(price == preset ? .white : AppTheme.primaryText)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(price == preset ? AppTheme.accent : AppTheme.cardBackground)
                                .cornerRadius(200)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if priceValid {
                    selectedType == .request ? AnyView(requestBreakdownView) : AnyView(offerBreakdownView)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }

    // ── Request: escrow breakdown, per-recipient, balance + top up ──

    private var requestBreakdownView: some View {
        VStack(spacing: 0) {
            ForEach(Array(selectedRecipients.enumerated()), id: \.offset) { _, recipient in
                HStack {
                    Text(recipient.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.secondaryText)
                    Spacer()
                    Text("$\(String(format: "%.2f", priceDouble))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                }
                .padding(.horizontal, 16).padding(.vertical, 16)
                Divider().background(AppTheme.divider)
            }

            HStack {
                Text("Total reward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.secondaryText)
                Spacer()
                Text("$\(String(format: "%.2f", totalEscrow))")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
            }
            .padding(.horizontal, 16).padding(.vertical, 16)

            if !hasSufficientBalance {
                Divider().background(AppTheme.divider)

                HStack {
                    Text("Your balance")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.secondaryText)
                    Spacer()
                    Text("$\(String(format: "%.2f", walletBalance))")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 16).padding(.vertical, 16)

                Divider().background(AppTheme.divider)

                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                        Text("You need $\(String(format: "%.2f", max(0, totalEscrow - walletBalance))) more")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.vertical, 5)
                    Button {
                        Analytics.shared.trackTap(elementId: "top_up_from_new_transaction", screenName: "new_transaction_step_4")
                        Analytics.shared.track(event: AnalyticsEvent.walletTopUpOpened,
                                               properties: ["screen": "new_transaction_step_4"])
                        showWalletSheet = true
                    } label: {
                        Text("Top Up")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(AppTheme.accent).cornerRadius(200)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
            }
        }
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    // ── Offer: simple fee breakdown, no escrow/balance check ────

    private var offerBreakdownView: some View {
        VStack(spacing: 0) {
            feeRow(label: "Unlock price",       value: "$\(String(format: "%.2f", priceDouble))",                color: AppTheme.primaryText)
            Divider().background(AppTheme.divider)
            feeRow(label: "Platform fee (20%)", value: "-$\(String(format: "%.2f", priceDouble * 0.20))",        color: AppTheme.primaryText)
            Divider().background(AppTheme.divider)
            feeRow(label: "You get", value: "$\(String(format: "%.2f", priceDouble * 0.80))",        color: AppTheme.green, valueSize: 20)
        }
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    private func feeRow(label: String, value: String, color: Color, valueSize: CGFloat = 13) -> some View {
        HStack {
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundColor(AppTheme.secondaryText)
            Spacer()
            Text(value).font(.system(size: valueSize, weight: .bold)).foregroundColor(color)
        }
        .padding(.horizontal, 16).padding(.vertical, 16)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Bottom button
    // ─────────────────────────────────────────────────────────

    private var bottomButton: some View {
        Button(action: bottomAction) {
            HStack(spacing: 8) {
                if isSending { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: AppTheme.disabledText)).scaleEffect(0.85) }
                Text(bottomButtonLabel)
                    .font(.system(size: 18, weight: .bold)).foregroundColor(bottomEnabled ? .white : AppTheme.disabledText)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(bottomEnabled ? AppTheme.accent : AppTheme.disabledBackground)
            .cornerRadius(200)
        }
        .disabled(!bottomEnabled)
        .padding(.horizontal, 20).padding(.vertical, 20)
        .background(AppTheme.pageBackground.ignoresSafeArea())
    }

    private var bottomButtonLabel: String {
        if isSending { return "Sending..." }
        switch currentFlowStep {
        case .notifications: return "Continue"
        case .price:          return selectedType == .request ? "Send Request" : "Send Video"
        default:              return "Continue"
        }
    }

    private var bottomEnabled: Bool {
        if isSending { return false }
        switch currentFlowStep {
        case .type:          return true
        case .content:       return step2Valid
        case .friends:       return step3Valid
        case .notifications: return true
        case .price:         return canSend
        }
    }

    private func advance() {
        withAnimation { step += 1 }
        Analytics.shared.trackScreen(name: screenName(for: currentFlowStep))
    }

    private func screenName(for flowStep: FlowStep) -> String {
        switch flowStep {
        case .type:          return "new_transaction_step_1"
        case .content:       return "new_transaction_step_2"
        case .friends:       return "new_transaction_step_3"
        case .notifications: return "new_transaction_notifications"
        case .price:         return "new_transaction_step_4"
        }
    }

    private func bottomAction() {
        switch currentFlowStep {
        case .type:
            Analytics.shared.trackTap(
                elementId: "transaction_type_selected",
                screenName: "new_transaction_step_1",
                properties: [AnalyticsProperty.transactionType: selectedType.rawValue]
            )
            advance()
        case .content:
            advance()
        case .friends:
            advance()
        case .notifications:
            requestNotificationsAndAdvance()
        case .price:
            selectedType == .request ? sendRequest() : sendOffer()
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Send — Request
    // ─────────────────────────────────────────────────────────

    private func sendRequest() {
        guard canSend else { return }
        isSending = true

        let onAppContactUserIds = contactVM.onAppContacts
            .filter { selectedOnAppIds.contains($0.phoneNumber) }
            .compactMap { $0.userId }
        let allOnAppIds    = Array(selectedFriendIds) + onAppContactUserIds
        let offAppContacts = contactVM.offAppContacts.filter { selectedOffAppHashes.contains($0.phoneHash) }
        let offAppNamesMap = Dictionary(uniqueKeysWithValues: offAppContacts.map { ($0.phoneHash, $0.fullName) })

        let payload: [String: Any] = [
            "type":                 "request",
            "onAppRecipientIds":    allOnAppIds,
            "offAppPhoneHashes":    offAppContacts.map { $0.phoneHash },
            "offAppRecipientNames": offAppNamesMap,
            "price":                priceDouble,
            "description":          description.trimmingCharacters(in: .whitespaces)
        ]

        Task {
            do {
                let result = try await functions.httpsCallable("sendTransaction").call(payload)
                guard let data    = result.data as? [String: Any],
                      let success = data["success"] as? Bool, success else {
                    throw NSError(domain: "SocialStar", code: -1)
                }
                await MainActor.run {
                    Analytics.shared.trackRequest(action: "sent", properties: [
                        AnalyticsProperty.amount:         priceDouble,
                        AnalyticsProperty.recipientCount: allOnAppIds.count + offAppContacts.count
                    ])
                    isSending = false
                    if !offAppContacts.isEmpty {
                        let priceStr  = String(format: "%.2f", priceDouble)
                        offAppNumbers = offAppContacts.map { $0.phoneNumber }
                        offAppMessage = "Hey \"\(description.trimmingCharacters(in: .whitespaces))\" on SocialStar and your reward will be $\(priceStr)! — join.socialstarapp.com"
                        Analytics.shared.track(event: AnalyticsEvent.inviteComposerOpened,
                                               properties: [AnalyticsProperty.recipientCount: offAppContacts.count])
                        showingComposer = true
                    } else {
                        onDismiss()
                    }
                }
            } catch {
                await MainActor.run { isSending = false; errorMessage = error.localizedDescription }
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Send — Offer (uploads video first, then sends)
    // ─────────────────────────────────────────────────────────

    private func sendOffer() {
        guard canSend, let videoURL = capturedVideoURL else { return }
        isSending = true
        offerSendState = .uploading

        Task {
            do {
                let downloadURL = try await VideoUploadManager.shared.upload(
                    videoURL:   videoURL,
                    folderPath: "offers/\(currentUserId)",
                    onProgress: { p in
                        Task { @MainActor in offerUploadProgress = p }
                    }
                )

                await MainActor.run { offerSendState = .finalizing }

                let onAppContactUserIds = contactVM.onAppContacts
                    .filter { selectedOnAppIds.contains($0.phoneNumber) }
                    .compactMap { $0.userId }
                let allOnAppIds    = Array(selectedFriendIds) + onAppContactUserIds
                let offAppContacts = contactVM.offAppContacts.filter { selectedOffAppHashes.contains($0.phoneHash) }
                let offAppNamesMap = Dictionary(uniqueKeysWithValues: offAppContacts.map { ($0.phoneHash, $0.fullName) })

                let payload: [String: Any] = [
                    "type":                 "offer",
                    "onAppRecipientIds":    allOnAppIds,
                    "offAppPhoneHashes":    offAppContacts.map { $0.phoneHash },
                    "offAppRecipientNames": offAppNamesMap,
                    "price":                priceDouble,
                    "photoUrl":             downloadURL
                ]

                let result = try await functions.httpsCallable("sendTransaction").call(payload)
                guard let data    = result.data as? [String: Any],
                      let success = data["success"] as? Bool, success else {
                    throw NSError(domain: "SocialStar", code: -1)
                }

                try? FileManager.default.removeItem(at: videoURL)

                await MainActor.run {
                    Analytics.shared.trackOffer(action: "sent", properties: [
                        AnalyticsProperty.amount:         priceDouble,
                        AnalyticsProperty.recipientCount: allOnAppIds.count + offAppContacts.count
                    ])
                    isSending         = false
                    offerSendState = .idle

                    if !offAppContacts.isEmpty {
                        let priceStr  = String(format: "%.2f", priceDouble)
                        offAppNumbers = offAppContacts.map { $0.phoneNumber }
                        offAppMessage = "Hey I've got a video for you on SocialStar — $\(priceStr) to unlock! join.socialstarapp.com"
                        showingComposer = true
                    } else {
                        onDismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isSending         = false
                    offerSendState = .idle
                    errorMessage      = error.localizedDescription
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────────────────────────

    private func sectionLabel(_ title: String) -> some View {
        Text(title).font(.system(size: 12, weight: .bold)).foregroundColor(AppTheme.secondaryText)
            .textCase(.uppercase).padding(.leading, 4)
    }

    private func toggle(_ set: inout Set<String>, id: String) {
        if set.contains(id) { set.remove(id) } else { set.insert(id); UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    private func friendRow(name: String, subtitle: String, imageUrl: String?, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ProfilePictureView(url: imageUrl, size: 44)
                    .overlay(Circle().stroke(isSelected ? AppTheme.accent : Color.clear, lineWidth: 2.5))
                VStack(alignment: .leading, spacing: 3) {
                    Text(name).font(.system(size: 15, weight: .bold)).foregroundColor(AppTheme.primaryText)
                    Text(subtitle).font(.system(size: 12)).foregroundColor(AppTheme.secondaryText).lineLimit(1)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.secondaryText.opacity(0.4))
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(isSelected ? AppTheme.accent.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - OfferRecordCameraView
//
// Thin wrapper around the same recording infra used for request
// fulfillment (RequestRealCameraView / RequestSimulatorPickerView),
// but it hands back a local file URL instead of uploading —
// upload happens later, after Friends + Reward are picked, as
// part of sendOffer().
// ─────────────────────────────────────────────────────────────

struct OfferRecordCameraView: View {
    let onRecorded: (URL) -> Void
    let onCancel:   () -> Void

    var body: some View {
        #if targetEnvironment(simulator)
        OfferSimulatorPickerView(onRecorded: onRecorded, onCancel: onCancel)
        #else
        OfferRealCameraView(onRecorded: onRecorded, onCancel: onCancel)
        #endif
    }
}

private struct OfferSimulatorPickerView: View {
    let onRecorded: (URL) -> Void
    let onCancel:   () -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark").font(.system(size: 28)).foregroundColor(.white).padding(5)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 65)

                Spacer()
                Image(systemName: "video.fill").font(.system(size: 48)).foregroundColor(.white.opacity(0.4))
                Text("Simulator — pick a video").font(.system(size: 14, weight: .bold)).foregroundColor(.white.opacity(0.6))
                Spacer()

                if isLoading {
                    ProgressView().progressViewStyle(.circular).tint(.white)
                } else {
                    PhotosPicker(selection: $selectedItem, matching: .videos) {
                        Text("Choose Video")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(AppTheme.accent).cornerRadius(200)
                            .padding(.horizontal, 32)
                    }
                }
            }
            .padding(.bottom, 60)
        }
        .ignoresSafeArea()
        .onChange(of: selectedItem) { item in
            guard let item else { return }
            isLoading = true
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let url = VideoRecordingViewModel.newTempURL()
                    try? data.write(to: url)
                    await MainActor.run { isLoading = false; onRecorded(url) }
                } else {
                    await MainActor.run { isLoading = false }
                }
            }
        }
    }
}

private struct OfferRealCameraView: View {
    let onRecorded: (URL) -> Void
    let onCancel:   () -> Void

    @StateObject private var vm               = VideoRecordingViewModel()
    @State private var isViewAppeared         = false
    @State private var showingPermissionAlert = false
    @State private var previewURL: URL? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isViewAppeared {
                VideoInitView()
                    .environmentObject(vm)
                    .ignoresSafeArea()
            }

            if let url = previewURL {
                OfferVideoPreviewConfirmView(
                    url: url,
                    onUse: {
                        vm.stopSession {
                            onRecorded(url)
                        }
                    },
                    onRetake: {
                        try? FileManager.default.removeItem(at: url)
                        previewURL = nil
                    }
                )
            } else {
                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    bottomBar
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { checkPermissions() }
        .onDisappear {
            vm.stopSession()
        }
        .onChange(of: vm.showPreview) { showing in
            guard showing, let url = vm.recordedVideoURL else { return }
            vm.showPreview = false
            previewURL = url
        }
        .alert("Camera Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                vm.stopSession {
                    onCancel()
                }
            }
            Button("Cancel", role: .cancel) {
                vm.stopSession {
                    onCancel()
                }
            }
        } message: {
            Text("Camera and microphone access are required to record videos.")
        }
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            Button {
                if vm.isRecording { vm.stopRecording() }
                vm.stopSession {
                    onCancel()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
            }

            Spacer()

            VStack(spacing: 4) {
                Button { if !vm.isRecording { vm.toggleCamera() } } label: {
                    Image(systemName: "arrow.2.circlepath")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(vm.isRecording ? .white.opacity(0.3) : .white)
                        .frame(width: 60, height: 60)
                }
                if vm.isFlashAvailable {
                    Button { vm.toggleFlashMode() } label: {
                        Image(systemName: vm.flashMode == .on ? "bolt.fill" : "bolt.slash")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(vm.flashMode == .on ? .yellow : .white)
                            .frame(width: 60, height: 60)
                    }
                }
            }
        }
        .padding(.horizontal, 12).padding(.top, 60)
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if vm.isRecording { durationLabel }
            recordButton
        }
        .padding(.bottom, 65)
    }

    private var durationLabel: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.red).frame(width: 8, height: 8)
            Text(formattedDuration)
                .font(.system(size: 16, weight: .semibold).monospacedDigit())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(Color.black.opacity(0.4)).cornerRadius(20)
    }

    private var formattedDuration: String {
        let t = Int(vm.recordingDuration)
        return String(format: "%02d:%02d", t / 60, t % 60)
    }

    private var recordButton: some View {
        Button {
            if vm.isRecording { vm.stopRecording() } else { vm.startRecording() }
        } label: {
            ZStack {
                Circle().stroke(Color.white, lineWidth: 7).frame(width: 90, height: 90)
                RoundedRectangle(cornerRadius: vm.isRecording ? 8 : 45)
                    .fill(Color.red)
                    .frame(width: vm.isRecording ? 36 : 72, height: vm.isRecording ? 36 : 72)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.isRecording)
            }
        }
    }

    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isViewAppeared = true
            vm.checkPermission()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { isViewAppeared = true; vm.checkPermission() }
                    else       { showingPermissionAlert = true }
                }
            }
        default:
            showingPermissionAlert = true
        }
    }
}

private struct OfferVideoPreviewConfirmView: View {
    let url: URL
    let onUse: () -> Void
    let onRetake: () -> Void

    @State private var player: AVPlayer?
    @State private var loopObserver: NSObjectProtocol?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayerFillView(player: player)
                    .ignoresSafeArea()
            }

            VStack {
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 200)
            }
            .ignoresSafeArea()

            VStack {
                Spacer()
                HStack(spacing: 20) {
                    Button(action: onRetake) {
                        Text("Retake")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(200)
                    }
                    Button(action: onUse) {
                        Text("Use Video")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.accent)
                            .cornerRadius(200)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
            }
        }
        .onAppear { setupPlayer() }
        .onDisappear { teardown() }
    }

    private func setupPlayer() {
        let p = AVPlayer(url: url)
        p.isMuted = false
        player = p
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: p.currentItem, queue: .main
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
// MARK: - OfferVideoThumbnail
// Simple muted, looping inline preview for the captured offer
// video while still on the compose screen (pre-upload).
// ─────────────────────────────────────────────────────────────

struct OfferVideoThumbnail: View {
    let url: URL
    @Binding var isActive: Bool

    var body: some View {
        InlineVideoPlayer(url: url, isActive: $isActive, isLoading: .constant(false))
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - FlowLayout
// ─────────────────────────────────────────────────────────────

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var height: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > width, lineWidth > 0 {
                height += lineHeight + spacing
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        height += lineHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - OffAppInviteComposer
// ─────────────────────────────────────────────────────────────

struct OffAppInviteComposer: UIViewControllerRepresentable {

    let recipients: [String]
    let body:       String
    let onFinish:   (MessageComposeResult) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = recipients
        vc.body       = body
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let parent: OffAppInviteComposer
        init(_ parent: OffAppInviteComposer) { self.parent = parent }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true) { self.parent.onFinish(result) }
        }
    }
}

private func emptyStateBox(icon: String, title: String, subtitle: String, buttonTitle: String, action: @escaping () -> Void) -> some View {
    VStack(spacing: 14) {
        ZStack {
            Circle()
                .fill(AppTheme.accent.opacity(0.12))
                .frame(width: 56, height: 56)
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(AppTheme.accent)
        }

        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.primaryText)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }

        Button(action: action) {
            Text(buttonTitle)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(AppTheme.accent)
                .cornerRadius(200)
        }
        .buttonStyle(.plain)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 28)
    .frame(maxWidth: .infinity)
    .background(AppTheme.cardBackground)
    .cornerRadius(16)
}
