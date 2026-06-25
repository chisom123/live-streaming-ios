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
                SwiftUIVideoView(track).ignoresSafeArea()
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
        }
    }

    // MARK: - Connecting
    private var connectingOverlay: some View {
        CustomSpinner()
            .frame(width: 50, height: 50)
    }

    // Add this as a separate view or struct
    struct CustomSpinner: View {
        @State private var isAnimating = false
        
        var body: some View {
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(
                    Animation.linear(duration: 1)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )
                .onAppear {
                    isAnimating = true
                }
        }
    }

    // MARK: - Live overlay
    private var liveOverlay: some View {
        ZStack(alignment: .bottom) {
            VStack {
                topGradientBar
                Spacer()
            }
            VStack(spacing: 0) {
                Spacer()
                // Active request banner — uses viewModel.activeRequestDescription
                // which you expose as a simple String? so no ObservableObject issues
                if let activeDesc = viewModel.activeRequestDescription {
                    viewerActiveBanner(activeDesc)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                chatFeed
                bottomBar
            }
        }
        .animation(
            .spring(response: 0.35, dampingFraction: 0.85),
            value: viewModel.activeRequestDescription != nil
        )
    }

    // MARK: - Top gradient bar
    private var topGradientBar: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [.black.opacity(0.65), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 120)
            .ignoresSafeArea()

            HStack(alignment: .center, spacing: 8) {
                // Streamer pill
                HStack(spacing: 6) {
                    ProfilePictureView(url: stream.streamerImageUrl, size: 28)
                    Text(stream.streamerName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .padding(.leading, 4)
                .padding(.trailing, 10)
                .padding(.vertical, 4)
                .background(.white.opacity(0.1))
                .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5))
                .clipShape(Capsule())

                // LIVE badge
                Text("LIVE")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white)
                    .kerning(0.5)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color(hex: "#E24B4A"))
                    .clipShape(Capsule())

                // Viewer count — driven by viewModel.viewerCount which updates
                // in real-time from the stream document Firestore listener
                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 9))
                    Text(formattedViewerCount(viewModel.viewerCount))
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.white.opacity(0.1))
                .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5))
                .clipShape(Capsule())

                Spacer()

                // Leave button
                Button { showLeaveConfirm = true } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.1))
                        .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 0.5))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
        }
    }

    private func formattedViewerCount(_ count: Int) -> String {
        count >= 1000 ? String(format: "%.1fk", Double(count) / 1000) : "\(count)"
    }

    // MARK: - Active request banner (viewer read-only)
    private func viewerActiveBanner(_ description: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: "#16A34A"))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text("Now performing")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "#4ade80"))
                Text(description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: "#16A34A").opacity(0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#16A34A").opacity(0.4), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Chat feed
    private var chatFeed: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(viewModel.messages) { msg in
                        ChatBubbleView(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 220)
            .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.25)
                    ]),
                    startPoint: .top, endPoint: .bottom
                )
            )
            .onChange(of: viewModel.messages.count) { _ in
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Bottom bar
    private var bottomBar: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 110)
            .ignoresSafeArea()

            HStack(spacing: 10) {
                // Chat input
                HStack {
                    TextField(
                        "",
                        text: $viewModel.chatText,
                        prompt: Text("Say something...").foregroundColor(.white.opacity(0.3))
                    )
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .tint(Color(hex: "#FF6B00"))
                    .focused($chatFocused)
                    .submitLabel(.send)
                    .onSubmit { viewModel.sendChatMessage() }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                }
                .background(.white.opacity(0.12))
                .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 0.5))
                .clipShape(Capsule())

                // Request FAB — primary action
                Button {
                    Analytics.shared.trackTap(
                        elementId: "open_request_sheet",
                        screenName: "stream_viewer",
                        properties: [AnalyticsProperty.streamId: stream.id]
                    )
                    showRequestSheet = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#FF6B00"))
                            .frame(width: 44, height: 44)
                        Circle()
                            .stroke(Color(hex: "#FF6B00").opacity(0.3), lineWidth: 4)
                            .frame(width: 52, height: 52)
                        Image(systemName: "dollarsign")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 52, height: 52)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 42)
        }
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
                            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5))
                            .clipShape(Capsule())
                    }
                    Button(action: onLeave) {
                        Text("Leave")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.08))
                            .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(24)
            .background(Color(hex: "#141414"))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            )
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
                    .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5))
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
            case .chat:         chatRow
            case .requestEvent: requestRow
            case .joinEvent:    joinRow
            }
        }
    }

    // MARK: - Chat row
    private var chatRow: some View {
        HStack(alignment: .top, spacing: 6) {
            ProfilePictureView(url: message.avatarUrl, size: 20)
                .padding(.top, 1)
            Group {
                Text(displayName + "  ")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                + Text(message.text)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.85))
            }
            .fixedSize(horizontal: false, vertical: true)
            .shadow(color: .black.opacity(0.7), radius: 3, x: 0, y: 1)
        }
        .frame(maxWidth: 290, alignment: .leading)
    }

    // MARK: - Request row
    // message.text is stored as "description · $5.00" by sendStreamRequest cloud function.
    // Split on " · $" to render description and price separately.
    private var requestRow: some View {
        let parts      = message.text.components(separatedBy: " · $")
        let reqDesc    = parts.first ?? message.text
        let priceLabel = parts.count > 1 ? "$\(parts[1])" : nil

        return HStack(alignment: .top, spacing: 6) {
            ProfilePictureView(url: message.avatarUrl, size: 20)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(hex: "#FF6B00"))
                        .frame(width: 4, height: 4)
                    Text(displayName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "#FF8C40"))
                    if let p = priceLabel {
                        Text("· \(p)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "#FF8C40"))
                    }
                }
                Text(reqDesc)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(hex: "#FF6B00").opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(hex: "#FF6B00").opacity(0.35), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: 290, alignment: .leading)
    }

    // MARK: - Join row
    private var joinRow: some View {
        HStack(spacing: 4) {
            ProfilePictureView(url: message.avatarUrl, size: 14)
            Text(isMe ? "You joined" : "\(message.name) joined")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.32))
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - SendStreamRequestSheet
struct SendStreamRequestSheet: View {

