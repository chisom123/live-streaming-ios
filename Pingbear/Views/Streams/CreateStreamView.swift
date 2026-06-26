import SwiftUI
import FirebaseAuth
import FirebaseFunctions
import Contacts
import UserNotifications
import MessageUI

// MARK: - CreateStreamView
struct CreateStreamView: View {

    let onDismiss:       () -> Void
    let onStreamCreated: (String, String?, String?) -> Void

    @StateObject var viewModel = CreateStreamViewModel()
    @State private var step = 1

    // iMessage composer state
    @State private var showingComposer  = false
    @State private var offAppNumbers:   [String] = []
    @State private var pendingStreamId: String?  = nil
    @State private var pendingToken:    String?  = nil
    @State private var pendingUrl:      String?  = nil

    init(onDismiss: @escaping () -> Void, onStreamCreated: @escaping (String, String?, String?) -> Void) {
        self.onDismiss       = onDismiss
        self.onStreamCreated = onStreamCreated
    }

    private enum FlowStep { case invite, notifications }
    private var activeSteps: [FlowStep] {
        var steps: [FlowStep] = [.invite]
        if viewModel.notificationPermissionUndetermined == true { steps.append(.notifications) }
        return steps
    }
    private var currentStep: FlowStep { activeSteps[min(step, activeSteps.count) - 1] }
    private var totalSteps: Int { activeSteps.count }

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                progressBar.padding(.horizontal, 20).padding(.bottom, 16)
                ZStack {
                    if currentStep == .invite        { inviteStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                    if currentStep == .notifications { notificationsStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                }
                .animation(.easeInOut(duration: 0.25), value: step)
            }
            VStack { Spacer(); bottomButton }
        }
        .navigationBarHidden(true)
        .onAppear {
            Analytics.shared.trackScreen(name: "create_stream")
            viewModel.contactVM.fetchFriendsFromFirestore()
            viewModel.checkNotificationPermission()
            let status = CNContactStore.authorizationStatus(for: .contacts)
            if status == .authorized {
                viewModel.contactVM.requestContactAccess()
            }
        }
        .sheet(isPresented: $showingComposer) {
            if !offAppNumbers.isEmpty {
                OffAppInviteComposer(
                    recipients: offAppNumbers,
                    body: "I'm live on SocialStar right now — Come send me requests! join.socialstarapp.com",
                    onFinish: { _ in
                        showingComposer = false
                        if let id = pendingStreamId {
                            onStreamCreated(id, pendingToken, pendingUrl)
                        }
                    }
                )
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
    }

    // MARK: - Header
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
        .padding(.horizontal, 20).padding(.vertical, 16)
    }

