import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Kingfisher

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    @StateObject private var chatIndicator: ChatIndicatorViewModel
    @State private var shouldMaintainScrollPosition = false
    @State private var scrollAnchorId: String?
    @State private var isFullScreenPhotoOpen = false
    @Environment(\.dismiss) private var dismiss
    let competition: Competition

    init(competition: Competition) {
        self.competition = competition
        self._viewModel = StateObject(wrappedValue: ChatViewModel(competitionId: competition.id))
        self._chatIndicator = StateObject(wrappedValue: ChatIndicatorViewModel(competitionId: competition.id))
    }

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                ChatNavigationHeader(title: competition.description, onBack: { viewModel.cleanup(); dismiss() })
                ZStack(alignment: .bottomTrailing) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if viewModel.hasMoreMessages {
                                    Button(action: {
                                        if let firstMessage = viewModel.messages.first { scrollAnchorId = firstMessage.id; shouldMaintainScrollPosition = true }
                                        viewModel.loadMoreMessages()
                                    }) {
                                        HStack {
                                            if viewModel.isLoadingMore { ProgressView().scaleEffect(0.8).tint(AppTheme.primaryText); Text("Loading...") }
                                            else { Image(systemName: "arrow.up.circle").font(.system(size: 16)); Text("Load More") }
                                        }
                                        .font(.system(size: 14, weight: .medium)).foregroundColor(AppTheme.primaryText)
                                        .padding(.horizontal, 16).padding(.vertical, 8)
                                        .background(RoundedRectangle(cornerRadius: 20).fill(AppTheme.cardHighlight))
                                    }
                                    .disabled(viewModel.isLoadingMore).padding(.vertical, 8)
                                }
                                ForEach(viewModel.messages) { message in
                                    MessageBubble(message: message, chatViewModel: viewModel, isFullScreenPhotoOpen: $isFullScreenPhotoOpen)
                                        .id(message.id).transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                                }
                                Color.clear.frame(height: 1).id("bottom")
                            }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                        }
                        .onChange(of: viewModel.messages.count) { _ in
                            guard !isFullScreenPhotoOpen else { return }
                            if shouldMaintainScrollPosition {
                                if let anchorId = scrollAnchorId { proxy.scrollTo(anchorId, anchor: .top) }
                                shouldMaintainScrollPosition = false; scrollAnchorId = nil
                            } else if !viewModel.isLoadingMore {
                                withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("bottom", anchor: .bottom) }
                            }
                            chatIndicator.markAsRead()
                        }
                        .simultaneousGesture(DragGesture().onChanged { _ in isTextFieldFocused = false })
                    }
                }
                MessageInputView(text: $messageText, isTextFieldFocused: $isTextFieldFocused, onSend: sendMessage)
                    .padding(.horizontal, 16).padding(.vertical, 8).background(AppTheme.pageBackground)
            }
        }
        .navigationBarHidden(true).tint(AppTheme.accent)
        .onAppear { chatIndicator.markAsRead(); Analytics.shared.trackScreen(name: "chat_view") }
        .onDisappear { viewModel.cleanup() }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
    }

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        viewModel.sendMessage(messageText); messageText = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let userId = Auth.auth().currentUser?.uid {
            FirebaseFirestore.Firestore.firestore().collection("users").document(userId).getDocument { userDoc, _ in
                let username = userDoc?.data()?["name"] as? String ?? "Someone"
                NotificationQueueManager.shared.queueGroupNotification(competitionId: competition.id, title: competition.description,
                    body: "\(username) sent a message", senderId: userId, excludeUsers: [userId])
                NotificationQueueManager.shared.processQueuedNotifications()
            }
        }
        Analytics.shared.trackTap(elementId: "message_send_btn_tapped", screenName: "chat_view")
    }
}

struct ChatNavigationHeader: View {
    let title: String; let onBack: () -> Void
    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "arrow.left").resizable().aspectRatio(contentMode: .fit).frame(width: 24, height: 24).foregroundColor(AppTheme.iconColor)
                Text(title).font(.system(size: 16, weight: .bold)).foregroundColor(AppTheme.primaryText).padding(.horizontal, 10).truncationMode(.tail).lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 20).padding(.vertical, 16).background(AppTheme.cardBackground)
    }
}

