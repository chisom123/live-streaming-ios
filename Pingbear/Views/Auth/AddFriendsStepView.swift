import SwiftUI
import MessageUI
import UserNotifications

struct AddFriendsStepView: View {

    @ObservedObject var contactViewModel: ContactViewModel
    @ObservedObject var addFriendsModel:  AddFriendsModel

    @State private var showUsernameSheet                          = false
    @State private var addedAnyFriend                              = false
    @State private var showNotificationPrompt                      = false
    @State private var notificationPermissionUndetermined: Bool?   = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {

                ZStack {
                    Text("Add friends")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)

                    HStack {
                        Button(action: {
                            Analytics.shared.trackTap(elementId: "add_friends_step_username_icon", screenName: "add_friends_step")
                            showUsernameSheet = true
                        }) {
                            Image(systemName: "at")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 22, height: 22)
                                .foregroundColor(AppTheme.iconColor)
                        }

                        Spacer()

                        Button(action: {
                            Analytics.shared.trackTap(
                                elementId: addedAnyFriend ? "add_friends_step_continue" : "add_friends_step_skip",
                                screenName: "add_friends_step"
                            )
                            finish()
                        }) {
                            Text(addedAnyFriend ? "Continue" : "Skip")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(addedAnyFriend ? AppTheme.accent : AppTheme.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        if contactViewModel.permissionDenied {
                            usernameFallback

                        } else if contactViewModel.isLoading {
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
                            if !contactViewModel.onAppContacts.isEmpty || !contactViewModel.offAppContacts.isEmpty {
                                searchBar
                            }

                            if !contactViewModel.filteredOnApp.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("On SocialStar")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(AppTheme.secondaryText)
                                        .padding(.horizontal)
                                    contactList(contacts: contactViewModel.filteredOnApp, isOnApp: true)
                                }
                            }

                            if !contactViewModel.filteredOffApp.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Invite to SocialStar")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(AppTheme.secondaryText)
                                        .padding(.horizontal)
                                    contactList(contacts: contactViewModel.filteredOffApp, isOnApp: false)
                                }
                            }

