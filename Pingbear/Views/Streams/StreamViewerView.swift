import SwiftUI
import FirebaseAuth
import FirebaseFunctions
import LiveKit

// MARK: - StreamViewerView
struct StreamViewerView: View {

    let stream:   StreamModel
    let onLeave:  () -> Void

    @StateObject private var viewModel: StreamViewerViewModel
    @State private var showRequestSheet = false
    @FocusState private var chatFocused: Bool

    init(stream: StreamModel, onLeave: @escaping () -> Void) {
        self.stream  = stream
        self.onLeave = onLeave
        _viewModel   = StateObject(wrappedValue: StreamViewerViewModel(stream: stream))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Video feed
            if let track = viewModel.streamerTrack {
                SwiftUIVideoView(track)
                    .ignoresSafeArea()
            } else {
                Rectangle()
                    .fill(AppTheme.pageBackground)
                    .ignoresSafeArea()
            }

            if viewModel.isConnecting {
                VStack(spacing: 12) {
                    ProgressView().tint(.white)
                    Text("Joining stream...")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
            } else if viewModel.isEnded {
                streamEndedOverlay
            } else {
                liveOverlay
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

    // MARK: - Live overlay
    private var liveOverlay: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            chatFeed
            bottomBar
        }
    }

    // MARK: - Top bar
    private var topBar: some View {
        HStack(alignment: .center, spacing: 8) {
            // Streamer avatar + name pill
            HStack(spacing: 6) {
                ProfilePictureView(url: stream.streamerImageUrl, size: 30)
                Text(stream.streamerName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.trailing, 4)
            .padding(.vertical, 4)
            .padding(.leading, 4)
            .background(.black.opacity(0.35))
            .clipShape(Capsule())

            // LIVE badge
            Text("LIVE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.danger)
                .clipShape(Capsule())

            // Viewer count
            HStack(spacing: 3) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 9))
                Text("\(stream.viewerIds.count + 1)")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.black.opacity(0.3))
            .clipShape(Capsule())

            Spacer()

            // Close
            Button(action: onLeave) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(.black.opacity(0.3))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 56)
        .padding(.bottom, 8)
    }

