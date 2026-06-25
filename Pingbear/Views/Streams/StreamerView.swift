import SwiftUI
import LiveKit
import AVFoundation

// MARK: - StreamerView
struct StreamerView: View {

    let streamId:     String
    let initialToken: String?
    let initialUrl:   String?
    let onEnd:        () -> Void

    @StateObject private var viewModel: StreamerViewModel
    @State private var showRequestQueue = false

    init(streamId: String, initialToken: String? = nil, initialUrl: String? = nil, onEnd: @escaping () -> Void) {
        self.streamId     = streamId
        self.initialToken = initialToken
        self.initialUrl   = initialUrl
        self.onEnd        = onEnd
        _viewModel = StateObject(wrappedValue: StreamerViewModel(
            streamId:     streamId,
            initialToken: initialToken,
            initialUrl:   initialUrl
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let track = viewModel.localVideoTrack {
                SwiftUIVideoView(track).ignoresSafeArea()
            }

            if viewModel.isConnecting {
                connectingOverlay
            } else if let err = viewModel.errorMessage {
                errorOverlay(err)
            } else {
                liveOverlay
            }

            if viewModel.showEndConfirm {
                endConfirmDialog
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "streamer_live")
            Task { await viewModel.startBroadcast() }
        }
        .onDisappear { viewModel.stopListening() }
    }

    // MARK: - Connecting
    private var connectingOverlay: some View {
        VStack(spacing: 14) {
            ProgressView().tint(.white)
            Text("Starting your stream...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Error
    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.orange)
            }
            Text("Something went wrong")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: onEnd) {
                Text("Go back")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 13)
                    .background(.white.opacity(0.1))
                    .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Live overlay
    private var liveOverlay: some View {
        ZStack(alignment: .bottom) {
            // Top
            VStack {
                streamerTopBar
                Spacer()
            }

            // Bottom stack
            VStack(spacing: 0) {
                Spacer()

                // Active accepted request banner
                if let active = viewModel.acceptedRequests.first {
                    acceptedRequestBanner(active)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Request queue panel (slides up)
                if showRequestQueue {
                    requestQueuePanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                chatFeed
                streamerBottomBar
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.85), value: showRequestQueue)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.acceptedRequests.first?.id ?? "")
        }
    }

    // MARK: - Top bar
    private var streamerTopBar: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [.black.opacity(0.65), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 120)
            .ignoresSafeArea()

            HStack(alignment: .center, spacing: 8) {
                // LIVE
                Text("LIVE")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white)
                    .kerning(0.5)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color(hex: "#E24B4A"))
                    .clipShape(Capsule())

                // Viewer count
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

                // Earnings
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(hex: "#16A34A"))
                        .frame(width: 6, height: 6)
                    Text("$\(String(format: "%.2f", viewModel.totalEarned))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.black.opacity(0.45))
                .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 0.5))
                .clipShape(Capsule())

                // End stream
                Button { viewModel.showEndConfirm = true } label: {
                    Text("End")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "#f87171"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#E24B4A").opacity(0.12))
                        .overlay(
                            Capsule().stroke(Color(hex: "#E24B4A").opacity(0.55), lineWidth: 0.5)
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 58)
        }
    }

    private func formattedViewerCount(_ count: Int) -> String {
        count >= 1000 ? String(format: "%.1fk", Double(count) / 1000) : "\(count)"
    }

    // MARK: - Accepted request banner (streamer actionable)
    private func acceptedRequestBanner(_ request: StreamRequest) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(hex: "#16A34A"))
                        .frame(width: 5, height: 5)
                    Text(request.fromUserName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#4ade80"))
                }
                Text(request.description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.completeRequest(request)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                    Text("Done · $\(String(format: "%.2f", request.creatorPayout))")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(Color(hex: "#16A34A"))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(hex: "#16A34A").opacity(0.14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#16A34A").opacity(0.38), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Request queue panel
    private var requestQueuePanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Requests")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(viewModel.pendingRequests.count) pending")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.45))
                Button { showRequestQueue = false } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.45))
                        .padding(.leading, 10)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            Divider()
                .background(.white.opacity(0.08))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Array(viewModel.pendingRequests.enumerated()), id: \.element.id) { index, req in
                        StreamerRequestCard(
                            request:   req,
                            isTop:     index == 0,
                            onAccept:  { viewModel.acceptRequest(req) },
                            onDecline: { viewModel.declineRequest(req) }
                        )
                    }
                    if viewModel.pendingRequests.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "tray")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.2))
                            Text("No pending requests")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .frame(maxHeight: 260)
        }
        .background(Color(hex: "#111111").opacity(0.96))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.1), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Chat feed (read-only)
    private var chatFeed: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(viewModel.messages) { msg in
                        ChatBubbleView(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
            .frame(maxHeight: 150)
            .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.28)
                    ]),
                    startPoint: .top, endPoint: .bottom
                )
            )
            .onChange(of: viewModel.messages.count) { _ in
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Bottom bar
    private var streamerBottomBar: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 100)
            .ignoresSafeArea()

            HStack(spacing: 10) {
                // Requests toggle
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                        showRequestQueue.toggle()
                    }
                    Analytics.shared.trackTap(
                        elementId: "toggle_request_queue",
                        screenName: "streamer_live",
                        properties: [AnalyticsProperty.streamId: streamId]
                    )
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 13))
                        Text("Requests")
                            .font(.system(size: 13, weight: .semibold))
                        if viewModel.pendingRequests.count > 0 {
                            Text("\(viewModel.pendingRequests.count)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 18, height: 18)
                                .background(Color(hex: "#E24B4A"))
                                .clipShape(Circle())
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        showRequestQueue
                            ? .white.opacity(0.16)
                            : .white.opacity(0.1)
                    )
                    .overlay(
                        Capsule().stroke(
                            showRequestQueue
                                ? .white.opacity(0.25)
                                : .white.opacity(0.14),
                            lineWidth: 0.5
                        )
                    )
                    .clipShape(Capsule())
                }

                // Flip camera
                Button {
                    Analytics.shared.trackTap(elementId: "flip_camera", screenName: "streamer_live")
                    Task {
                        if let track = viewModel.localVideoTrack,
                           let capturer = track.capturer as? CameraCapturer {
                            try? await capturer.switchCameraPosition()
                        }
                    }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.1))
                        .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 0.5))
                        .clipShape(Circle())
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 46)
        }
    }

    // MARK: - End confirm dialog
    private var endConfirmDialog: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#E24B4A").opacity(0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: "stop.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "#f87171"))
                    }
                    Text("End stream?")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.white)
                    Text("Open requests will be automatically refunded to viewers.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                HStack(spacing: 10) {
                    Button { viewModel.showEndConfirm = false } label: {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(.white.opacity(0.08))
                            .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5))
                            .clipShape(Capsule())
                    }
                    Button {
                        viewModel.showEndConfirm = false
                        Task { await viewModel.endStream(); onEnd() }
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.isEnding {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text("End stream")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color(hex: "#E24B4A"))
                        .clipShape(Capsule())
                    }
                    .disabled(viewModel.isEnding)
                }
            }
            .padding(24)
            .background(Color(hex: "#161616"))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - StreamerRequestCard
