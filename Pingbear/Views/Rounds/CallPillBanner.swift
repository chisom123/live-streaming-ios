import SwiftUI

// ─────────────────────────────────────────────────────────────
// MARK: - CallPillBanner
//
// Sits at the top of the app VStack in normal layout flow.
// Pushes content down when active — no overlapping, no
// z-index fights, no UIWindow complexity.
// ─────────────────────────────────────────────────────────────

struct CallPillBanner: View {
    @StateObject private var callManager = VoiceCallManager.shared

    var body: some View {
        if callManager.isConnected || !callManager.participants.isEmpty {
            HStack(spacing: 10) {
                Circle()
                    .fill(AppTheme.green)
                    .frame(width: 8, height: 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(callManager.participants) { participant in
                            speakingAvatar(participant: participant)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
                .frame(maxWidth: .infinity)

                Button(action: {
                    Analytics.shared.trackTap(
                        elementId: callManager.isMuted ? "call_pill_unmute" : "call_pill_mute"
                    )
                    callManager.toggleMute()
                }) {
                    Image(systemName: callManager.isMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 14))
                        .foregroundColor(callManager.isMuted ? .red : AppTheme.primaryText)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.pageBackground)
                        .clipShape(Circle())
                }

                Button(action: {
                    Analytics.shared.trackTap(
                        elementId: "call_pill_leave",
                        properties: ["participant_count": callManager.participants.count]
                    )
                    callManager.leaveCall()
                }) {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AppTheme.cardBackground)
            .cornerRadius(200)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.25), value: callManager.isConnected)
            .padding(.vertical, 6)
        }
    }

    private func speakingAvatar(participant: CallParticipant) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ProfilePictureView(url: participant.profilePictureUrl, size: 28)
                .overlay(
                    Circle()
                        .stroke(
                            participant.isSpeaking ? AppTheme.green : Color.clear,
                            lineWidth: 2
                        )
                )
                .scaleEffect(participant.isSpeaking ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: participant.isSpeaking)

            if participant.isMuted {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 7))
                    .foregroundColor(.white)
                    .frame(width: 12, height: 12)
                    .background(Color.red)
                    .clipShape(Circle())
                    .offset(x: 2, y: 2)
            }
        }
        .padding(3)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - VoiceCallButton
//
// Shown in CompDetails header.
// Shows participant count badge when others are in a call.
// ─────────────────────────────────────────────────────────────

struct VoiceCallButton: View {
    @ObservedObject var callManager: VoiceCallManager = VoiceCallManager.shared
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Image("phone")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(AppTheme.iconColor)
                    .frame(width: 27, height: 27)
                    .frame(width: 45, height: 45)
                    .padding(6)

                if !callManager.participants.isEmpty && !callManager.isConnected {
                    Text("\(callManager.participants.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(AppTheme.green)
                        .clipShape(Circle())
                        .offset(x: 11, y: -11)
                }
            }
        }
    }
}
