import SwiftUI
import FirebaseAuth
import FirebaseFunctions
import UserNotifications
import MessageUI

// MARK: - CreateStreamView
struct CreateStreamView: View {

    let onDismiss:       () -> Void
    let onStreamCreated: (String, String?, String?) -> Void

    @StateObject var viewModel = CreateStreamViewModel()

    // iMessage composer state
    @State private var showingComposer:  Bool     = false
    @State private var pendingStreamId:  String?  = nil
    @State private var pendingToken:     String?  = nil
    @State private var pendingUrl:       String?  = nil

    // Add Friends sheet
    @State private var showingAddFriends = false
    @StateObject private var addFriendsModel = AddFriendsModel()

    init(onDismiss: @escaping () -> Void, onStreamCreated: @escaping (String, String?, String?) -> Void) {
        self.onDismiss       = onDismiss
        self.onStreamCreated = onStreamCreated
    }

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                inviteStep
            }
            VStack { Spacer(); bottomButton }
        }
        .navigationBarHidden(true)
        .onAppear {
            Analytics.shared.trackScreen(name: "create_stream")
            viewModel.refreshFriends()
        }
        .fullScreenCover(isPresented: $showingAddFriends, onDismiss: {
            viewModel.refreshFriends()
        }) {
            AddFriendsView(
                viewModel: ContactViewModel(),
                addFriendsModel: addFriendsModel,
                onFriendAdded: { friendId, _ in
                    viewModel.refreshFriends()
                }
            )
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
            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.iconColor)
            }
            Spacer()
            Text("Go Live")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.primaryText)
            Spacer()
            Color.clear.frame(width: 24, height: 24)
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }

    // MARK: - Invite step

    private var inviteStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                HStack {
                    Text("Who can watch?")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(AppTheme.primaryText)
                    Spacer()
                    if !viewModel.filteredFriends.isEmpty {
                        Button {
                            Analytics.shared.trackTap(elementId: "add_friends_button", screenName: "create_stream")
                            showingAddFriends = true
                        } label: {
                            Text("Add Friends")
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(AppTheme.accent)
                                .cornerRadius(200)
                        }
                    }
                }
                .padding(.top)

                if viewModel.isLoadingFriends {
                    HStack {
                        Spacer()
                        ProgressView().tint(AppTheme.primaryText)
                        Spacer()
                    }
                    .padding(.vertical, 40)

                } else if viewModel.filteredFriends.isEmpty {
                    noFriendsEmptyState

                } else {
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

            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Empty state

    private var noFriendsEmptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(AppTheme.accent.opacity(0.12)).frame(width: 64, height: 64)
                Image(systemName: "person.2.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
            }
            VStack(spacing: 8) {
                Text("No friends yet")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
                Text("Add friends so you can invite them to your stream")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            Button {
                Analytics.shared.trackTap(elementId: "add_friends_empty_state", screenName: "create_stream")
                showingAddFriends = true
            } label: {
                Text("Add Friends")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(AppTheme.accent)
                    .cornerRadius(200)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Friend row

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

    // MARK: - Bottom button

    private var bottomButton: some View {
        Button {
            Analytics.shared.trackTap(
                elementId: "create_stream_submit",
                screenName: "create_stream",
                properties: [AnalyticsProperty.invitedCount: viewModel.totalSelected]
            )
            createStreamAction()
        } label: {
            HStack(spacing: 8) {
                if viewModel.isSending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.disabledText))
                        .scaleEffect(0.85)
                }
                Text(viewModel.isSending ? "Creating..." : "Go Live")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(viewModel.canCreate ? .white : AppTheme.disabledText)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(viewModel.canCreate ? AppTheme.accent : AppTheme.disabledBackground)
            .cornerRadius(200)
        }
        .disabled(!viewModel.canCreate)
        .padding(.horizontal, 20).padding(.vertical, 20)
        .background(AppTheme.pageBackground.ignoresSafeArea())
    }

    // MARK: - Create stream

    private func createStreamAction() {
        Task {
            guard let result = await viewModel.createStream() else { return }
            Analytics.shared.trackStreamStarted(
                streamId:     result.streamId,
                invitedCount: viewModel.totalSelected
            )
            onStreamCreated(result.streamId, result.token, result.url)
        }
    }
}
