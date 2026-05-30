import SwiftUI
import FirebaseAuth
import FirebaseFunctions

struct HomeView: View {

    @StateObject private var viewModel = FriendsViewModel()
    @StateObject private var callManager = VoiceCallManager.shared

    @State private var selectedFriendIds: Set<String> = []
    @State private var showingAddFriends = false

    @State private var activeSessionId:  String? = nil
    @State private var callingSessionId: String? = nil
    @State private var calledFriends:    [Friend] = []

    var body: some View {
        ZStack {
            // ── Home content ──────────────────────────────────
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    navBar

                    if viewModel.isLoading {
                        Spacer()
                        ProgressView().tint(AppTheme.primaryText)
                        Spacer()
                    } else if viewModel.friends.isEmpty {
                        emptyState
                    } else {
                        friendsList
                    }

                    if !selectedFriendIds.isEmpty {
                        callButton
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }

        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedFriendIds.isEmpty)
        .navigationBarHidden(true)
        .onAppear {
            viewModel.fetchFriends()
            Analytics.shared.trackScreen(name: "home")
        }
        .fullScreenCover(isPresented: $showingAddFriends, onDismiss: {
            viewModel.fetchFriends()
        }) {
            AddFriendsView(addFriendsModel: AddFriendsModel())
        }

        // ── Calling screen — shown while friends' phones ring ──
        .fullScreenCover(item: Binding(
            get: { callingSessionId.map { SessionItem(id: $0) } },
            set: { if $0 == nil { callingSessionId = nil } }
        )) { item in
            CallingView(
                sessionId: item.id,
                calledFriends: calledFriends,
                onFirstAnswer: {
                    // First person answered — move to full session lobby
                    callingSessionId = nil
                    activeSessionId  = item.id
                },
                onCancel: {
                    // End CallKit call so UUID is cleaned up for next call
                    CallKitManager.shared.endActiveCall(reason: .remoteEnded)
                    // Stop ringing on all invited friends' phones
                    Functions.functions().httpsCallable("sendCallEnded").call([
                        "sessionId": item.id,
                        "friendIds": calledFriends.map { $0.id }
                    ]) { _, _ in }
                    // End session and disconnect LiveKit
                    Functions.functions().httpsCallable("endSession").call(
                        ["sessionId": item.id]
                    ) { _, _ in }
                    VoiceCallManager.shared.leaveCall()
                    callingSessionId = nil
                    calledFriends    = []
                }
            )
        }
        // ── Session lobby — shown after first person answers ──
        .fullScreenCover(item: Binding(
            get: { activeSessionId.map { SessionItem(id: $0) } },
            set: { if $0 == nil { activeSessionId = nil } }
        )) { item in
            SessionView(sessionId: item.id)
        }
        .onChange(of: callManager.callState) { state in
            AppLogger.nav("[HomeView] callState → \(state) currentSessionId=\(callManager.currentSessionId ?? "nil") activeSessionId=\(activeSessionId ?? "nil") callingSessionId=\(callingSessionId ?? "nil")")
            if state == .connected, let sessionId = callManager.currentSessionId {
                if activeSessionId == nil && callingSessionId == nil {
                    AppLogger.nav("[HomeView] incoming call → opening SessionView sessionId=\(sessionId)")
                    activeSessionId = sessionId
                } else {
                    AppLogger.nav("[HomeView] .connected — CallingView handling transition")
                }
            }
            if state == .idle {
                print("HomeView: 🔴 .idle received — clearing all session state")
                activeSessionId  = nil
                callingSessionId = nil
                calledFriends    = []
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Nav Bar
    // ─────────────────────────────────────────────────────────

    private var navBar: some View {
        HStack {
            #if DEBUG
            DebugSessionButton()
            #else
            Color.clear.frame(width: 25, height: 25)
            #endif

            Spacer()

            Text("Friends")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.primaryText)

            Spacer()

            Button(action: {
                Analytics.shared.trackTap(elementId: "add_friends", screenName: "home")
                showingAddFriends = true
            }) {
                Image(systemName: "plus")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 25, height: 25)
                    .foregroundColor(AppTheme.iconColor)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Friends List
    // ─────────────────────────────────────────────────────────

    private var friendsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(viewModel.friends) { friend in
                    FriendCell(
                        friend: friend,
                        isSelected: selectedFriendIds.contains(friend.id),
                        onTap: { toggleSelection(friend.id) }
                    )

                    if friend.id != viewModel.friends.last?.id {
                        Divider()
                            .background(AppTheme.divider)
                    }
                }
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(14)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, selectedFriendIds.isEmpty ? 20 : 100)
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Empty State
    // ─────────────────────────────────────────────────────────

    private var emptyState: some View {
        VStack {
            Spacer()

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 28))
                        .foregroundColor(AppTheme.accent)
                }
                .padding(.top, 32)
                .padding(.bottom, 20)

                Text("No friends yet")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
                    .padding(.bottom, 8)

                Text("Add friends to start playing")
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.secondaryText)
                    .padding(.bottom, 28)

                Button(action: { showingAddFriends = true }) {
                    Text("Add Friends")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 200)
                        .padding(.vertical, 14)
                        .background(AppTheme.accent)
                        .cornerRadius(200)
                }
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
            .background(AppTheme.cardBackground)
            .cornerRadius(20)
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Call Button
    // ─────────────────────────────────────────────────────────