                            if !contactViewModel.searchText.isEmpty
                                && contactViewModel.filteredOnApp.isEmpty
                                && contactViewModel.filteredOffApp.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 32)).foregroundColor(AppTheme.secondaryText)
                                    Text("No contacts match \"\(contactViewModel.searchText)\"")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AppTheme.secondaryText)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 40)
                            } else if contactViewModel.searchText.isEmpty
                                && contactViewModel.onAppContacts.isEmpty
                                && contactViewModel.offAppContacts.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "person.2.slash")
                                        .font(.system(size: 32)).foregroundColor(AppTheme.secondaryText)
                                    Text("No contacts found")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AppTheme.secondaryText)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 40)
                            }
                        }
                    }
                    .padding(.bottom, contactViewModel.selectedToInvite.isEmpty ? 40 : 110)
                }
            }

            if !contactViewModel.selectedToInvite.isEmpty {
                inviteBar
            }

            // ── Notification permission modal ────────────────────────
            // Same priming pattern as AddFriendsView: after the user
            // successfully sends an invite, ask them to enable
            // notifications so notifyFriendJoined can actually reach
            // this device once their invitee signs up.
            if showNotificationPrompt {
                notificationPromptModal
            }
        }
        .background(AppTheme.pageBackground)
        .navigationBarHidden(true)
        .onAppear {
            Analytics.shared.trackScreen(name: "add_friends_step")
            // This is the first point in the flow where contacts access is
            // actually requested — the user just tapped "Add friends" on
            // the explainer screen, so the system dialog now follows an
            // explicit action instead of firing on page-load.
            if contactViewModel.onAppContacts.isEmpty
                && contactViewModel.offAppContacts.isEmpty
                && !contactViewModel.permissionDenied {
                contactViewModel.requestContactAccess()
            }
            checkNotificationPermission()
        }
        .sheet(isPresented: $showUsernameSheet, onDismiss: {
            Analytics.shared.track(event: "add_by_username_sheet_dismissed", properties: ["screen": "add_friends_step"])
        }) {
            AddByUsernameSheet(addFriendsModel: addFriendsModel, onFriendAdded: { _, _ in
                addedAnyFriend = true
            })
        }
    }

    // MARK: - Username fallback (contacts denied)

    private var usernameFallback: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(AppTheme.accent.opacity(0.15)).frame(width: 60, height: 60)
                Image(systemName: "at").font(.system(size: 24, weight: .bold)).foregroundColor(AppTheme.accent)
            }
            VStack(spacing: 6) {
                Text("Search by username instead")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
                Text("We couldn't access your contacts, but you can still find friends by username.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            Button(action: {
                Analytics.shared.trackTap(elementId: "add_friends_step_username_cta", screenName: "add_friends_step")
                showUsernameSheet = true
            }) {
                Text("Search by username")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent)
                    .cornerRadius(200)
            }
            .padding(.horizontal, 20)

            Button(action: {
                Analytics.shared.trackTap(elementId: "add_friends_step_enable_contacts", screenName: "add_friends_step")
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "lock").font(.system(size: 12))
                    Text("Or enable contacts in Settings")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal)
    }

    // MARK: - Search bar (contacts granted)

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.secondaryText)
                .padding(.leading, 12)
            TextField("Search contacts", text: $contactViewModel.searchText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.primaryText)
                .tint(AppTheme.accent)
                .padding(.vertical, 10)
                .onChange(of: contactViewModel.searchText) { newValue in
                    if !newValue.isEmpty {
                        Analytics.shared.track(
                            event: "contacts_searched",
                            properties: ["screen": "add_friends_step", "query_length": newValue.count]
                        )
                    }
                }
            if !contactViewModel.searchText.isEmpty {
                Button(action: {
                    Analytics.shared.trackTap(elementId: "add_friends_step_clear_search", screenName: "add_friends_step")
                    contactViewModel.searchText = ""
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

    // MARK: - Contact list

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
                                Button(action: { addOnAppFriend(contact) }) {
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
                            let selected = contactViewModel.selectedToInvite.contains(contact.phoneHash)
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
                            let isSelecting = !contactViewModel.selectedToInvite.contains(contact.phoneHash)
                            Analytics.shared.track(
                                event: isSelecting ? "invite_contact_selected" : "invite_contact_deselected",
                                properties: ["screen": "add_friends_step", "contact_name": contact.fullName]
                            )
                            contactViewModel.toggleInviteSelection(for: contact)
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

    // MARK: - Invite bar

    private var selectedContacts: [Contact] {
        contactViewModel.offAppContacts.filter { contactViewModel.selectedToInvite.contains($0.phoneHash) }
    }

    private var inviteBar: some View {
        HStack(spacing: 12) {
            Text("\(contactViewModel.selectedToInvite.count) selected")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppTheme.primaryText)
            Spacer()
            Button(action: {
                Analytics.shared.trackTap(elementId: "add_friends_step_send_invites", screenName: "add_friends_step")
                sendInvites()
            }) {
                Text("Send invite\(contactViewModel.selectedToInvite.count == 1 ? "" : "s")")
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
        .ignoresSafeArea(edges: .bottom)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: contactViewModel.selectedToInvite.isEmpty)
    }

    // MARK: - Notification prompt modal

    private var notificationPromptModal: some View {
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
                                    properties: ["screen": "add_friends_step_invite"]
                                )
                            } else {
                                Analytics.shared.track(
                                    event: AnalyticsEvent.notificationPermissionDenied,
                                    properties: ["screen": "add_friends_step_invite"]
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

    // MARK: - Notification permission

    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationPermissionUndetermined = (settings.authorizationStatus == .notDetermined)
            }
        }
    }

    // MARK: - Actions

    private func addOnAppFriend(_ contact: Contact) {
        Analytics.shared.track(
            event: "add_friend_tapped",
            properties: ["method": "onboarding_contacts_list", "username": contact.username]
        )
        addFriendsModel.addFriend(byUsername: contact.username) { success, _ in
            DispatchQueue.main.async {
                guard success else {
                    Analytics.shared.track(
                        event: "friend_add_failed",
                        properties: ["method": "onboarding_contacts_list", "username": contact.username]
                    )
                    return
                }
                Analytics.shared.track(
                    event: "friend_added",
                    properties: ["method": "onboarding_contacts_list", "username": contact.username]
                )
                if let idx = contactViewModel.onAppContacts.firstIndex(where: { $0.phoneHash == contact.phoneHash }) {
                    contactViewModel.onAppContacts[idx].isAdded = true
                }
                addedAnyFriend = true
            }
        }
    }

    private func sendInvites() {
        guard MFMessageComposeViewController.canSendText() else {
            Analytics.shared.track(event: "imessage_unavailable", properties: ["screen": "add_friends_step"])
            return
        }
        let numbers = selectedContacts.map { $0.phoneNumber }
        guard !numbers.isEmpty else { return }

        Analytics.shared.track(
            event: "invite_composer_opened",
            properties: ["screen": "add_friends_step", "recipient_count": numbers.count]
        )

        let composer = MFMessageComposeViewController()
        composer.recipients = numbers
        composer.body = "Hey add me on SocialStar! join.socialstarapp.com"
        composer.messageComposeDelegate = InviteComposerDelegate.shared

        InviteComposerDelegate.shared.onFinish = { result in
            switch result {
            case .sent:
                Analytics.shared.track(
                    event: "invites_sent",
                    properties: ["screen": "add_friends_step", "count": numbers.count]
                )
                // Off-app invites are a bet on a future signup, not a friend
                // yet — this does not set addedAnyFriend. It still clears
                // selection so the bar dismisses, and primes notifications
                // so this device can hear about it when the invite resolves.
                contactViewModel.writePendingInvites {
                    DispatchQueue.main.async {
                        contactViewModel.selectedToInvite.removeAll()
                        if self.notificationPermissionUndetermined == true {
                            self.showNotificationPrompt = true
                        }
                    }
                }
            case .cancelled:
                Analytics.shared.track(
                    event: "invite_composer_cancelled",
                    properties: ["screen": "add_friends_step", "recipient_count": numbers.count]
                )
            case .failed:
                Analytics.shared.track(
                    event: "invite_composer_failed",
                    properties: ["screen": "add_friends_step", "recipient_count": numbers.count]
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

    private func finish() {
        OnboardingCompletion.finish(hasFriend: addedAnyFriend)
    }
}
