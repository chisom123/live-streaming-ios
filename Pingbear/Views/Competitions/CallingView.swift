import SwiftUI
import FirebaseAuth

struct CallingView: View {

    let sessionId: String
    let calledFriends: [Friend]
    let onFirstAnswer: () -> Void
    let onCancel: () -> Void

    @StateObject private var callManager = VoiceCallManager.shared
    @State private var elapsed: Int  = 0
    @State private var timer: Timer? = nil
    @State private var pulsing       = false

    private let timeout = 45

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                avatarStack
                    .padding(.bottom, 32)

                Text(statusText)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
                    .padding(.bottom, 8)

                Text("Ringing...")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.secondaryText)

                Spacer()

                Button(action: {
                    Analytics.shared.trackTap(
                        elementId: "cancel_call",
                        screenName: "calling",
                        properties: [
                            "elapsed_seconds": elapsed,
                            "friend_count": calledFriends.count
                        ]
                    )
                    stopTimer()
                    onCancel()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 16))
                        Text("Cancel")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .cornerRadius(200)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "calling", properties: [
                "friend_count": calledFriends.count,
                "session_id": sessionId
            ])
            pulsing = true
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        // Transition to lobby when first remote participant joins
        .onChange(of: callManager.callState) { state in
            AppLogger.call("[CallingView] callState → \(state)")
        }
        .onChange(of: callManager.participants.count) { count in
            AppLogger.call("[CallingView] participants=\(count) callState=\(callManager.callState)")
            if count > 1 {
                AppLogger.call("[CallingView] first answer → transitioning to lobby ✅")
                Analytics.shared.track(event: "call_answered", properties: [
                    "session_id": sessionId,
                    "elapsed_seconds": elapsed,
                    "friend_count": calledFriends.count
                ])
                stopTimer()
                onFirstAnswer()
            }
        }
        .onDisappear {
            AppLogger.nav("[CallingView] disappeared — callState=\(callManager.callState) participants=\(callManager.participants.count)")
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Avatar Stack
    // ─────────────────────────────────────────────────────────

    private var avatarStack: some View {
        Group {
            if calledFriends.count == 1 {
                singleAvatar(calledFriends[0])
            } else {
                HStack(spacing: -16) {
                    ForEach(calledFriends.prefix(4)) { friend in
                        ProfilePictureView(url: friend.profilePictureUrl, size: 64)
                            .overlay(Circle().stroke(AppTheme.pageBackground, lineWidth: 3))
                    }
                    if calledFriends.count > 4 {
                        ZStack {
                            Circle()
                                .fill(AppTheme.cardBackground)
                                .frame(width: 64, height: 64)
                                .overlay(Circle().stroke(AppTheme.pageBackground, lineWidth: 3))
                            Text("+\(calledFriends.count - 4)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppTheme.primaryText)
                        }
                    }
                }
            }
        }
    }

    private func singleAvatar(_ friend: Friend) -> some View {
        ZStack {
            Circle()
                .stroke(AppTheme.accent.opacity(0.2), lineWidth: 2)
                .frame(width: 110, height: 110)
                .scaleEffect(pulsing ? 1.3 : 1.0)
                .opacity(pulsing ? 0.0 : 1.0)
                .animation(
                    .easeInOut(duration: 1.4).repeatForever(autoreverses: false),
                    value: pulsing
                )

            Circle()
                .stroke(AppTheme.accent.opacity(0.35), lineWidth: 2)
                .frame(width: 90, height: 90)
                .scaleEffect(pulsing ? 1.2 : 1.0)
                .opacity(pulsing ? 0.0 : 1.0)
                .animation(
                    .easeInOut(duration: 1.4).repeatForever(autoreverses: false).delay(0.3),
                    value: pulsing
                )

            ProfilePictureView(url: friend.profilePictureUrl, size: 80)
                .overlay(Circle().stroke(AppTheme.accent.opacity(0.6), lineWidth: 2.5))
        }
    }

    private var statusText: String {
        if calledFriends.count == 1 {
            return "Calling \(calledFriends[0].name)"
        }
        return "Calling \(calledFriends.count) friends"
    }

    private func startTimer() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsed += 1
            if elapsed % 2 == 0 {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            if elapsed >= timeout {
                AppLogger.call("[CallingView] no answer after \(timeout)s — cancelling")
                Analytics.shared.track(event: "call_timed_out", properties: [
                    "session_id": sessionId,
                    "friend_count": calledFriends.count,
                    "timeout_seconds": timeout
                ])
                stopTimer()
                onCancel()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
