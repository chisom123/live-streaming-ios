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
                topBar
                Spacer()
            }
            VStack(spacing: 0) {
                Spacer()
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

    // MARK: - Top bar
    private var topBar: some View {
        ZStack(alignment: .top) {
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
                }
                .padding(.leading)
            }
            .padding(.horizontal)
            .padding(.top)
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
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.messages) { msg in
                        ChatBubbleView(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 320)
            .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.18)
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
            HStack(spacing: 10) {
                // CHANGED: background opacity from 0.25 → 0.15 to match TikTok's darker input
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
                    .padding(.vertical, 11)
                }
                .background(.black.opacity(0.45))
                .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 0.5))
                .clipShape(Capsule())

                // CHANGED: removed the outer stroke ring, kept only the solid filled circle
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
                        Image(systemName: "gift.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 44, height: 44)
            }
            .padding(.horizontal)
            .padding(.bottom)
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
        let isMultiLine = isMessageMultiLine()
        
        return Group {
            if isMultiLine {
                // Multi-line: profile picture at top
                HStack(alignment: .top, spacing: 8) {
                    ProfilePictureView(url: message.avatarUrl, size: 28)
                        .padding(.top, 1)
                    Group {
                        Text(displayName + "  ")
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
            } else {
                // Single-line: profile picture centered with text
                HStack(alignment: .center, spacing: 8) {
                    ProfilePictureView(url: message.avatarUrl, size: 28)
                    Group {
                        Text(displayName + "  ")
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
        }
    }

    private func isMessageMultiLine() -> Bool {
        // If there's a newline, it's definitely multi-line
        if message.text.contains("\n") {
            return true
        }
        
        let fullText = displayName + "  " + message.text
        let font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        let maxWidth: CGFloat = 310 - 36
        
        let nsString = fullText as NSString
        let size = nsString.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        
        return size.height > 24
    }
    
    // MARK: - Join row
    private var joinRow: some View {
        HStack(alignment: .center, spacing: 8) {  // Use .center for single line
            ProfilePictureView(url: message.avatarUrl, size: 28)
            Group {
                Text(displayName + "  ")
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
        let parts      = message.text.components(separatedBy: " · $")
        let reqDesc    = parts.first ?? message.text
        let priceLabel = parts.count > 1 ? "$\(parts[1])" : nil

        return HStack(alignment: .top, spacing: 8) {
            ProfilePictureView(url: message.avatarUrl, size: 28)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(displayName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#FF8C40"))
                    
                    Text("·")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#FF8C40"))
                    
                    if let p = priceLabel {
                        Text("\(p)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#FF8C40"))
                    }
                }
                Text(reqDesc)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(hex: "#FF6B00").opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: 310, alignment: .leading)
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

                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white.opacity(0.18))
                            .frame(width: 36, height: 4)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                            .padding(.bottom, 20)

                        Text("Make a request")
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)

                        sectionLabel("What should they do?")
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

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
