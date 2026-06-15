import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import PhotosUI
import MessageUI
import Contacts

// ─────────────────────────────────────────────────────────────
// MARK: - NewTransactionView
// 3-step wizard: Type → Details → Friends
// ─────────────────────────────────────────────────────────────

struct NewTransactionView: View {

    let onDismiss: () -> Void

    @State private var step:                 Int             = 1
    @State private var selectedType:         TransactionType = .request
    @State private var description:          String          = ""
    @State private var price:                String          = ""
    @State private var offerImage:           UIImage?        = nil
    @State private var selectedItem:         PhotosPickerItem? = nil
    @State private var selectedFriendIds:    Set<String>     = []
    @State private var selectedOnAppIds:     Set<String>     = []
    @State private var selectedOffAppHashes: Set<String>     = []
    @State private var isSending:            Bool            = false
    @State private var errorMessage:         String?         = nil
    @State private var showingComposer:      Bool            = false
    @State private var offAppNumbers:        [String]        = []
    @State private var offAppMessage:        String          = ""

    @StateObject private var contactVM = ContactViewModel()

    private let presetPrices = ["0.50", "1.00", "2.00", "5.00", "10.00"]
    private let functions    = Functions.functions()
    private let currentUserId = Auth.auth().currentUser?.uid ?? ""

    private var totalSelected: Int {
        selectedFriendIds.count + selectedOnAppIds.count + selectedOffAppHashes.count
    }

    private var priceDouble: Double { Double(price) ?? 0 }
    private var priceValid: Bool { priceDouble >= 0.50 && priceDouble <= 20.00 }

    private var step2Valid: Bool {
        priceValid &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty &&
        (selectedType == .request || offerImage != nil)
    }

