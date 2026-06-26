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
        .sheet(isPresented: $showRequestQueue) {
            StreamerRequestSheet(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
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
                Circle().fill(Color.orange.opacity(0.15)).frame(width: 64, height: 64)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 26)).foregroundColor(.orange)
            }
            Text("Something went wrong")
                .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            Text(message)
                .font(.system(size: 13)).foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button(action: onEnd) {
                Text("Go back")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    .padding(.horizontal, 32).padding(.vertical, 13)
                    .background(.white.opacity(0.1))
                    .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Live overlay
    private var liveOverlay: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                streamerTopBar
                // Calling banner — visible until first viewer joins
                if viewModel.isCallingFriends {
                    callingFriendsBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                Spacer()
            }

            VStack(spacing: 0) {
                Spacer()
                if let active = viewModel.acceptedRequests.first {
                    acceptedRequestBanner(active)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                chatFeed
                streamerBottomBar
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.acceptedRequests.first?.id ?? "")
        }
        .animation(.easeInOut(duration: 0.4), value: viewModel.isCallingFriends)
    }

    // MARK: - Calling friends banner
    private var callingFriendsBanner: some View {
        HStack(spacing: 10) {
            CallingSpinner()
                .frame(width: 16, height: 16)
            Text("Calling friends to join")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.08))
        .overlay(
            Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5)
        )
        .clipShape(Capsule())
    }

    // MARK: - Top bar
    private var streamerTopBar: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("LIVE")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .kerning(0.5)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Color(hex: "#E24B4A")).clipShape(Capsule())

            HStack(spacing: 4) {
                Image(systemName: "eye.fill").font(.system(size: 12))
                Text(formattedViewerCount(viewModel.viewerCount))
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(.white.opacity(0.1)).clipShape(Capsule())

            HStack(spacing: 4) {
                Circle().fill(Color(hex: "#16A34A")).frame(width: 6, height: 6)
                Text("$\(String(format: "%.2f", viewModel.totalEarned))")
                    .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
            }
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(.white.opacity(0.1)).clipShape(Capsule())

            Spacer()

            Button { viewModel.showEndConfirm = true } label: {
                Text("End")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#f87171"))
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .background(Color(hex: "#E24B4A").opacity(0.12))
                    .overlay(Capsule().stroke(Color(hex: "#E24B4A").opacity(0.55), lineWidth: 0.5))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 58)
    }

    private func formattedViewerCount(_ count: Int) -> String {
        count >= 1000 ? String(format: "%.1fk", Double(count) / 1000) : "\(count)"
    }

    // MARK: - Accepted request banner
    private func acceptedRequestBanner(_ request: StreamRequest) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Circle().fill(Color(hex: "#16A34A")).frame(width: 5, height: 5)
                    Text(request.fromUserName)
                        .font(.system(size: 11, weight: .bold)).foregroundColor(Color(hex: "#4ade80"))
                }
                Text(request.description)
                    .font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.9)).lineLimit(1)
            }
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.completeRequest(request)
            } label: {
                Text("Done · $\(String(format: "%.2f", request.creatorPayout))")
                    .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .background(Color(hex: "#16A34A")).clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color(hex: "#16A34A").opacity(0.14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#16A34A").opacity(0.38), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Chat feed
    private var chatFeed: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.messages) { msg in
                        ChatBubbleView(message: msg).id(msg.id)
                    }
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
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
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Bottom bar
    private var streamerBottomBar: some View {
        HStack(spacing: 10) {
            Button {
                Analytics.shared.trackTap(
                    elementId: "toggle_request_queue",
                    screenName: "streamer_live",
                    properties: [AnalyticsProperty.streamId: streamId]
                )
                showRequestQueue = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "list.bullet").font(.system(size: 13))
                    Text("Requests").font(.system(size: 13, weight: .semibold))
                    if viewModel.pendingRequests.count > 0 {
                        Text("\(viewModel.pendingRequests.count)")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                            .frame(width: 18, height: 18)
                            .background(Color(hex: "#E24B4A")).clipShape(Circle())
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(.white.opacity(0.1))
                .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 0.5))
                .clipShape(Capsule())
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
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 15)).foregroundColor(.white.opacity(0.8))
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

    // MARK: - End confirm dialog
    private var endConfirmDialog: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color(hex: "#E24B4A").opacity(0.15)).frame(width: 52, height: 52)
                        if viewModel.isEnding {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#f87171")))
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "stop.fill").font(.system(size: 18))
                                .foregroundColor(Color(hex: "#f87171"))
                        }
                    }
                    Text(viewModel.isEnding ? "Ending stream..." : "End stream?")
                        .font(.system(size: 19, weight: .bold)).foregroundColor(.white)
                    if !viewModel.isEnding {
                        Text("Open requests will be automatically refunded to viewers.")
                            .font(.system(size: 13)).foregroundColor(.white.opacity(0.45))
                            .multilineTextAlignment(.center).padding(.horizontal, 8)
                    }
                }
                if !viewModel.isEnding {
                    HStack(spacing: 10) {
                        Button { viewModel.showEndConfirm = false } label: {
                            Text("Cancel").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 15)
                                .background(.white.opacity(0.08))
                                .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5))
                                .clipShape(Capsule())
                        }
                        Button {
                            Task { await viewModel.endStream(); onEnd(); viewModel.showEndConfirm = false }
                        } label: {
                            Text("End stream").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 15)
                                .background(Color(hex: "#E24B4A")).clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(24)
            .background(Color(hex: "#161616"))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.1), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - CallingSpinner
