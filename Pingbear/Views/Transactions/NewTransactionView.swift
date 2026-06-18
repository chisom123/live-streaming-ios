import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import MessageUI
import Contacts

// ─────────────────────────────────────────────────────────────
// MARK: - NewTransactionView
// 3-step wizard: Description → Friends → Price
// ─────────────────────────────────────────────────────────────

struct NewTransactionView: View {

    let onDismiss: () -> Void

    @State private var step:                 Int         = 1
    @State private var description:          String      = ""
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

    @StateObject private var contactVM = ContactViewModel()

    private let presetPrices  = ["0.50", "1.00", "2.00", "5.00", "10.00"]
    private let functions     = Functions.functions()
    private let currentUserId = Auth.auth().currentUser?.uid ?? ""
    private let db            = Firestore.firestore()

    private var totalSelected: Int {
        selectedFriendIds.count + selectedOnAppIds.count + selectedOffAppHashes.count
    }

    private var priceDouble:  Double { Double(price) ?? 0 }
    private var priceValid:   Bool   { priceDouble >= 0.50 && priceDouble <= 20.00 }
    private var totalEscrow:  Double { priceDouble * Double(totalSelected) }
    private var hasSufficientBalance: Bool { walletBalance >= totalEscrow }

    private var step1Valid: Bool { !description.trimmingCharacters(in: .whitespaces).isEmpty }
    private var step2Valid: Bool { totalSelected > 0 }
    private var step3Valid: Bool { priceValid && hasSufficientBalance }
    private var canSend:    Bool { step3Valid && !isSending }

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
                    if step == 1 { descriptionStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                    if step == 2 { friendsStep    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                    if step == 3 { priceStep      .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                }
                .animation(.easeInOut(duration: 0.25), value: step)
            }
            VStack { Spacer(); bottomButton }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "new_request_step_1")
            contactVM.fetchFriendsFromFirestore()
            startBalanceListener()
        }
        .onDisappear { stopBalanceListener() }
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
        switch step {
        case 1: return "Your Request"
        case 2: return "Pick Friends"
        case 3: return "Set a Price"
        default: return ""
        }
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(1...3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= step ? AppTheme.accent : AppTheme.divider)
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.25), value: step)
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Step 1: Description
    // ─────────────────────────────────────────────────────────

    private var descriptionStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What's your video request?")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(AppTheme.primaryText)
                }

                TextField("e.g. Crack an egg on your head", text: $description, axis: .vertical)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
                    .lineLimit(5...10)
                    .padding(14)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .tint(AppTheme.accent)
                    .onChange(of: description) { if $0.count > 120 { description = String($0.prefix(120)) } }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Step 2: Friends
    // ─────────────────────────────────────────────────────────

    private var friendsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Pick your friends")
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
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            } label: {
                Text("Enable Contacts in Settings")
                    .font(.system(size: 15, weight: .bold)).foregroundColor(AppTheme.accent)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(AppTheme.cardBackground).cornerRadius(12)
            }
            .buttonStyle(.plain)
        } else {
            Button { contactVM.requestContactAccess() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                    Text("Find Friends from Contacts").font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(AppTheme.accent).cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Step 3: Price
    // ─────────────────────────────────────────────────────────

    private var priceStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Set a price")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(AppTheme.primaryText)
                    Text("This is what you'll pay per friend. The total is held until they respond.")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.secondaryText)
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
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Text("$").font(.system(size: 18, weight: .bold)).foregroundColor(AppTheme.primaryText).padding(.leading, 16)
                    TextField("Custom amount", text: $price)
                        .font(.system(size: 18, weight: .bold)).foregroundColor(AppTheme.primaryText)
                        .keyboardType(.decimalPad).padding(.vertical, 14)
                }
                .background(AppTheme.cardBackground).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                    !price.isEmpty && !priceValid ? Color.red.opacity(0.5) : AppTheme.divider, lineWidth: 1))

                if !price.isEmpty && !priceValid {
                    Text("Price must be between $0.50 and $20.00").font(.system(size: 12)).foregroundColor(.red)
                }

                if priceValid { requestBreakdownView }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }

    private var requestBreakdownView: some View {
        VStack(spacing: 0) {
            ForEach(Array(selectedRecipients.enumerated()), id: \.offset) { _, recipient in
                HStack {
                    HStack(spacing: 6) {
                        Text(recipient.name).font(.system(size: 13)).foregroundColor(AppTheme.primaryText)
                        if recipient.isOffApp {
                            Text("invite").font(.system(size: 10, weight: .bold)).foregroundColor(AppTheme.accent)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(AppTheme.accent.opacity(0.1)).cornerRadius(4)
                        }
                    }
                    Spacer()
                    Text("$\(String(format: "%.2f", priceDouble))").font(.system(size: 13)).foregroundColor(AppTheme.secondaryText)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                Divider().background(AppTheme.divider)
            }

            HStack {
                Text("Total").font(.system(size: 13, weight: .bold)).foregroundColor(AppTheme.primaryText)
                Spacer()
                Text("$\(String(format: "%.2f", totalEscrow))").font(.system(size: 13, weight: .bold)).foregroundColor(AppTheme.primaryText)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)

            Divider().background(AppTheme.divider)

            HStack {
                Image(systemName: "wallet.pass.fill").font(.system(size: 13))
                    .foregroundColor(hasSufficientBalance ? AppTheme.green : .red)
                Text("Your balance").font(.system(size: 13)).foregroundColor(AppTheme.secondaryText)
                Spacer()
                Text("$\(String(format: "%.2f", walletBalance))").font(.system(size: 13, weight: .bold))
                    .foregroundColor(hasSufficientBalance ? AppTheme.green : .red)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)

            if !hasSufficientBalance {
                Divider().background(AppTheme.divider)
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 13)).foregroundColor(.red)
                        Text("You need $\(String(format: "%.2f", max(0, totalEscrow - walletBalance))) more")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.red)
                        Spacer()
                    }
                    Button {
                        Analytics.shared.trackTap(elementId: "top_up_from_new_request", screenName: "new_request_step_3")
                        Analytics.shared.track(event: AnalyticsEvent.walletTopUpOpened,
                                               properties: ["screen": "new_request_step_3"])
                        showWalletSheet = true
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
            }
        }
        .background(AppTheme.cardBackground).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            hasSufficientBalance ? AppTheme.divider : Color.red.opacity(0.3), lineWidth: 1))
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Bottom button
    // ─────────────────────────────────────────────────────────

    private var bottomButton: some View {
        Button(action: bottomAction) {
            HStack(spacing: 8) {
                if isSending { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.85) }
                Text(isSending ? "Sending..." : step < 3 ? "Continue" : "Send Request")
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

    private var bottomEnabled: Bool {
        if isSending { return false }
        switch step {
        case 1: return step1Valid
        case 2: return step2Valid
        case 3: return canSend
        default: return false
        }
    }

    private func bottomAction() {
        switch step {
        case 1:
            withAnimation { step = 2 }
            Analytics.shared.trackScreen(name: "new_request_step_2")
        case 2:
            withAnimation { step = 3 }
            Analytics.shared.trackScreen(name: "new_request_step_3")
        case 3:
            sendRequest()
        default:
            break
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Send
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
                        offAppMessage = "I'll pay you $\(priceStr) for a video on SocialStar! \"\(description.trimmingCharacters(in: .whitespaces))\" join.socialstarapp.com"
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
