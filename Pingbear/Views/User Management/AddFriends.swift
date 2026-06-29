import SwiftUI
import FirebaseFirestore
import MessageUI
import UserNotifications

struct AddFriendsView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel          = ContactViewModel()
    @ObservedObject var addFriendsModel: AddFriendsModel
    @State private var messageStatus: MessageStatus? = nil
    @State private var username: String              = ""
    @State private var showUsernameSearch            = false
    @State private var showNotificationPrompt        = false
    @State private var notificationPermissionUndetermined: Bool? = nil

    var onFriendAdded: ((String, String) -> Void)? = nil

    enum MessageStatus { case error, success, none }

    func processUsername(_ username: String) -> String {
        username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var selectedContacts: [Contact] {
        viewModel.offAppContacts.filter { viewModel.selectedToInvite.contains($0.phoneHash) }
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            VStack(spacing: 0) {

                // ── Nav bar ──────────────────────────────────────────
                HStack {
                    Button(action: {
                        Analytics.shared.trackTap(elementId: "back_button", screenName: "add_friends")
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(AppTheme.iconColor)
                    }
                    Spacer()
                    Text("Add Friends")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                    Spacer()
                    Button(action: {
                        Analytics.shared.trackTap(elementId: "add_by_username_icon", screenName: "add_friends")
                        showUsernameSearch = true
                    }) {
                        Image(systemName: "person.badge.plus")
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(AppTheme.iconColor)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 20)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // ── Permission denied ────────────────────────
                        if viewModel.permissionDenied {
                            VStack(spacing: 16) {
                                Image(systemName: "person.crop.circle.badge.xmark")
                                    .font(.system(size: 44))
                                    .foregroundColor(AppTheme.secondaryText)
                                VStack(spacing: 6) {
                                    Text("Contacts access needed")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AppTheme.primaryText)
                                    Text("Allow access so we can find your friends on SocialStar")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppTheme.secondaryText)
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(3)
                                }
                                Button(action: {
                                    Analytics.shared.trackTap(elementId: "enable_contacts_button", screenName: "add_friends")
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Text("Enable Contacts")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(AppTheme.accent)
                                        .cornerRadius(200)
                                }
                                .padding(.horizontal, 40)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                            .padding(.horizontal)

                        // ── Loading state ────────────────────────────
                        } else if viewModel.isLoading {
                            HStack {
                                Spacer()
                                VStack(spacing: 10) {
                                    ProgressView().tint(AppTheme.secondaryText)
                                    Text("Finding your contacts...")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.secondaryText)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 40)

                        } else {

                            // ── Contact search bar ───────────────────
                            if !viewModel.onAppContacts.isEmpty || !viewModel.offAppContacts.isEmpty {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(AppTheme.secondaryText)
                                        .padding(.leading, 12)
                                    TextField("Search contacts", text: $viewModel.searchText)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AppTheme.primaryText)
                                        .tint(AppTheme.accent)
                                        .padding(.vertical, 10)
                                        .onChange(of: viewModel.searchText) { newValue in
                                            if !newValue.isEmpty {
                                                Analytics.shared.track(
                                                    event: "contacts_searched",
                                                    properties: ["query_length": newValue.count]
                                                )
                                            }
                                        }
                                    if !viewModel.searchText.isEmpty {
                                        Button(action: {
                                            Analytics.shared.trackTap(elementId: "clear_search", screenName: "add_friends")
                                            viewModel.searchText = ""
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(AppTheme.secondaryText)
                                        }
                                        .padding(.trailing, 12)
                                    }
                                }
                                .background(AppTheme.cardBackground)
                                .cornerRadius(10)
                                .padding(.horizontal)
                            }

                            // ── On the app ───────────────────────────
                            if !viewModel.filteredOnApp.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("On SocialStar")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(AppTheme.secondaryText)
                                        .padding(.horizontal)
                                    contactList(contacts: viewModel.filteredOnApp, isOnApp: true)
                                }
                            }

                            // ── Not on the app ───────────────────────
                            if !viewModel.filteredOffApp.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Invite to SocialStar")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(AppTheme.secondaryText)
                                        .padding(.horizontal)
                                    contactList(contacts: viewModel.filteredOffApp, isOnApp: false)
                                }
                            }

                            // ── Empty states ─────────────────────────
                            if !viewModel.searchText.isEmpty
                                && viewModel.filteredOnApp.isEmpty
                                && viewModel.filteredOffApp.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 32)).foregroundColor(AppTheme.secondaryText)
                                    Text("No contacts match \"\(viewModel.searchText)\"")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AppTheme.secondaryText)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 60)
                            } else if viewModel.searchText.isEmpty
                                && viewModel.onAppContacts.isEmpty
                                && viewModel.offAppContacts.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "person.2.slash")
                                        .font(.system(size: 36)).foregroundColor(AppTheme.secondaryText)
                                    Text("No contacts found")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AppTheme.secondaryText)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 60)
                            }
                        }
                    }
                    .padding(.bottom, viewModel.selectedToInvite.isEmpty ? 40 : 120)
                }
            }

            // ── Fixed invite bar ─────────────────────────────────────
            if !viewModel.selectedToInvite.isEmpty {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        HStack(spacing: -10) {
                            ForEach(selectedContacts.prefix(3)) { contact in
                                contactAvatar(contact: contact, size: 34)
                                    .overlay(Circle().stroke(AppTheme.cardBackground, lineWidth: 2))
                            }
                            if selectedContacts.count > 3 {
                                ZStack {
                                    Circle().fill(AppTheme.cardBackground).frame(width: 34, height: 34)
                                    Text("+\(selectedContacts.count - 3)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(AppTheme.secondaryText)
                                }
                                .overlay(Circle().stroke(AppTheme.cardBackground, lineWidth: 2))
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(viewModel.selectedToInvite.count) selected")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppTheme.primaryText)
                            Text(selectedContacts.map { $0.firstName }.joined(separator: ", "))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.secondaryText)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button(action: {
                            Analytics.shared.trackTap(elementId: "send_invites_button", screenName: "add_friends")
                            sendInvites()
                        }) {
                            Text("Send invite\(viewModel.selectedToInvite.count == 1 ? "" : "s")")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 18).padding(.vertical, 10)
                                .background(AppTheme.accent)
                                .cornerRadius(200)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppTheme.pageBackground)
                    .padding(.bottom, 0)
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.selectedToInvite.isEmpty)
            }

            // ── Notification permission modal ────────────────────────
            if showNotificationPrompt {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accent.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 36))
                                .foregroundColor(AppTheme.accent)
                        }
                        VStack(spacing: 8) {
                            Text("Get notified when your friends join")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppTheme.primaryText)
                                .multilineTextAlignment(.center)
                            Text("We'll let you know the moment one of your invited friends signs up.")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        Button {
                            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                                DispatchQueue.main.async {
                                    if granted {
                                        UIApplication.shared.registerForRemoteNotifications()
                                        Analytics.shared.track(
                                            event: AnalyticsEvent.notificationPermissionGranted,
                                            properties: ["screen": "add_friends_invite"]
                                        )
                                    } else {
                                        Analytics.shared.track(
                                            event: AnalyticsEvent.notificationPermissionDenied,
                                            properties: ["screen": "add_friends_invite"]
                                        )
                                    }
                                    showNotificationPrompt = false
                                }
                            }
                        } label: {
                            Text("OK")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(AppTheme.accent)
                                .cornerRadius(200)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(28)
                    .background(AppTheme.cardBackground)
                    .cornerRadius(20)
                    .padding(.horizontal, 40)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: showNotificationPrompt)
            }
        }
        .background(AppTheme.pageBackground)
        .onAppear {
            Analytics.shared.trackScreen(name: "add_friends")
            viewModel.requestContactAccess()
            checkNotificationPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if viewModel.permissionDenied {
                Analytics.shared.track(event: "returned_from_settings", properties: ["screen": "add_friends"])
                viewModel.requestContactAccess()
            }
        }
        .sheet(isPresented: $showUsernameSearch, onDismiss: {
            Analytics.shared.track(event: "add_by_username_sheet_dismissed", properties: ["screen": "add_friends"])
        }) {
            AddByUsernameSheet(
                addFriendsModel: addFriendsModel,
                onFriendAdded: onFriendAdded
            )
        }
    }

    // MARK: - Notification permission

    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationPermissionUndetermined = (settings.authorizationStatus == .notDetermined)
            }
        }
    }

    // MARK: - Contact list builder

    @ViewBuilder
    private func contactList(contacts: [Contact], isOnApp: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(contacts.indices, id: \.self) { i in
                let contact = contacts[i]
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        contactAvatar(contact: contact, size: 40)
                            .padding(.leading, 20)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(contact.fullName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(AppTheme.primaryText)
                                .lineLimit(1)
                            if isOnApp {
                                Text("@\(contact.username)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.secondaryText)
                                    .lineLimit(1)
                            } else {
                                Text("Not on SocialStar yet")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.secondaryText)
                            }
                        }

                        Spacer()

                        if isOnApp {
                            if !contact.isAdded {
                                Button(action: {
                                    Analytics.shared.track(
                                        event: "add_friend_tapped",
                                        properties: ["method": "contacts_list", "username": contact.username]
                                    )
                                    addFriendsModel.addFriend(byUsername: contact.username) { success, _ in
                                        if success {
                                            Analytics.shared.track(
                                                event: "friend_added",
                                                properties: ["method": "contacts_list", "username": contact.username]
                                            )
                                            DispatchQueue.main.async {
                                                if let idx = viewModel.onAppContacts.firstIndex(where: { $0.phoneHash == contact.phoneHash }) {
                                                    viewModel.onAppContacts[idx].isAdded = true
                                                }
                                            }
                                            if let onFriendAdded {
                                                Firestore.firestore().collection("users")
                                                    .whereField("username", isEqualTo: contact.username)
                                                    .getDocuments { snap, _ in
                                                        guard let doc = snap?.documents.first else { return }
                                                        onFriendAdded(doc.documentID, contact.fullName)
                                                    }
                                            }
                                        } else {
                                            Analytics.shared.track(
                                                event: "friend_add_failed",
                                                properties: ["method": "contacts_list", "username": contact.username]
                                            )
                                        }
                                    }
                                }) {
                                    Text("Add")
                                        .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                                        .padding(.horizontal, 18).padding(.vertical, 7)
                                        .background(AppTheme.accent).cornerRadius(200)
                                }
                                .padding(.trailing, 20)
                            } else {
                                HStack(spacing: 6) {
                                    Text("Added").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                                    Image(systemName: "checkmark.circle.fill")
                                        .resizable().frame(width: 16, height: 16).foregroundColor(.white)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(AppTheme.green).cornerRadius(200)
                                .padding(.trailing, 20)
                            }
                        } else {
                            let selected = viewModel.selectedToInvite.contains(contact.phoneHash)
                            ZStack {
                                Circle()
                                    .strokeBorder(selected ? AppTheme.accent : AppTheme.secondaryText.opacity(0.4), lineWidth: 2)
                                    .frame(width: 26, height: 26)
                                if selected {
                                    Circle().fill(AppTheme.accent).frame(width: 18, height: 18)
                                }
                            }
                            .padding(.trailing, 20)
                        }
                    }
                    .padding(.vertical, 18)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !isOnApp {
                            let isSelecting = !viewModel.selectedToInvite.contains(contact.phoneHash)
                            Analytics.shared.track(
                                event: isSelecting ? "invite_contact_selected" : "invite_contact_deselected",
                                properties: [
                                    "contact_name": contact.fullName,
                                    "total_selected": viewModel.selectedToInvite.count + (isSelecting ? 1 : -1)
                                ]
                            )
                            viewModel.toggleInviteSelection(for: contact)
                        }
                    }

                    if i < contacts.count - 1 {
                        Divider().background(AppTheme.divider).padding(.leading, 74)
                    }
                }
            }
        }
        .background(AppTheme.cardBackground)
        .cornerRadius(10)
        .padding(.horizontal)
    }

    // MARK: - Avatar

    @ViewBuilder
    private func contactAvatar(contact: Contact, size: CGFloat) -> some View {
        if let url = contact.profileImageUrl, !url.isEmpty {
            ProfilePictureView(url: url, size: size)
        } else if let image = contact.contactImage {
            Image(uiImage: image)
                .resizable().scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Image("user-new")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.6, height: size * 0.6)
                .frame(width: size, height: size)
                .background(Color(hex: "#F5F5F5"))
                .clipShape(Circle())
        }
    }

    // MARK: - Invite

    private var inviteMessage: String {
        "Hey add me on SocialStar! join.socialstarapp.com"
    }

    private func sendInvites() {
        guard MFMessageComposeViewController.canSendText() else {
            Analytics.shared.track(event: "imessage_unavailable", properties: ["screen": "add_friends"])
            return
        }
        let numbers = selectedContacts.map { $0.phoneNumber }
        guard !numbers.isEmpty else { return }

        Analytics.shared.track(
            event: "invite_composer_opened",
            properties: ["recipient_count": numbers.count]
        )

        let composer = MFMessageComposeViewController()
        composer.recipients = numbers
        composer.body = inviteMessage
        composer.messageComposeDelegate = InviteComposerDelegate.shared

        InviteComposerDelegate.shared.onFinish = { result in
            switch result {
            case .sent:
                Analytics.shared.track(
                    event: "invites_sent",
                    properties: ["count": numbers.count, "names": self.selectedContacts.map { $0.firstName }.joined(separator: ", ")]
                )
                viewModel.writePendingInvites {
                    DispatchQueue.main.async {
                        viewModel.selectedToInvite.removeAll()
                        if self.notificationPermissionUndetermined == true {
                            self.showNotificationPrompt = true
                        }
                    }
                }
            case .cancelled:
                Analytics.shared.track(
                    event: "invite_composer_cancelled",
                    properties: ["recipient_count": numbers.count]
                )
            case .failed:
                Analytics.shared.track(
                    event: "invite_composer_failed",
                    properties: ["recipient_count": numbers.count]
                )
            @unknown default:
                break
            }
        }

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root  = scene.windows.first?.rootViewController else { return }
        var topVC = root
        while let presented = topVC.presentedViewController { topVC = presented }
        topVC.present(composer, animated: true)
    }
}

