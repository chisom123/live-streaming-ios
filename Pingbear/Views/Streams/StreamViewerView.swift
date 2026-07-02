import SwiftUI
import FirebaseAuth
import FirebaseFunctions
import LiveKit

// MARK: - StreamViewerView
struct StreamViewerView: View {

    let stream:  StreamModel
    let onLeave: () -> Void

    @StateObject private var viewModel: StreamViewerViewModel
    @State private var showRequestSheet = false
    @State private var showLeaveConfirm = false
    @FocusState private var chatFocused: Bool

    init(stream: StreamModel, onLeave: @escaping () -> Void) {
        self.stream  = stream
        self.onLeave = onLeave
        _viewModel   = StateObject(wrappedValue: StreamViewerViewModel(stream: stream))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let track = viewModel.streamerTrack {
                SwiftUIVideoView(track)
                    .ignoresSafeArea()
                    .scaleEffect(x: viewModel.isFrontCamera ? -1 : 1, y: 1)
            } else {
                Rectangle()
                    .fill(Color(hex: "#0a0a0f"))
                    .ignoresSafeArea()
            }

            if viewModel.isConnecting {
                connectingOverlay
            } else if viewModel.isEnded {
                streamEndedOverlay
            } else {
                liveOverlay
            }

            if showLeaveConfirm {
                leaveConfirmDialog
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "stream_viewer")
            Task { await viewModel.join() }
        }
        .onDisappear { viewModel.leave() }
        .sheet(isPresented: $showRequestSheet) {
            SendStreamRequestSheet(
                stream: stream,
                onDismiss: { showRequestSheet = false }
            )
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Connecting
    private var connectingOverlay: some View {
        CustomSpinner()
            .frame(width: 50, height: 50)
    }

    // MARK: - Live overlay
    private var liveOverlay: some View {
        ZStack(alignment: .bottom) {
            // Bottom content first (renders behind)
            VStack(spacing: 0) {
                requestButtonRow
                chatFeed
                bottomBar
            }
            .animation(
                .spring(response: 0.35, dampingFraction: 0.85),
                value: viewModel.activeRequestDescription != nil
            )

            // Top bar last (renders on top, receives taps first)
            VStack(spacing: 0) {
                topBar
                Spacer()
            }
            .allowsHitTesting(true)
        }
    }

    // MARK: - Top bar
    private var topBar: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 8) {
                ProfilePictureView(url: stream.streamerImageUrl, size: 30)
                Text(stream.streamerName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer()

            Text("LIVE")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .kerning(0.5)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(AppTheme.danger)
                .clipShape(Capsule())

            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 12))
                Text(formattedViewerCount(viewModel.viewerCount))
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.white.opacity(0.1))
            .clipShape(Capsule())

            Button { showLeaveConfirm = true } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .padding(.leading)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .background(Color.white.opacity(0.001))
    }

    private func formattedViewerCount(_ count: Int) -> String {
        count >= 1000 ? String(format: "%.1fk", Double(count) / 1000) : "\(count)"
    }

    // MARK: - Chat feed
    private var chatFeed: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.messages) { msg in
                        ChatBubbleView(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 250)
            .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.18),
                        .init(color: .black, location: 0.85),
                        .init(color: .clear, location: 1)
                    ]),
                    startPoint: .top, endPoint: .bottom
                )
            )
            .padding(.vertical, 25)
            .onChange(of: viewModel.messages.count) { _ in
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Request button row
    // Sits above the chat feed, left-aligned, so it reads as its own
    // primary action rather than competing with the chat input.
    private var requestButtonRow: some View {
        HStack {
            Button {
                Analytics.shared.trackTap(
                    elementId: "open_request_sheet",
                    screenName: "stream_viewer",
                    properties: [AnalyticsProperty.streamId: stream.id]
                )
                showRequestSheet = true
            } label: {
                Text("Make a request")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#FF6B00"))
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    // MARK: - Bottom bar
    private var bottomBar: some View {
        HStack {
            TextField(
                "",
                text: $viewModel.chatText,
                prompt: Text("Say something...").foregroundColor(.white)
            )
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .tint(Color(hex: "#FF6B00"))
            .focused($chatFocused)
            .submitLabel(.send)
            .onSubmit { viewModel.sendChatMessage() }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
        }
        .background(.black.opacity(0.45))
        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 0.5))
        .clipShape(Capsule())
        .padding(.horizontal)
        .padding(.bottom, 10)
    }

    // MARK: - Leave confirm dialog
    private var leaveConfirmDialog: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { showLeaveConfirm = false }

            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.08))
                            .frame(width: 48, height: 48)
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Text("Leave stream?")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("You can rejoin anytime while it's live.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 10) {
                    Button { showLeaveConfirm = false } label: {
                        Text("Stay")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    Button(action: onLeave) {
                        Text("Leave")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(24)
            .background(Color(hex: "#141414"))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Stream ended
    private var streamEndedOverlay: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 72, height: 72)
                Image(systemName: "video.slash.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.45))
            }
            Text("Stream ended")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            Button(action: onLeave) {
                Text("Close")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 13)
                    .background(.white.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - ChatBubbleView
struct ChatBubbleView: View {

    let message: ChatMessage
    private let currentUserId = Auth.auth().currentUser?.uid ?? ""

    private var isMe: Bool { message.userId == currentUserId }
    private var displayName: String { isMe ? "You" : message.name }

    var body: some View {
        Group {
            switch message.type {
            case .chat:             chatRow
            case .joinEvent:        joinRow
            case .requestEvent:     requestRow
            case .requestAccepted:  requestAcceptedRow
            case .requestDeclined:  requestDeclinedRow
            case .requestCompleted: requestCompletedRow
            default:                chatRow
            }
        }
    }

    // MARK: - Multi-line helper
    private func isMultiLine(_ fullText: String) -> Bool {
        if fullText.contains("\n") { return true }

        let font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        let maxWidth: CGFloat = 310 - 36

        let size = (fullText as NSString).boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return size.height > 24
    }

    // MARK: - Chat row
    private var chatRow: some View {
        let alignment: VerticalAlignment = isMultiLine(displayName + " " + message.text) ? .top : .center

        return HStack(alignment: alignment, spacing: 8) {
            ProfilePictureView(url: message.avatarUrl, size: 28)
                .padding(.top, alignment == .top ? 1 : 0)
            Group {
                Text(displayName + " ")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                + Text(message.text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .fixedSize(horizontal: false, vertical: true)
            .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 1)
        }
        .frame(maxWidth: 310, alignment: .leading)
    }

    // MARK: - Join row
    private var joinRow: some View {
        HStack(alignment: .center, spacing: 8) {
            ProfilePictureView(url: message.avatarUrl, size: 28)
            Group {
                Text(displayName + " ")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                + Text("joined")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .fixedSize(horizontal: false, vertical: true)
            .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 1)
        }
        .frame(maxWidth: 310, alignment: .leading)
    }

    // MARK: - Request row
    private var requestRow: some View {
        let parts = message.text.components(separatedBy: " · $")
        let reqDesc = parts.first ?? message.text
        let priceLabel = parts.count > 1 ? " $\(parts[1])" : ""
        let fullText = displayName + " " + "\(priceLabel.isEmpty ? "" : "\(priceLabel) ")request " + reqDesc
        let alignment: VerticalAlignment = isMultiLine(fullText) ? .top : .center

        return HStack(alignment: alignment, spacing: 8) {
            ProfilePictureView(url: message.avatarUrl, size: 28)
                .padding(.top, alignment == .top ? 1 : 0)
            Group {
                Text(displayName + " ")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                + Text("\(priceLabel.isEmpty ? "" : "\(priceLabel) ")request ")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "#FF6B00"))
                + Text(reqDesc)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .fixedSize(horizontal: false, vertical: true)
            .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 1)
        }
        .frame(maxWidth: 310, alignment: .leading)
    }

    // MARK: - Request Accepted Row
    private var requestAcceptedRow: some View {
        let body = extractRequestText() ?? ""
        let fullText = displayName + " " + "accepted " + body
        let alignment: VerticalAlignment = isMultiLine(fullText) ? .top : .center

        return HStack(alignment: alignment, spacing: 8) {
            ProfilePictureView(url: message.avatarUrl, size: 28)
                .padding(.top, alignment == .top ? 1 : 0)
            Group {
                Text(displayName + " ")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                + Text("accepted ")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "#22C55E"))
                + Text(body)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .fixedSize(horizontal: false, vertical: true)
            .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 1)
        }
        .frame(maxWidth: 310, alignment: .leading)
    }

    // MARK: - Request Declined Row
    private var requestDeclinedRow: some View {
        let body = extractRequestText() ?? ""
        let fullText = displayName + " " + "declined " + body
        let alignment: VerticalAlignment = isMultiLine(fullText) ? .top : .center

        return HStack(alignment: alignment, spacing: 8) {
            ProfilePictureView(url: message.avatarUrl, size: 28)
                .padding(.top, alignment == .top ? 1 : 0)
            Group {
                Text(displayName + " ")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                + Text("declined ")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "#EF4444"))
                + Text(body)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .fixedSize(horizontal: false, vertical: true)
            .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 1)
        }
        .frame(maxWidth: 310, alignment: .leading)
    }

    // MARK: - Request Completed Row
    private var requestCompletedRow: some View {
        let body = extractRequestText() ?? ""
        let fullText = displayName + " " + "completed " + body
        let alignment: VerticalAlignment = isMultiLine(fullText) ? .top : .center

        return HStack(alignment: alignment, spacing: 8) {
            ProfilePictureView(url: message.avatarUrl, size: 28)
                .padding(.top, alignment == .top ? 1 : 0)
            Group {
                Text(displayName + " ")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                + Text("completed ")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "#F59E0B"))
                + Text(body)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .fixedSize(horizontal: false, vertical: true)
            .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 1)
        }
        .frame(maxWidth: 310, alignment: .leading)
    }

    // MARK: - Extract request text helper
    private func extractRequestText() -> String? {
        let pattern = "\"(.*)\""
        if let range = message.text.range(of: pattern, options: .regularExpression) {
            let match = String(message.text[range])
                .replacingOccurrences(of: "\"", with: "")
            return match.isEmpty ? nil : match
        }
        return nil
    }
}
