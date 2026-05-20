import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    @StateObject private var chatIndicator: ChatIndicatorViewModel
    @State private var shouldMaintainScrollPosition = false
    @State private var scrollAnchorId: String?
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
                ChatNavigationHeader(title: competition.description, onBack: {
                    viewModel.cleanup()
                    dismiss()
                })

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if viewModel.hasMoreMessages {
                                Button(action: {
                                    if let firstMessage = viewModel.messages.first {
                                        scrollAnchorId = firstMessage.id
                                        shouldMaintainScrollPosition = true
                                    }
                                    viewModel.loadMoreMessages()
                                }) {
                                    HStack {
                                        if viewModel.isLoadingMore {
                                            ProgressView().scaleEffect(0.8).tint(AppTheme.primaryText)
                                            Text("Loading...")
                                        } else {
                                            Image(systemName: "arrow.up.circle").font(.system(size: 16))
                                            Text("Load More")
                                        }
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.primaryText)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 20).fill(AppTheme.cardHighlight))
                                }
                                .disabled(viewModel.isLoadingMore)
                                .padding(.vertical, 8)
                            }

                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                                    .transition(.asymmetric(
                                        insertion: .scale.combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }

                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        if shouldMaintainScrollPosition {
                            if let anchorId = scrollAnchorId {
                                proxy.scrollTo(anchorId, anchor: .top)
                            }
                            shouldMaintainScrollPosition = false
                            scrollAnchorId = nil
                        } else if !viewModel.isLoadingMore {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                        chatIndicator.markAsRead()
                    }
                    .simultaneousGesture(DragGesture().onChanged { _ in
                        isTextFieldFocused = false
                    })
                }

                MessageInputView(
                    text: $messageText,
                    isTextFieldFocused: $isTextFieldFocused,
                    onSend: sendMessage
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppTheme.pageBackground)
            }
        }
        .navigationBarHidden(true)
        .tint(AppTheme.accent)
        .onAppear {
            chatIndicator.markAsRead()
            Analytics.shared.trackScreen(name: "chat_view")
        }
        .onDisappear { viewModel.cleanup() }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        viewModel.sendMessage(messageText)
        messageText = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if let userId = Auth.auth().currentUser?.uid {
            Firestore.firestore().collection("users").document(userId).getDocument { userDoc, _ in
                let username = userDoc?.data()?["name"] as? String ?? "Someone"
                NotificationQueueManager.shared.queueGroupNotification(
                    competitionId: competition.id,
                    title: competition.description,
                    body: "\(username) sent a message",
                    senderId: userId,
                    excludeUsers: [userId]
                )
                NotificationQueueManager.shared.processQueuedNotifications()
            }
        }

        Analytics.shared.trackTap(elementId: "message_send_btn_tapped", screenName: "chat_view")
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Navigation Header
// ─────────────────────────────────────────────────────────────

struct ChatNavigationHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 27, height: 27)
                    .foregroundColor(AppTheme.iconColor)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
                    .padding(.horizontal, 10)
                    .truncationMode(.tail)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppTheme.pageBackground)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Message Bubble
// ─────────────────────────────────────────────────────────────

struct MessageBubble: View {
    let message: ChatMessage
    @State private var showTimestamp = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isCurrentUser {
                Spacer()
            } else {
                ProfilePictureView(url: message.senderProfilePicture, size: 28)
            }

            VStack(alignment: message.isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !message.isCurrentUser {
                    Text(message.senderName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.secondaryText)
                }

                Text(message.text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(message.isCurrentUser ? .white : AppTheme.primaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isCurrentUser ? AppTheme.accent : AppTheme.cardHighlight)
                    )

                if showTimestamp {
                    Text(formatTimestamp(message.timestamp))
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.secondaryText)
                        .transition(.opacity)
                }
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTimestamp.toggle()
                }
            }

            if !message.isCurrentUser {
                Spacer()
            }
        }
        .padding(.horizontal, message.isCurrentUser ? 0 : 8)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Message Input
// ─────────────────────────────────────────────────────────────

struct MessageInputView: View {
    @Binding var text: String
    @FocusState.Binding var isTextFieldFocused: Bool
    let onSend: () -> Void

    var body: some View {
        TextField("Type a message...", text: $text)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(AppTheme.primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 200).fill(AppTheme.cardHighlight))
            .focused($isTextFieldFocused)
            .submitLabel(.send)
            .onSubmit { onSend() }
    }
}