struct MessageBubble: View {
    let message: ChatMessage; let chatViewModel: ChatViewModel; @Binding var isFullScreenPhotoOpen: Bool
    @State private var showTimestamp = false; @State private var showFullScreenPhoto = false
    @State private var photo: UserPhoto?; @State private var photoOwner: (name: String, profilePicture: String?)?
    @State private var isLoadingPhoto = false; @State private var photoLoadError = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isCurrentUser { Spacer() }
            else { ProfilePictureView(url: message.senderProfilePicture, size: 28) }
            VStack(alignment: message.isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !message.isCurrentUser {
                    Text(message.senderName).font(.system(size: 13, weight: .medium)).foregroundColor(AppTheme.secondaryText)
                }
                VStack(alignment: message.isCurrentUser ? .trailing : .leading, spacing: 8) {
                    if message.isPhotoMessage {
                        PhotoMessageView(photo: photo, isLoading: isLoadingPhoto, hasError: photoLoadError, onTap: { showFullScreenPhoto = true })
                    }
                    if !message.text.isEmpty {
                        HStack(alignment: .bottom, spacing: 4) {
                            Text(message.text)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(message.isCurrentUser ? .white : AppTheme.primaryText)
//                            if message.isCurrentUser { messageStatusIcon.font(.system(size: 12)).foregroundColor(.white) }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 18).fill(message.isCurrentUser ? AppTheme.accent : AppTheme.cardHighlight))
                    }
                }
                if showTimestamp {
                    Text(formatTimestamp(message.timestamp)).font(.system(size: 11)).foregroundColor(AppTheme.secondaryText).transition(.opacity)
                }
            }
            .onTapGesture { if !message.isPhotoMessage { withAnimation(.easeInOut(duration: 0.2)) { showTimestamp.toggle() } } }
            if !message.isCurrentUser { Spacer() }
        }
        .padding(.horizontal, message.isCurrentUser ? 0 : 8)
        .onAppear { if message.isPhotoMessage && photo == nil && !isLoadingPhoto { fetchPhotoData() } }
        .fullScreenCover(isPresented: $showFullScreenPhoto) {
            if let photo = photo, let owner = photoOwner {
                let displayName = (photo.userId == Auth.auth().currentUser?.uid) ? "Me" : owner.name
                FullScreenPhotoView(photo: photo, userName: displayName, competitionId: message.photoCompetitionId, userProfilePictureUrl: owner.profilePicture)
            }
        }
        .onChange(of: showFullScreenPhoto) { isOpen in isFullScreenPhotoOpen = isOpen }
    }

    private var messageStatusIcon: some View {
        Group {
            switch message.messageStatus {
            case .sending: Image(systemName: "clock")
            case .sent: Image(systemName: "checkmark.circle")
            case .failed: Image(systemName: "exclamationmark.circle")
            }
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter(); formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func fetchPhotoData() {
        guard let photoId = message.photoId, let competitionId = message.photoCompetitionId else { return }
        isLoadingPhoto = true; photoLoadError = false
        chatViewModel.fetchPhotoData(for: photoId, competitionId: competitionId) { fetchedPhoto, owner in
            DispatchQueue.main.async {
                self.isLoadingPhoto = false
                if let fetchedPhoto = fetchedPhoto, let owner = owner { self.photo = fetchedPhoto; self.photoOwner = owner }
                else { self.photoLoadError = true }
            }
        }
    }
}

struct PhotoMessageView: View {
    let photo: UserPhoto?; let isLoading: Bool; let hasError: Bool; let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let photo = photo {
                    KFImage(URL(string: photo.photoUrl))
                        .placeholder { ZStack { RoundedRectangle(cornerRadius: 12).fill(AppTheme.cardHighlight).frame(width: 200, height: 200); ProgressView().tint(AppTheme.primaryText) } }
                        .fade(duration: 0.25).cacheMemoryOnly().resizable().aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 200).clipped().cornerRadius(12)
                } else if isLoading {
                    ZStack { RoundedRectangle(cornerRadius: 12).fill(AppTheme.cardHighlight).frame(width: 200, height: 200); ProgressView().tint(AppTheme.primaryText) }
                } else if hasError {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(AppTheme.cardHighlight).frame(width: 200, height: 200)
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle").font(.system(size: 24)).foregroundColor(AppTheme.secondaryText)
                            Text("Failed to load").font(.system(size: 12)).foregroundColor(AppTheme.secondaryText)
                        }
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(AppTheme.cardHighlight).frame(width: 200, height: 200)
                        Image(systemName: "photo").font(.system(size: 40)).foregroundColor(AppTheme.secondaryText)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle()).disabled(photo == nil)
    }
}

struct MessageInputView: View {
    @Binding var text: String; @FocusState.Binding var isTextFieldFocused: Bool; let onSend: () -> Void

    var body: some View {
        TextField("Type a message...", text: $text)
            .font(.system(size: 15, weight: .medium)).foregroundColor(AppTheme.primaryText)
            .padding(.horizontal, 16).padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 200).fill(AppTheme.cardHighlight))
            .focused($isTextFieldFocused).submitLabel(.send).onSubmit { onSend() }
    }
}
