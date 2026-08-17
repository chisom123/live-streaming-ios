import SwiftUI
import FirebaseAuth

// MARK: - HomeFeedView
struct HomeFeedView: View {

    @StateObject private var viewModel = HomeFeedViewModel()
    @State private var showCreateStream = false
    @State private var viewerStream:    StreamModel?  = nil
    @State private var streamerItem:    StreamIDItem? = nil

    private let currentUserId = Auth.auth().currentUser?.uid ?? ""
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if viewModel.isLoading {
                    Spacer()
                    ProgressView().tint(AppTheme.primaryText)
                    Spacer()
                } else {
                    ZStack(alignment: .bottom) {
                        ScrollView {
                            VStack(spacing: 20) {
                                if !viewModel.liveStreams.isEmpty {
                                    liveSection
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 100)
                        }

                        VStack(spacing: 14) {
                            if viewModel.liveStreams.isEmpty {
                                EarningsTooltipView()
                            }

                            actionButtons
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.pageBackground.opacity(0), AppTheme.pageBackground],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea()
                        )
                    }
                }
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "home_feed")
            viewModel.startListening()
        }
        .onDisappear { viewModel.stopListening() }
        .fullScreenCover(isPresented: $showCreateStream) {
            CreateStreamView(
                onDismiss: { showCreateStream = false },
                onStreamCreated: { streamId, token, url in
                    showCreateStream = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        streamerItem = StreamIDItem(id: streamId, token: token, url: url)
                    }
                }
            )
        }
        .fullScreenCover(item: $streamerItem) { item in
            StreamerView(
                streamId:     item.id,
                initialToken: item.token,
                initialUrl:   item.url,
                onEnd:        { streamerItem = nil }
            )
        }
        .fullScreenCover(item: $viewerStream) { stream in
            StreamViewerView(stream: stream, onLeave: { viewerStream = nil })
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Color.clear.frame(width: 30, height: 30)
            Spacer()
            Text("Live")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.primaryText)
            Spacer()
            Color.clear.frame(width: 30, height: 30)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Live section
    private var liveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.liveStreams) { stream in
                    LiveStreamCard(stream: stream, isOwnStream: stream.streamerId == currentUserId) {
                        Analytics.shared.trackTap(
                            elementId: "join_stream_card",
                            screenName: "home_feed",
                            properties: [AnalyticsProperty.streamId: stream.id]
                        )
                        if stream.streamerId == currentUserId {
                            streamerItem = StreamIDItem(id: stream.id, token: nil, url: nil)
                        } else {
                            viewerStream = stream
                        }
                    }
                }
            }
        }
    }

    // MARK: - Action buttons
    private var actionButtons: some View {
        Button {
            Analytics.shared.trackTap(elementId: "go_live_button", screenName: "home_feed")
            showCreateStream = true
        } label: {
            Text("GO LIVE")
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(.white)
                .frame(maxWidth: 200)
                .padding(.vertical, 20)
                .background(AppTheme.accent)
                .cornerRadius(200)
        }
    }
}

// MARK: - EarningsTooltipView

struct EarningsTooltipView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Text("$")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(.white)
                Text("Get Paid")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.green)
            .cornerRadius(14)

            TooltipTail()
                .fill(AppTheme.green)
                .frame(width: 14, height: 8)
        }
    }
}

// MARK: - TooltipTail

struct TooltipTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - LiveStreamCard
struct LiveStreamCard: View {
    let stream:      StreamModel
    let isOwnStream: Bool
    let onTap:       () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    ZStack {
                        Rectangle()
                            .fill(AppTheme.cardBackground)
                        ProfilePictureView(url: stream.streamerImageUrl, size: 72)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
                    .clipped()

                    HStack {
                        liveBadge
                        Spacer()
                    }
                    .padding(8)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(stream.streamerName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                        .lineLimit(1)
                    Text(elapsedText)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.secondaryText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    private var liveBadge: some View {
        Text("LIVE")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(AppTheme.danger)
            .cornerRadius(200)
    }

    private var elapsedText: String {
        let mins = stream.elapsedSeconds / 60
        return mins < 1 ? "just started" : "\(mins)m"
    }
}