// MARK: - Add by username sheet

struct AddByUsernameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var addFriendsModel: AddFriendsModel
    var onFriendAdded: ((String, String) -> Void)?

    @State private var username: String         = ""
    @State private var messageStatus: Status?   = nil
    @FocusState private var focused: Bool

    enum Status { case success, error }

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(AppTheme.divider)
                .frame(width: 36, height: 4)
                .padding(.top, 12).padding(.bottom, 20)

            Text("Add by username")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.primaryText)
                .padding(.bottom, 24)

            HStack(spacing: 0) {
                HStack {
                    Image(systemName: "at")
                        .foregroundColor(AppTheme.secondaryText).padding(.leading, 15)
                    TextField("Enter username", text: $username)
                        .padding(.vertical)
                        .padding(.leading, 5)
                        .foregroundColor(AppTheme.primaryText)
                        .font(.system(size: 16, weight: .bold))
                        .tint(AppTheme.accent)
                        .autocapitalization(.none)
                        .focused($focused)
                }
                .frame(height: 60)
                .background(AppTheme.cardBackground
                    .clipShape(RoundedCorner(radius: 10, corners: [.topLeft, .bottomLeft])))

                Button(action: {
                    Analytics.shared.trackTap(elementId: "add_by_username_submit", screenName: "add_by_username_sheet")
                    addByUsername()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 56, height: 60).foregroundColor(.white)
                        .background(
                            (username.isEmpty ? AppTheme.disabledBackground : AppTheme.accent)
                                .clipShape(RoundedCorner(radius: 10, corners: [.topRight, .bottomRight]))
                        )
                }
                .disabled(username.isEmpty)
            }
            .padding(.horizontal, 20)

            if let status = messageStatus {
                Text(status == .success ? "Friend added successfully" : "Couldn't find that username")
                    .foregroundColor(status == .success ? AppTheme.green : .red)
                    .font(.system(size: 15, weight: .bold))
                    .padding(.top, 16)
            }

            Spacer()
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .onAppear {
            Analytics.shared.trackScreen(name: "add_by_username_sheet")
            focused = true
        }
    }

    private func addByUsername() {
        let processed = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !processed.isEmpty else { return }

        Analytics.shared.track(event: "username_search_attempted", properties: ["username": processed])

        addFriendsModel.addFriend(byUsername: processed) { success, _ in
            messageStatus = success ? .success : .error
            if success {
                Analytics.shared.track(event: "friend_added", properties: ["method": "username", "username": processed])
                username = ""
                if let onFriendAdded {
                    Firestore.firestore().collection("users")
                        .whereField("username", isEqualTo: processed)
                        .getDocuments { snap, _ in
                            guard let doc = snap?.documents.first else { return }
                            onFriendAdded(doc.documentID, doc.data()["name"] as? String ?? processed)
                        }
                }
            } else {
                Analytics.shared.track(event: "friend_add_failed", properties: ["method": "username", "username": processed])
            }
        }
    }
}

// MARK: - Singleton delegate

class InviteComposerDelegate: NSObject, MFMessageComposeViewControllerDelegate {
    static let shared = InviteComposerDelegate()
    var onFinish: ((MessageComposeResult) -> Void)?

    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true) {
            self.onFinish?(result)
            self.onFinish = nil
        }
    }
}