    private var canSend: Bool {
        step2Valid && totalSelected > 0 && !isSending
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
                    if step == 1 { typeStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                    if step == 2 { detailsStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                    if step == 3 { friendsStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                }
                .animation(.easeInOut(duration: 0.25), value: step)
            }

            VStack { Spacer(); bottomButton }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "new_transaction_flow")
            contactVM.fetchFriendsFromFirestore()
        }
        .sheet(isPresented: $showingComposer) {
            if !offAppNumbers.isEmpty {
                OffAppInviteComposer(
                    recipients: offAppNumbers,
                    body: offAppMessage,
                    onFinish: { _ in
                        showingComposer = false
                        onDismiss()
                    }
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
        case 1:  return "New"
        case 2:  return selectedType == .request ? "Your Request" : "Your Offer"
        case 3:  return "Who?"
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
    // MARK: - Step 1: Type
    // ─────────────────────────────────────────────────────────

    private var typeStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What do you want to do?")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(AppTheme.primaryText)
                    Text("Choose how you want to interact with your friends")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.secondaryText)
                }

                typeCard(
                    type:     .request,
                    icon:     "📸",
                    title:    "Request Photo",
                    subtitle: "Ask a friend to send you a photo. You set the price and they decide if it's worth it."
                )

                typeCard(
                    type:     .offer,
                    icon:     "🎁",
                    title:    "Share Photo",
                    subtitle: "Create a mystery photo and send it to friends. They pay to unlock and see what's inside."
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
                Text(icon)
                    .font(.system(size: 32))
                    .frame(width: 56, height: 56)
                    .background(AppTheme.cardBackground)
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
            .padding(16)
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
    // MARK: - Step 2: Details (price + description + deadline)
    // ─────────────────────────────────────────────────────────

    private var detailsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Offer photo picker
                if selectedType == .offer {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("Your mystery photo")

                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            ZStack {
                                if let offerImage {
                                    Image(uiImage: offerImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 200)
                                        .clipped()
                                        .cornerRadius(16)
                                } else {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(AppTheme.cardBackground)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 200)
                                        .overlay(
                                            VStack(spacing: 10) {
                                                Image(systemName: "camera.fill")
                                                    .font(.system(size: 28))
                                                    .foregroundColor(AppTheme.secondaryText)
                                                Text("Tap to add your photo")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(AppTheme.secondaryText)
                                            }
                                        )
                                }
                            }
                        }
                        .onChange(of: selectedItem) { newItem in
                            guard let newItem else { return }
                            Task {
                                if let data  = try? await newItem.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    await MainActor.run { offerImage = image }
                                }
                            }
                        }
                    }
                }

                // Description / teaser
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel(selectedType == .request ? "What do you want?" : "Description")

                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text(selectedType == .request
                                 ? "e.g. Send me a photo of what you're having for dinner 🍕"
                                 : "e.g. You'll never guess where I am right now 👀")
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.secondaryText.opacity(0.5))
                                .padding(14)
                        }
                        TextEditor(text: $description)
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.primaryText)
                            .frame(minHeight: 90)
                            .padding(10)
                            .scrollContentBackground(.hidden)
                    }
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.divider, lineWidth: 1))

                    HStack {
                        Spacer()
                        Text("\(description.count)/120")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
                .onChange(of: description) { if $0.count > 120 { description = String($0.prefix(120)) } }

                // Price
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("Set a price")

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                        ForEach(presetPrices, id: \.self) { preset in
                            Button {
                                price = preset
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text("$\(preset)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(price == preset ? .white : AppTheme.primaryText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(price == preset ? AppTheme.accent : AppTheme.cardBackground)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        Text("$")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.primaryText)
                            .padding(.leading, 16)
                        TextField("Custom amount", text: $price)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.primaryText)
                            .keyboardType(.decimalPad)
                            .padding(.vertical, 14)
                    }
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                        !price.isEmpty && !priceValid ? Color.red.opacity(0.5) : AppTheme.divider,
                        lineWidth: 1
                    ))

                    if !price.isEmpty && !priceValid {
                        Text("Price must be between $0.50 and $20.00")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }

                    // Fee breakdown — only show when price is valid
                    if priceValid {
                        FeeBreakdownView(price: priceDouble, type: selectedType)
                    }
                }

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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pick your friends")
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(AppTheme.primaryText)
                        Text(selectedType == .request
                             ? "Who do you want photos from?"
                             : "Who do you want to send this to?")
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    Spacer()
                    if totalSelected > 0 {
                        Text("\(totalSelected) selected")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                    }
                }

                // Price summary
                if priceValid && totalSelected > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.accent)
                        Text(selectedType == .request
                             ? "$\(String(format: "%.2f", priceDouble * Double(totalSelected))) will be held in escrow for \(totalSelected) friend\(totalSelected == 1 ? "" : "s")"
                             : "$\(String(format: "%.2f", priceDouble)) per friend who unlocks")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    .padding(12)
                    .background(AppTheme.accent.opacity(0.06))
                    .cornerRadius(10)
                }

                // Friends
                if !contactVM.friends.isEmpty {
                    sectionLabel("Friends")
                    VStack(spacing: 0) {
                        ForEach(contactVM.friends) { friend in
                            friendRow(
                                name:       friend.name,
                                subtitle:   "@\(friend.username)",
                                imageUrl:   friend.profilePictureUrl,
                                isSelected: selectedFriendIds.contains(friend.id)
                            ) { toggle(&selectedFriendIds, id: friend.id) }
                            if friend.id != contactVM.friends.last?.id {
                                Divider().background(AppTheme.divider)
                            }
                        }
                    }
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
                }

                contactsSection
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
                HStack { Spacer(); ProgressView().tint(AppTheme.primaryText); Spacer() }
                    .padding(.vertical, 24)
            } else {
                if !contactVM.onAppContacts.isEmpty {
                    sectionLabel("On SocialStar")
                    VStack(spacing: 0) {
                        ForEach(contactVM.onAppContacts) { contact in
                            friendRow(
                                name:       contact.fullName,
                                subtitle:   "@\(contact.username)",
                                imageUrl:   contact.profileImageUrl,
                                isSelected: selectedOnAppIds.contains(contact.phoneNumber)
                            ) { toggle(&selectedOnAppIds, id: contact.phoneNumber) }
                            if contact.id != contactVM.onAppContacts.last?.id {
                                Divider().background(AppTheme.divider)
                            }
                        }
                    }
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
                }

                if !contactVM.offAppContacts.isEmpty {
                    sectionLabel("Invite to SocialStar")
                    VStack(spacing: 0) {
                        ForEach(contactVM.offAppContacts) { contact in
                            friendRow(
                                name:       contact.fullName,
                                subtitle:   "Not on the app yet",
                                imageUrl:   nil,
                                isSelected: selectedOffAppHashes.contains(contact.phoneHash)
                            ) { toggle(&selectedOffAppHashes, id: contact.phoneHash) }
                            if contact.phoneHash != contactVM.offAppContacts.last?.phoneHash {
                                Divider().background(AppTheme.divider)
                            }
                        }
                    }
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
                }
            }
        } else if status == .denied || status == .restricted {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Enable Contacts in Settings")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        } else {
            Button { contactVM.requestContactAccess() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                    Text("Find Friends from Contacts")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.accent)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Bottom button
    // ─────────────────────────────────────────────────────────

    private var bottomButton: some View {
        Button(action: bottomAction) {
            HStack(spacing: 8) {
                if isSending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.85)
                }
                Text(bottomTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(bottomEnabled ? AppTheme.accent : AppTheme.disabledBackground)
            .cornerRadius(200)
        }
        .disabled(!bottomEnabled)
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(AppTheme.pageBackground.ignoresSafeArea())
    }

    private var bottomTitle: String {
        if isSending { return "Sending..." }
        switch step {
        case 1:  return "Continue"
        case 2:  return "Continue"
        case 3:  return selectedType == .request ? "Send Request" : "Send Offer"
        default: return "Continue"
        }
    }

    private var bottomEnabled: Bool {
        if isSending { return false }
        switch step {
        case 1:  return true
        case 2:  return step2Valid
        case 3:  return canSend
        default: return false
        }
    }

    private func bottomAction() {
        switch step {
        case 1:
            Analytics.shared.trackTap(
                elementId: "new_transaction_type_selected",
                screenName: "new_transaction_flow",
                properties: [AnalyticsProperty.transactionType: selectedType.rawValue]
            )
            withAnimation { step = 2 }
        case 2:
            withAnimation { step = 3 }
        case 3:
            sendTransaction()
        default:
            break
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Send
    // ─────────────────────────────────────────────────────────

    private func sendTransaction() {
        guard canSend else { return }
        isSending = true

        let onAppContactUserIds = contactVM.onAppContacts
            .filter { selectedOnAppIds.contains($0.phoneNumber) }
            .compactMap { $0.userId }

        let allOnAppIds    = Array(selectedFriendIds) + onAppContactUserIds
        let offAppContacts = contactVM.offAppContacts.filter {
            selectedOffAppHashes.contains($0.phoneHash)
        }

        if selectedType == .offer, let image = offerImage {
            Task {
                do {
                    let photoUrl = try await UploadManager.shared.upload(
                        image: image,
                        folderPath: "offers/\(currentUserId)",
                        onProgress: { _ in }
                    )
                    await sendToBackend(onAppIds: allOnAppIds, offAppContacts: offAppContacts, photoUrl: photoUrl)
                } catch {
                    await MainActor.run {
                        isSending    = false
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } else {
            Task {
                await sendToBackend(onAppIds: allOnAppIds, offAppContacts: offAppContacts, photoUrl: nil)
            }
        }
    }

    private func sendToBackend(onAppIds: [String], offAppContacts: [Contact], photoUrl: String?) async {
        var payload: [String: Any] = [
            "type":              selectedType.rawValue,
            "onAppRecipientIds": onAppIds,
            "offAppPhoneHashes": offAppContacts.map { $0.phoneHash },
            "price":             priceDouble,
            "description":       description.trimmingCharacters(in: .whitespaces),
            "deadlineSeconds":   NSNull()
        ]
        if let photoUrl { payload["photoUrl"] = photoUrl }

        do {
            let result = try await functions.httpsCallable("sendTransaction").call(payload)
            guard let data    = result.data as? [String: Any],
                  let success = data["success"] as? Bool, success else {
                throw NSError(domain: "SocialStar", code: -1)
            }

            await MainActor.run {
                if selectedType == .request {
                    Analytics.shared.trackRequest(
                        action: "sent",
                        properties: [
                            AnalyticsProperty.amount: priceDouble,
                            AnalyticsProperty.recipientCount: onAppIds.count + offAppContacts.count
                        ]
                    )
                } else {
                    Analytics.shared.trackOffer(
                        action: "sent",
                        properties: [
                            AnalyticsProperty.amount: priceDouble,
                            AnalyticsProperty.recipientCount: onAppIds.count + offAppContacts.count
                        ]
                    )
                }

                isSending = false

                if !offAppContacts.isEmpty {
                    let priceStr   = String(format: "%.2f", priceDouble)
                    offAppNumbers  = offAppContacts.map { $0.phoneNumber }
                    offAppMessage  = selectedType == .request
                        ? "I'll pay you $\(priceStr) for a photo on SocialStar 👀 join.socialstarapp.com"
                        : "I've got something for you on SocialStar 🎁 $\(priceStr) to unlock → join.socialstarapp.com"
                    showingComposer = true
                } else {
                    onDismiss()
                }
            }
        } catch {
            await MainActor.run {
                isSending    = false
                errorMessage = error.localizedDescription
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────────────────────────

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(AppTheme.secondaryText)
            .textCase(.uppercase)
            .padding(.leading, 4)
    }

    private func toggle(_ set: inout Set<String>, id: String) {
        if set.contains(id) { set.remove(id) } else {
            set.insert(id)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func friendRow(
        name: String,
        subtitle: String,
        imageUrl: String?,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ProfilePictureView(url: imageUrl, size: 44)
                    .overlay(Circle().stroke(isSelected ? AppTheme.accent : Color.clear, lineWidth: 2.5))

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.secondaryText.opacity(0.4))
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
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
        let vc        = MFMessageComposeViewController()
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

// ─────────────────────────────────────────────────────────────
// MARK: - FeeBreakdownView
// Reusable — used in NewTransactionView and TransactionDetailView
// ─────────────────────────────────────────────────────────────

struct FeeBreakdownView: View {

    let price: Double
    let type:  TransactionType

    private var platformFee:   Double { (price * 0.20 * 100).rounded() / 100 }
    private var youPocket:     Double { price - platformFee }
    private var priceLabel:    String { type == .request ? "Request price" : "Offer price" }

    var body: some View {
        VStack(spacing: 0) {
            feeRow(label: priceLabel,      value: "$\(String(format: "%.2f", price))",       valueColor: AppTheme.primaryText, bold: false)
            Divider().background(AppTheme.divider)
            feeRow(label: "Platform fee (20%)",  value: "-$\(String(format: "%.2f", platformFee))", valueColor: AppTheme.secondaryText, bold: false)
            Divider().background(AppTheme.divider)
            feeRow(label: "You pocket",    value: "$\(String(format: "%.2f", youPocket))",    valueColor: AppTheme.green, bold: true)
        }
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.divider, lineWidth: 1))
    }

    private func feeRow(label: String, value: String, valueColor: Color, bold: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: bold ? .bold : .regular))
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