struct StreamerRequestCard: View {
    let request:   StreamRequest
    let isTop:     Bool
    let onAccept:  () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                ProfilePictureView(url: request.fromUserImageUrl, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(request.fromUserName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("$\(String(format: "%.2f", request.price))")
                    .font(.system(size: 17, weight: .black))
                    .foregroundColor(Color(hex: "#FF6B00"))
            }

            Text(request.description)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)

            HStack(spacing: 8) {
                Button(action: onDecline) {
                    Text("Decline")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.06))
                        .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 0.5))
                        .clipShape(Capsule())
                }
                Button(action: onAccept) {
                    HStack(spacing: 4) {
                        Text("Accept")
                        Text("· $\(String(format: "%.2f", request.creatorPayout))")
                            .opacity(0.8)
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#16A34A"))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(13)
        .background(
            isTop
                ? Color(hex: "#FF6B00").opacity(0.1)
                : .white.opacity(0.06)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(
                    isTop
                        ? Color(hex: "#FF6B00").opacity(0.28)
                        : .white.opacity(0.09),
                    lineWidth: 0.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }
}

// MARK: - StreamSummaryView
struct StreamSummaryView: View {
    let streamId:     String
    let totalEarned:  Double
    let requestCount: Int
    let durationSecs: Int
    let onDismiss:    () -> Void

    var body: some View {
        ZStack {
            Color(hex: "#0d0d0d").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Check icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "#16A34A").opacity(0.15))
                        .frame(width: 72, height: 72)
                    Circle()
                        .stroke(Color(hex: "#16A34A").opacity(0.3), lineWidth: 0.5)
                        .frame(width: 72, height: 72)
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Color(hex: "#16A34A"))
                }
                .padding(.bottom, 20)

                Text("Stream ended")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.white)
                    .padding(.bottom, 6)

                // Hero earned amount
                Text("$\(String(format: "%.2f", totalEarned))")
                    .font(.system(size: 52, weight: .black))
                    .foregroundColor(.white)
                    .tracking(-1)
                    .padding(.bottom, 4)

                Text("total earned")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.bottom, 36)

                // Stats card
                VStack(spacing: 0) {
                    summaryRow(
                        icon: "checkmark.circle",
                        label: "Requests completed",
                        value: "\(requestCount)"
                    )
                    Divider().background(.white.opacity(0.07))
                    summaryRow(
                        icon: "clock",
                        label: "Duration",
                        value: durationFormatted
                    )
                }
                .padding(.vertical, 4)
                .background(.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.08), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 32)
                .padding(.bottom, 36)

                Spacer()

                Button(action: onDismiss) {
                    Text("Done")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Color(hex: "#FF6B00"))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.35))
                .frame(width: 20)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.45))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var durationFormatted: String {
        let mins = durationSecs / 60
        let secs = durationSecs % 60
        return mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
    }
}