    private var callButton: some View {
        HStack(spacing: 12) {
            HStack(spacing: -8) {
                ForEach(Array(selectedFriends.prefix(3))) { friend in
                    ProfilePictureView(url: friend.profilePictureUrl, size: 32)
                        .overlay(Circle().stroke(AppTheme.accent, lineWidth: 2))
                }
            }

            Button(action: startCall) {
                HStack(spacing: 8) {
                    if viewModel.isStartingCall {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text(viewModel.isStartingCall ? "Calling..." : callButtonLabel)
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(viewModel.isStartingCall ? AppTheme.disabledBackground : AppTheme.accent)
                .cornerRadius(200)
            }
            .disabled(viewModel.isStartingCall)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
        .padding(.top, 12)
        .background(
            AppTheme.pageBackground
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: -4)
                .ignoresSafeArea()
        )
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────────────────────────

    private var selectedFriends: [Friend] {
        viewModel.friends.filter { selectedFriendIds.contains($0.id) }
    }

    private var callButtonLabel: String {
        let count = selectedFriendIds.count
        if count == 1 { return "Call \(selectedFriends.first?.name ?? "")" }
        return "Call \(count) Friends"
    }

    private func toggleSelection(_ id: String) {
        if selectedFriendIds.contains(id) {
            selectedFriendIds.remove(id)
        } else {
            selectedFriendIds.insert(id)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func startCall() {
        guard !selectedFriendIds.isEmpty else { return }

        Analytics.shared.trackTap(
            elementId: "start_call",
            screenName: "home",
            properties: ["friend_count": selectedFriendIds.count]
        )

        let friendIds  = Array(selectedFriendIds)
        let friends    = viewModel.friends.filter { selectedFriendIds.contains($0.id) }
        selectedFriendIds = []

        viewModel.startCall(friendIds: friendIds) { sessionId in
            guard let sessionId else { return }
            DispatchQueue.main.async {
                // Show CallingView immediately before joining LiveKit
                // so the user sees the ringing screen straight away
                self.calledFriends    = friends
                self.callingSessionId = sessionId
            }
            VoiceCallManager.shared.joinCall(sessionId: sessionId) { success in
                if !success {
                    DispatchQueue.main.async {
                        self.callingSessionId = nil
                        self.calledFriends    = []
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - FriendCell
// ─────────────────────────────────────────────────────────────

struct FriendCell: View {
    let friend: Friend
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ProfilePictureView(url: friend.profilePictureUrl, size: 44)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? AppTheme.accent : Color.clear, lineWidth: 2.5)
                    )

                Text(friend.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.secondaryText.opacity(0.4))
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? AppTheme.accent.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - SessionItem
// ─────────────────────────────────────────────────────────────

struct SessionItem: Identifiable {
    let id: String
}