// Matches the custom spinner used in StreamViewerView
struct CallingSpinner: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}

// MARK: - StreamerRequestSheet
struct StreamerRequestSheet: View {

    @ObservedObject var viewModel: StreamerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: "#111111").ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.18))
                    .frame(width: 36, height: 4).frame(maxWidth: .infinity)
                    .padding(.top, 12).padding(.bottom, 16)

                HStack {
                    Text("Requests").font(.system(size: 24, weight: .black)).foregroundColor(.white)
                    Spacer()
                    Text("\(viewModel.pendingRequests.count) pending")
                        .font(.system(size: 13)).foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 20).padding(.bottom, 16)

                Divider().background(.white.opacity(0.08))

                if viewModel.pendingRequests.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "tray").font(.system(size: 28)).foregroundColor(.white.opacity(0.2))
                        Text("No pending requests").font(.system(size: 14)).foregroundColor(.white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 60)
                } else {
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
                        }
                        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 32)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - StreamerRequestCard
struct StreamerRequestCard: View {
    let request:   StreamRequest
    let isTop:     Bool
    let onAccept:  () -> Void
    let onDecline: () -> Void

    @State private var actionState: ActionState = .idle
    enum ActionState { case idle, accepting, declining }
    private var isActing: Bool { actionState != .idle }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 9) {
                ProfilePictureView(url: request.fromUserImageUrl, size: 28)
                Text(request.fromUserName).font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(String(format: "%.2f", request.creatorPayout))")
                        .font(.system(size: 17, weight: .black)).foregroundColor(Color(hex: "#FF6B00"))
                    Text("$\(String(format: "%.2f", request.price)) before fees")
                        .font(.system(size: 10, weight: .semibold)).foregroundColor(.white.opacity(0.35))
                }
            }

            Text(request.description).font(.system(size: 13)).foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true).lineLimit(3)

            HStack(spacing: 8) {
                Button {
                    guard !isActing else { return }
                    actionState = .declining
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDecline()
                } label: {
                    HStack(spacing: 6) {
                        if actionState == .declining {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.4))).scaleEffect(0.75)
                            Text("Declining...").font(.system(size: 13, weight: .bold)).foregroundColor(.white.opacity(0.3))
                        } else {
                            Text("Decline").font(.system(size: 13, weight: .bold))
                                .foregroundColor(isActing ? .white.opacity(0.2) : .white.opacity(0.5))
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(isActing ? .white.opacity(0.03) : .white.opacity(0.06))
                    .overlay(Capsule().stroke(.white.opacity(isActing ? 0.05 : 0.1), lineWidth: 0.5))
                    .clipShape(Capsule())
                }
                .disabled(isActing)

                Button {
                    guard !isActing else { return }
                    actionState = .accepting
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onAccept()
                } label: {
                    HStack(spacing: 6) {
                        if actionState == .accepting {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.5))).scaleEffect(0.75)
                            Text("Accepting...").font(.system(size: 13, weight: .bold)).foregroundColor(.white.opacity(0.5))
                        } else {
                            Text("Accept").font(.system(size: 13, weight: .bold))
                                .foregroundColor(isActing ? .white.opacity(0.4) : .white)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(isActing ? Color(hex: "#16A34A").opacity(0.4) : Color(hex: "#16A34A"))
                    .clipShape(Capsule())
                }
                .disabled(isActing)
            }
        }
        .padding(13)
        .background(isTop ? Color(hex: "#FF6B00").opacity(0.1) : .white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(isTop ? Color(hex: "#FF6B00").opacity(0.28) : .white.opacity(0.09), lineWidth: 0.5)
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
                ZStack {
                    Circle().fill(Color(hex: "#16A34A").opacity(0.15)).frame(width: 72, height: 72)
                    Circle().stroke(Color(hex: "#16A34A").opacity(0.3), lineWidth: 0.5).frame(width: 72, height: 72)
                    Image(systemName: "checkmark").font(.system(size: 26, weight: .bold)).foregroundColor(Color(hex: "#16A34A"))
                }
                .padding(.bottom, 20)
                Text("Stream ended").font(.system(size: 26, weight: .black)).foregroundColor(.white).padding(.bottom, 6)
                Text("$\(String(format: "%.2f", totalEarned))").font(.system(size: 52, weight: .black)).foregroundColor(.white).tracking(-1).padding(.bottom, 4)
                Text("total earned").font(.system(size: 13)).foregroundColor(.white.opacity(0.35)).padding(.bottom, 36)
                VStack(spacing: 0) {
                    summaryRow(icon: "checkmark.circle", label: "Requests completed", value: "\(requestCount)")
                    Divider().background(.white.opacity(0.07))
                    summaryRow(icon: "clock", label: "Duration", value: durationFormatted)
                }
                .padding(.vertical, 4)
                .background(.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 32).padding(.bottom, 36)
                Spacer()
                Button(action: onDismiss) {
                    Text("Done").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 17)
                        .background(Color(hex: "#FF6B00")).clipShape(Capsule())
                }
                .padding(.horizontal, 32).padding(.bottom, 52)
            }
        }
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(.white.opacity(0.35)).frame(width: 20)
            Text(label).font(.system(size: 14)).foregroundColor(.white.opacity(0.45))
            Spacer()
            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private var durationFormatted: String {
        let mins = durationSecs / 60
        let secs = durationSecs % 60
        return mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
    }
}
