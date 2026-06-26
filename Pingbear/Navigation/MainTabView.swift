import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct MainTabView: View {
    @Binding var selectedTab: Int

    @EnvironmentObject private var coordinator: NavigationCoordinator

    // VoIP navigation state lives here — always active regardless of tab
    @State private var voipViewerStream: StreamModel?  = nil
    @State private var voipStreamerItem: StreamIDItem? = nil

    private let currentUserId = Auth.auth().currentUser?.uid ?? ""
    private let db = Firestore.firestore()

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                TabView(selection: $selectedTab) {
                    HomeFeedView()
                        .tag(0)

                    WalletView()
                        .tag(1)

                    SettingsView()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .id(selectedTab)

                CustomTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom - 15, 0))
                    .background(AppTheme.pageBackground)
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
        .background(AppTheme.pageBackground)

        // ── VoIP deep-link handler ────────────────────────────────
        // Placed here so it fires regardless of which tab is active.
        // HomeFeedView no longer needs its own onChange handler.
        .onChange(of: coordinator.pendingVoIPStream) { target in
            guard let target else { return }
            coordinator.pendingVoIPStream = nil
            Task { await openStreamFromVoIP(target) }
        }

        // Opens StreamViewerView via VoIP accept
        .fullScreenCover(item: $voipViewerStream) { stream in
            StreamViewerView(stream: stream, onLeave: { voipViewerStream = nil })
        }

        // Opens StreamerView if the accepting user is the streamer (edge case)
        .fullScreenCover(item: $voipStreamerItem) { item in
            StreamerView(
                streamId:     item.id,
                initialToken: item.token,
                initialUrl:   item.url,
                onEnd:        { voipStreamerItem = nil }
            )
        }
    }

    // MARK: - VoIP navigation
    private func openStreamFromVoIP(_ target: VoIPStreamTarget) async {
        if target.streamerId == currentUserId {
            voipStreamerItem = StreamIDItem(id: target.streamId, token: nil, url: nil)
            return
        }
        do {
            let doc = try await db.collection("streams").document(target.streamId).getDocument()
            if let stream = StreamModel.from(doc), stream.isLive {
                // Switch to the Live tab so the user lands in the right context
                await MainActor.run { selectedTab = 0 }
                voipViewerStream = stream
            }
        } catch {
            print("[MainTabView] VoIP stream fetch failed: \(error)")
        }
    }
}