    private var headerTitle: String {
        switch currentStep {
        case .invite:        return "Start Stream"
        case .notifications: return "Notifications"
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

    // MARK: - Step 1: Invite
    private var inviteStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Who can watch?")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(AppTheme.primaryText)
                    Spacer()
                    if viewModel.totalSelected > 0 {
                        Text("\(viewModel.totalSelected) invited")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                    }
                }

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.secondaryText).padding(.leading, 12)
                    TextField("Search friends and contacts", text: $viewModel.friendsSearchText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.primaryText)
                        .tint(AppTheme.accent)
                        .padding(.vertical, 10)
                    if !viewModel.friendsSearchText.isEmpty {
                        Button { viewModel.friendsSearchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(AppTheme.secondaryText)
                        }
                        .padding(.trailing, 12)
                    }
                }
                .background(AppTheme.cardBackground)
                .cornerRadius(10)

                if viewModel.hasNoSearchResults {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.system(size: 32)).foregroundColor(AppTheme.secondaryText)
                        Text("No results for \"\(viewModel.friendsSearchText)\"")
                            .font(.system(size: 15, weight: .semibold)).foregroundColor(AppTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
                } else {
                    if !viewModel.filteredFriends.isEmpty {
                        sectionLabel("Friends")
                        VStack(spacing: 0) {
                            ForEach(viewModel.filteredFriends) { friend in
                                let isSelected = viewModel.selectedFriendIds.contains(friend.id)
                                Button {
                                    viewModel.toggleFriend(friend.id)
                                } label: {
                                    friendRow(
                                        name: friend.name,
                                        subtitle: "@\(friend.username)",
                                        imageUrl: friend.profilePictureUrl,
                                        isSelected: isSelected
                                    )
                                }
                                .buttonStyle(.plain)
                                if friend.id != viewModel.filteredFriends.last?.id {
                                    Divider().background(AppTheme.divider)
                                }
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
            if status == .authorized {
                viewModel.contactVM.requestContactAccess()
            }
        }
    }

    @ViewBuilder
    private var contactsSection: some View {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .authorized {
            if viewModel.contactVM.isLoading {
                HStack {
                    Spacer()
                    ProgressView().tint(AppTheme.primaryText)
                    Spacer()
                }
                .padding(.vertical, 24)
            } else {
                if !viewModel.filteredOnAppContacts.isEmpty {
                    sectionLabel("On SocialStar")
                    VStack(spacing: 0) {
                        ForEach(viewModel.filteredOnAppContacts) { contact in
                            let isSelected = viewModel.selectedOnAppIds.contains(contact.phoneNumber)
                            Button {
                                viewModel.toggleOnApp(contact.phoneNumber)
                            } label: {
                                friendRow(
                                    name: contact.fullName,
                                    subtitle: "@\(contact.username)",
                                    imageUrl: contact.profileImageUrl,
                                    isSelected: isSelected
                                )
                            }
                            .buttonStyle(.plain)
                            if contact.id != viewModel.filteredOnAppContacts.last?.id {
                                Divider().background(AppTheme.divider)
                            }
                        }
                    }
                    .background(AppTheme.cardBackground).cornerRadius(12)
                }

                if !viewModel.filteredOffAppContacts.isEmpty {
                    sectionLabel("Invite to SocialStar")
                    VStack(spacing: 0) {
                        ForEach(viewModel.filteredOffAppContacts) { contact in
                            let isSelected = viewModel.selectedOffAppHashes.contains(contact.phoneHash)
                            Button {
                                viewModel.toggleOffApp(contact.phoneHash)
                            } label: {
                                friendRow(
                                    name: contact.fullName,
                                    subtitle: "Not on the app yet",
                                    imageUrl: nil,
                                    isSelected: isSelected
                                )
                            }
                            .buttonStyle(.plain)
                            if contact.phoneHash != viewModel.filteredOffAppContacts.last?.phoneHash {
                                Divider().background(AppTheme.divider)
                            }
                        }
                    }
                    .background(AppTheme.cardBackground).cornerRadius(12)
                }

                if viewModel.filteredOnAppContacts.isEmpty && viewModel.filteredOffAppContacts.isEmpty && viewModel.friendsSearchText.isEmpty {
                    VStack(spacing: 12) {
                        Text("No contacts found")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.secondaryText)
                        Text("Add friends to see them here")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.secondaryText.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            }
        } else if status == .denied || status == .restricted {
            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(AppTheme.accent.opacity(0.12)).frame(width: 56, height: 56)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 22, weight: .semibold)).foregroundColor(AppTheme.accent)
                }
                VStack(spacing: 10) {
                    Text("Contacts Access Needed")
                        .font(.system(size: 16, weight: .bold)).foregroundColor(AppTheme.primaryText)
                    Text("Enable contacts access in Settings to find friends who are already on SocialStar.")
                        .font(.system(size: 13, weight: .medium)).foregroundColor(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Enable in Settings")
                        .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(AppTheme.accent).cornerRadius(200)
                }
            }
            .padding(24)
            .background(AppTheme.cardBackground).cornerRadius(16)
        } else {
            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(AppTheme.accent.opacity(0.12)).frame(width: 56, height: 56)
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 22, weight: .semibold)).foregroundColor(AppTheme.accent)
                }
                VStack(spacing: 10) {
                    Text("Find Friends from Contacts")
                        .font(.system(size: 16, weight: .bold)).foregroundColor(AppTheme.primaryText)
                    Text("We'll match your contacts with people already on SocialStar — your contacts stay private.")
                        .font(.system(size: 13, weight: .medium)).foregroundColor(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                Button {
                    viewModel.contactVM.requestContactAccess()
                } label: {
                    Text("Allow Access")
                        .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(AppTheme.accent).cornerRadius(200)
                }
            }
            .padding(24)
            .background(AppTheme.cardBackground).cornerRadius(16)
        }
    }

    private func friendRow(name: String, subtitle: String, imageUrl: String?, isSelected: Bool) -> some View {
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

    // MARK: - Notifications Step
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
                    Text("Get notified when friends join")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                        .multilineTextAlignment(.center)
                    Text("We'll let you know when your invited friends join the stream.")
                        .font(.system(size: 15))
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

    // MARK: - Bottom button
    private var bottomButton: some View {
        Button(action: bottomAction) {
            HStack(spacing: 8) {
                if viewModel.isSending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.disabledText))
                        .scaleEffect(0.85)
                }
                Text(bottomLabel)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(bottomEnabled ? .white : AppTheme.disabledText)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(bottomEnabled ? AppTheme.accent : AppTheme.disabledBackground)
            .cornerRadius(200)
        }
        .disabled(!bottomEnabled)
        .padding(.horizontal, 20).padding(.vertical, 20)
        .background(AppTheme.pageBackground.ignoresSafeArea())
    }

    private var bottomLabel: String {
        if viewModel.isSending { return "Creating..." }
        switch currentStep {
        case .notifications: return "Continue"
        case .invite:        return "Go Live"
        }
    }

    private var bottomEnabled: Bool {
        if viewModel.isSending { return false }
        switch currentStep {
        case .invite:        return viewModel.canCreate
        case .notifications: return true
        }
    }

    private func advance() {
        withAnimation { step += 1 }
    }

    private func requestNotificationsAndAdvance() {
        Analytics.shared.trackTap(elementId: "allow_notifications", screenName: "create_stream_notifications")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted { UIApplication.shared.registerForRemoteNotifications() }
                advance()
            }
        }
    }

    private func bottomAction() {
        switch currentStep {
        case .invite:
            Analytics.shared.trackTap(
                elementId: "create_stream_submit",
                screenName: "create_stream",
                properties: [AnalyticsProperty.invitedCount: viewModel.totalSelected]
            )
            if viewModel.notificationPermissionUndetermined == true {
                advance()
            } else {
                createStreamAction()
            }
        case .notifications:
            requestNotificationsAndAdvance()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                createStreamAction()
            }
        }
    }

    private func createStreamAction() {
        Task {
            guard let result = await viewModel.createStream() else { return }

            Analytics.shared.trackStreamStarted(
                streamId:     result.streamId,
                invitedCount: viewModel.totalSelected
            )

            let offAppContacts = viewModel.contactVM.offAppContacts
                .filter { viewModel.selectedOffAppHashes.contains($0.phoneHash) }

            if !offAppContacts.isEmpty && MFMessageComposeViewController.canSendText() {
                // Stash stream details, open iMessage composer
                // onStreamCreated fires after composer is dismissed
                pendingStreamId = result.streamId
                pendingToken    = result.token
                pendingUrl      = result.url
                offAppNumbers   = offAppContacts.map { $0.phoneNumber }
                showingComposer = true
            } else {
                onStreamCreated(result.streamId, result.token, result.url)
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title).font(.system(size: 12, weight: .bold)).foregroundColor(AppTheme.secondaryText)
            .textCase(.uppercase).padding(.leading, 4)
    }
}