    // MARK: - Chat feed
    private var chatFeed: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.messages) { msg in
                        ChatBubbleView(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 240)
            // Fade top of chat into transparent — like TikTok/IG
            .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.22)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
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
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom bar
    private var bottomBar: some View {
        HStack(spacing: 10) {
            // Chat input
            HStack(spacing: 0) {
                TextField("", text: $viewModel.chatText,
                          prompt: Text("Say something...").foregroundColor(.white.opacity(0.35)))
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .tint(AppTheme.accent)
                    .focused($chatFocused)
                    .submitLabel(.send)
                    .onSubmit { viewModel.sendChatMessage() }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
            }
            .background(.white.opacity(0.14))
            .clipShape(Capsule())

            // Request button
            Button {
                Analytics.shared.trackTap(
                    elementId: "open_request_sheet",
                    screenName: "stream_viewer",
                    properties: [AnalyticsProperty.streamId: stream.id]
                )
                showRequestSheet = true
            } label: {
                Image(systemName: "dollarsign")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.accent)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 40)
    }

    // MARK: - Stream ended
    private var streamEndedOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash.fill")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.5))
            Text("Stream ended")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Button(action: onLeave) {
                Text("Close")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.15))
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
        switch message.type {

        // Plain chat — no bubble, inline username + text like TikTok
        case .chat:
            HStack(alignment: .top, spacing: 6) {
                ProfilePictureView(url: message.avatarUrl, size: 22)
                    .padding(.top, 1)
                Group {
                    Text(displayName + "  ")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    + Text(message.text)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                }
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 1)
            }
            .frame(maxWidth: 280, alignment: .leading)

        // Request — subtle pill highlight, not a heavy box
        case .requestEvent:
            HStack(alignment: .top, spacing: 6) {
                ProfilePictureView(url: message.avatarUrl, size: 22)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(displayName) sent a request")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.gold)
                    Text(message.text)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(AppTheme.accent.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppTheme.accent.opacity(0.45), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .frame(maxWidth: 280, alignment: .leading)

        // Join — small centered row with avatar
        case .joinEvent:
            HStack(spacing: 5) {
                ProfilePictureView(url: message.avatarUrl, size: 18)
                Text(isMe ? "You joined" : "\(message.name) joined")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

// MARK: - SendStreamRequestSheet
struct SendStreamRequestSheet: View {

    let stream:     StreamModel
    let onDismiss:  () -> Void

    @State private var description = ""
    @State private var price       = ""
    @State private var isSending   = false
    @State private var errorMessage: String? = nil
    @State private var showWallet = false
    @StateObject private var walletVM = WalletViewModel()

    private let presetPrices   = ["0.50", "1.00", "2.00", "5.00", "10.00", "20.00"]
    private let presetRequests = ["Tell a joke", "Do an impression", "Show us your pet", "Call someone live", "Do a challenge"]
    private let functions      = Functions.functions()

    private var priceDouble: Double { Double(price) ?? 0 }
    private var priceValid:  Bool   { priceDouble >= 0.50 && priceDouble <= 50.00 }
    private var hasFunds:    Bool   { walletVM.balance >= priceDouble }
    private var canSend:     Bool   { priceValid && !description.trimmingCharacters(in: .whitespaces).isEmpty && hasFunds && !isSending }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Drag handle
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppTheme.divider)
                            .frame(width: 36, height: 4)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)

                        Text("Make a request")
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(AppTheme.primaryText)
                            .padding(.horizontal, 20)

                        // Description
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("What do you want them to do?", text: $description, axis: .vertical)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppTheme.primaryText)
                                .lineLimit(3...5)
                                .padding(14)
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .tint(AppTheme.accent)
                                .onChange(of: description) { if $0.count > 120 { description = String($0.prefix(120)) } }
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(presetRequests, id: \.self) { preset in
                                        Button {
                                            description = preset
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        } label: {
                                            Text(preset)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(description == preset ? .white : AppTheme.primaryText)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(description == preset ? AppTheme.accent : AppTheme.cardBackground)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        // Price
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your offer")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.secondaryText)
                                .textCase(.uppercase)
                                .padding(.horizontal, 20)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
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
                                            .cornerRadius(200)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // Balance + top up
                        VStack(spacing: 0) {
                            HStack {
                                Text("Your balance")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.secondaryText)
                                Spacer()
                                Text("$\(String(format: "%.2f", walletVM.balance))")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(hasFunds ? AppTheme.primaryText : AppTheme.danger)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                            if !hasFunds {
                                Divider().background(AppTheme.divider)
                                Button {
                                    Analytics.shared.trackTap(elementId: "top_up_from_stream_request", screenName: "send_stream_request")
                                    showWallet = true
                                } label: {
                                    Text("Top Up Wallet")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .background(AppTheme.accent)
                                        .cornerRadius(200)
                                }
                                .buttonStyle(.plain)
                                .padding(12)
                            }
                        }
                        .background(AppTheme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)

                        if let err = errorMessage {
                            Text(err)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.danger)
                                .padding(.horizontal, 20)
                        }

                        // Send button
                        Button(action: sendRequest) {
                            HStack(spacing: 8) {
                                if isSending {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.disabledText))
                                        .scaleEffect(0.85)
                                }
                                Text(isSending ? "Sending..." : "Send Request")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(canSend ? .white : AppTheme.disabledText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canSend ? AppTheme.accent : AppTheme.disabledBackground)
                            .cornerRadius(200)
                        }
                        .disabled(!canSend)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
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

    private func sendRequest() {
        guard canSend else { return }
        isSending = true
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
