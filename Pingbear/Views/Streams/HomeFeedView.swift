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
                    ScrollView {
                        VStack(spacing: 20) {
                            if viewModel.liveStreams.isEmpty {
                                emptyState
                            } else {
                                liveSection
                            }
                            actionButtons
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
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
            Text("Live")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(AppTheme.primaryText)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Live section
    private var liveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Live now")
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
            HStack(spacing: 8) {
                Image(systemName: "video.fill").font(.system(size: 16))
                Text("Go Live").font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(AppTheme.accent).cornerRadius(200)
        }
        .padding(.top, 8)
    }

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.system(size: 44))
                .foregroundColor(AppTheme.secondaryText)
            VStack(spacing: 6) {
                Text("No one's live right now")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
                Text("Go live yourself, or ask a friend to stream")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(AppTheme.secondaryText)
            .textCase(.uppercase)
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
                        viewerPill
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

    private var viewerPill: some View {
        HStack(spacing: 3) {
            Image(systemName: "eye")
                .font(.system(size: 9))
                .foregroundColor(.white)
            Text("\(max(0, stream.viewerIds.count - 1))")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.5))
        .cornerRadius(200)
    }

    private var elapsedText: String {
        let mins = stream.elapsedSeconds / 60
        return mins < 1 ? "just started" : "\(mins)m"
    }
}