    let stream:    StreamModel
    let onDismiss: () -> Void

    @State private var description  = ""
    @State private var price        = ""
    @State private var isSending    = false
    @State private var errorMessage: String? = nil
    @State private var showWallet   = false
    @StateObject private var walletVM = WalletViewModel()

    private let presetPrices   = ["0.50", "1.00", "2.00", "5.00", "10.00", "20.00"]
    private let presetRequests = ["Tell a joke", "Do an impression", "Show your pet", "Call someone live", "Do a challenge"]
    private let functions      = Functions.functions()

    private var priceDouble: Double { Double(price) ?? 0 }
    private var priceValid:  Bool   { priceDouble >= 0.50 && priceDouble <= 50.00 }
    private var hasFunds:    Bool   { walletVM.balance >= priceDouble }
    private var descFilled:  Bool   { !description.trimmingCharacters(in: .whitespaces).isEmpty }
    private var canSend:     Bool   { priceValid && descFilled && hasFunds && !isSending }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#111111").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // Drag handle
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white.opacity(0.18))
                            .frame(width: 36, height: 4)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                            .padding(.bottom, 20)

                        // Title
                        Text("Make a request")
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)

                        // Description section
                        sectionLabel("What should they do?")
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                        // axis parameter removed — use the lineLimit approach instead
                        // for broader SDK compatibility
                        ZStack(alignment: .topLeading) {
                            if description.isEmpty {
                                Text("Describe your request...")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.28))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $description)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .tint(Color(hex: "#FF6B00"))
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .frame(minHeight: 80, maxHeight: 120)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .onChange(of: description) { if $0.count > 120 { description = String($0.prefix(120)) } }
                        }
                        .background(.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.1), lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)

                        // Preset chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 7) {
                                ForEach(presetRequests, id: \.self) { preset in
                                    Button {
                                        description = preset
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    } label: {
                                        Text(preset)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(description == preset ? .white : .white.opacity(0.6))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(
                                                description == preset
                                                    ? Color(hex: "#FF6B00")
                                                    : .white.opacity(0.08)
                                            )
                                            .overlay(
                                                Capsule().stroke(
                                                    description == preset
                                                        ? Color.clear
                                                        : .white.opacity(0.1),
                                                    lineWidth: 0.5
                                                )
                                            )
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 28)

                        // Price section
                        sectionLabel("Your offer")
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                            spacing: 8
                        ) {
                            ForEach(presetPrices, id: \.self) { preset in
                                Button {
                                    price = preset
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Text("$\(preset)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(price == preset ? .white : .white.opacity(0.65))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(
                                            price == preset
                                                ? Color(hex: "#FF6B00")
                                                : .white.opacity(0.07)
                                        )
                                        .overlay(
                                            Capsule().stroke(
                                                price == preset
                                                    ? Color.clear
                                                    : .white.opacity(0.1),
                                                lineWidth: 0.5
                                            )
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                        // Balance row
                        HStack {
                            Text("Balance")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                            Spacer()
                            if !hasFunds && priceValid {
                                Text("Insufficient funds")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: "#E24B4A"))
                                    .padding(.trailing, 6)
                            }
                            Text("$\(String(format: "%.2f", walletVM.balance))")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(hasFunds ? .white : Color(hex: "#E24B4A"))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.08), lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)

                        // Top up button
                        if !hasFunds && priceValid {
                            Button {
                                Analytics.shared.trackTap(
                                    elementId: "top_up_from_stream_request",
                                    screenName: "send_stream_request"
                                )
                                showWallet = true
                            } label: {
                                Text("Top up wallet")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(Color(hex: "#FF6B00"))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                        }

                        if let err = errorMessage {
                            Text(err)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "#E24B4A"))
                                .padding(.horizontal, 20)
                                .padding(.top, 10)
                        }

                        // Send button
                        Button(action: sendRequest) {
                            HStack(spacing: 8) {
                                if isSending {
                                    ProgressView()
                                        .progressViewStyle(
                                            CircularProgressViewStyle(tint: .white.opacity(0.5))
                                        )
                                        .scaleEffect(0.8)
                                }
                                Text(sendButtonLabel)
                                    .font(.system(size: 17, weight: .black))
                                    .foregroundColor(canSend ? .white : .white.opacity(0.3))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(canSend ? Color(hex: "#FF6B00") : .white.opacity(0.07))
                            .clipShape(Capsule())
                        }
                        .disabled(!canSend)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 48)
                    }
                }
            }
            .fullScreenCover(isPresented: $showWallet) {
                WalletView(onDismiss: { showWallet = false })
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "send_stream_request")
            walletVM.startListening()
        }
        .onDisappear { walletVM.stopListening() }
    }

    private var sendButtonLabel: String {
        if isSending { return "Sending..." }
        if priceValid { return "Send request · $\(price)" }
        return "Send request"
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white.opacity(0.35))
            .kerning(0.6)
    }

    private func sendRequest() {
        guard canSend else { return }
        isSending    = true
        errorMessage = nil

        Task {
            do {
                let result = try await functions.httpsCallable("sendStreamRequest").call([
                    "streamId":    stream.id,
                    "description": description.trimmingCharacters(in: .whitespaces),
                    "price":       priceDouble
                ])
                guard let data      = result.data as? [String: Any],
                      let requestId = data["requestId"] as? String
                else { throw NSError(domain: "Stream", code: -1) }

                Analytics.shared.trackStreamRequest(
                    action:    "sent",
                    streamId:  stream.id,
                    requestId: requestId,
                    amount:    priceDouble
                )
                await MainActor.run { onDismiss() }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSending    = false
                }
            }
        }
    }
}
