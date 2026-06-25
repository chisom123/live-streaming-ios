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
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil && !viewModel.showEndConfirm },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
    }

    // MARK: - Connecting
    private var connectingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView().tint(.white)
            Text("Starting stream...")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Error
    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44)).foregroundColor(.orange)
            Text("Something went wrong")
                .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            Text(message)
                .font(.system(size: 14)).foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Button(action: onEnd) {
                Text("Go back")
                    .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 32).padding(.vertical, 12)
                    .background(Color.white.opacity(0.15)).cornerRadius(200)
            }
        }
    }

    // MARK: - Live overlay
    private var liveOverlay: some View {
        VStack(spacing: 0) {
            streamerTopBar
            Spacer()
            if !viewModel.acceptedRequests.isEmpty { acceptedRequestsBanner }
            if showRequestQueue { requestQueuePanel }
            VStack(spacing: 0) {
                chatFeed
                streamerBottomBar
            }
        }
    }

    private var streamerTopBar: some View {
        HStack(alignment: .top) {
            HStack(spacing: 8) {
                Text("LIVE")
                    .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(AppTheme.danger).cornerRadius(200)
                HStack(spacing: 4) {
                    Image(systemName: "eye").font(.system(size: 10)).foregroundColor(.white)
                    Text("\(viewModel.viewerCount)")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(.white)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.black.opacity(0.45)).cornerRadius(200)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 13)).foregroundColor(AppTheme.green)
                Text("$\(String(format: "%.2f", viewModel.totalEarned))")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.black.opacity(0.5)).cornerRadius(200)

            Button { viewModel.showEndConfirm = true } label: {
                Text("End")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(AppTheme.danger.opacity(0.8)).cornerRadius(200)
            }
        }
        .padding(.horizontal, 16).padding(.top, 60)
    }

    private var acceptedRequestsBanner: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.acceptedRequests) { req in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(req.fromUserName)
                                .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                            Text(req.description)
                                .font(.system(size: 11)).foregroundColor(.white.opacity(0.75)).lineLimit(1)
                        }
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            viewModel.completeRequest(req)
                        } label: {
                            Text("Done  $\(String(format: "%.2f", req.creatorPayout))")
                                .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(AppTheme.green).cornerRadius(200)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(AppTheme.accent.opacity(0.2))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.accent.opacity(0.5), lineWidth: 0.5))
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    private var requestQueuePanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Requests")
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                Spacer()
                Text("\(viewModel.pendingRequests.count) pending")
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
                Button { showRequestQueue = false } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14)).foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Divider().background(Color.white.opacity(0.15))
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.pendingRequests) { req in
                        StreamerRequestCard(
                            request:   req,
                            onAccept:  { viewModel.acceptRequest(req) },
                            onDecline: { viewModel.declineRequest(req) }
                        )
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: 240)
        }
        .background(Color.black.opacity(0.75))
        .clipShape(RoundedCorner(radius: 16, corners: [.topLeft, .topRight]))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Chat Feed (read-only for streamer)
    private var chatFeed: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.messages) { msg in
                        ChatBubbleView(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 160)
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
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var streamerBottomBar: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showRequestQueue.toggle()
                }
                Analytics.shared.trackTap(elementId: "toggle_request_queue", screenName: "streamer_live",
                                           properties: [AnalyticsProperty.streamId: streamId])
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet").font(.system(size: 14)).foregroundColor(.white)
                    Text("Requests").font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                    if viewModel.pendingRequests.count > 0 {
                        Text("\(viewModel.pendingRequests.count)")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(AppTheme.danger).clipShape(Circle())
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.black.opacity(0.5)).cornerRadius(200)
            }

            Button {
                Analytics.shared.trackTap(elementId: "flip_camera", screenName: "streamer_live")
                Task {
                    if let track = viewModel.localVideoTrack,
                       let capturer = track.capturer as? CameraCapturer {
                        try? await capturer.switchCameraPosition()
                    }
                }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16)).foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.5)).clipShape(Circle())
            }

            Spacer()
        }
        .padding(.horizontal, 16).padding(.bottom, 50)
    }

    // MARK: - End confirm
    private var endConfirmDialog: some View {
        Color.black.opacity(0.6).ignoresSafeArea()
            .overlay(
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("End stream?")
                            .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        Text("Any open requests will be automatically refunded.")
                            .font(.system(size: 14)).foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    HStack(spacing: 12) {
                        Button { viewModel.showEndConfirm = false } label: {
                            Text("Cancel")
                                .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color.white.opacity(0.15)).cornerRadius(200)
                        }
                        Button {
                            viewModel.showEndConfirm = false
                            Task { await viewModel.endStream(); onEnd() }
                        } label: {
                            HStack(spacing: 6) {
                                if viewModel.isEnding {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                }
                                Text("End stream")
                                    .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(AppTheme.danger).cornerRadius(200)
                        }
                        .disabled(viewModel.isEnding)
                    }
                }
                .padding(24)
                .background(AppTheme.pageBackground)
                .cornerRadius(20)
                .padding(.horizontal, 32)
            )
    }
}

// MARK: - StreamerRequestCard
struct StreamerRequestCard: View {
    let request:   StreamRequest
    let onAccept:  () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    ProfilePictureView(url: request.fromUserImageUrl, size: 28)
                    Text(request.fromUserName)
                        .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                }
                Spacer()
                Text("$\(String(format: "%.2f", request.price))")
                    .font(.system(size: 16, weight: .bold)).foregroundColor(AppTheme.accent)
            }
            Text(request.description)
                .font(.system(size: 14)).foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button(action: onDecline) {
                    Text("Decline")
                        .font(.system(size: 13, weight: .bold)).foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Color.white.opacity(0.1)).cornerRadius(200)
                }
                Button(action: onAccept) {
                    Text("Accept  $\(String(format: "%.2f", request.creatorPayout))")
                        .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(AppTheme.green).cornerRadius(200)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
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
            AppTheme.pageBackground.ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56)).foregroundColor(AppTheme.green)
                Text("Stream ended")
                    .font(.system(size: 28, weight: .black)).foregroundColor(AppTheme.primaryText)
                VStack(spacing: 12) {
                    statRow(label: "Earned",             value: "$\(String(format: "%.2f", totalEarned))")
                    statRow(label: "Requests completed", value: "\(requestCount)")
                    statRow(label: "Duration",           value: durationFormatted)
                }
                .padding(20).background(AppTheme.cardBackground).cornerRadius(16)
                .padding(.horizontal, 32)
                Spacer()
                Button(action: onDismiss) {
                    Text("Done")
                        .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(AppTheme.accent).cornerRadius(200)
                }
                .padding(.horizontal, 32).padding(.bottom, 48)
            }
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 15)).foregroundColor(AppTheme.secondaryText)
            Spacer()
            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(AppTheme.primaryText)
        }
    }

    private var durationFormatted: String {
        let mins = durationSecs / 60
        let secs = durationSecs % 60
        return mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
    }
}
