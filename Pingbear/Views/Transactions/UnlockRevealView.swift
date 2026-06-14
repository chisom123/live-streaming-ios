import SwiftUI
import FirebaseAuth
import FirebaseFunctions

// ─────────────────────────────────────────────────────────────
// MARK: - UnlockRevealView
// The centrepiece of the app — mystery box reveal
// ─────────────────────────────────────────────────────────────

struct UnlockRevealView: View {

    let enriched:   EnrichedContentTransaction
    let onComplete: () -> Void

    @State private var phase:          RevealPhase = .confirm
    @State private var isUnlocking     = false
    @State private var errorMessage:   String?     = nil
    @State private var photoUrl:       String?     = nil
    @State private var imageOpacity:   Double      = 0
    @State private var scaleEffect:    Double      = 0.85

    private let functions     = Functions.functions()
    private let currentUserId = Auth.auth().currentUser?.uid ?? ""

    private var tx: ContentTransaction { enriched.transaction }
    private var otherName: String { enriched.otherProfile?.name ?? "Someone" }

    enum RevealPhase {
        case confirm    // show price, confirm payment
        case unlocking  // animation while calling backend
        case revealed   // show the photo
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch phase {
            case .confirm:
                confirmView
            case .unlocking:
                unlockingView
            case .revealed:
                revealedView
            }
        }
        .ignoresSafeArea()
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Confirm
    // ─────────────────────────────────────────────────────────

    private var confirmView: some View {
        VStack(spacing: 0) {
            // Mystery blurred placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 0)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#FF6B00").opacity(0.3),
                                Color(hex: "#FF6B00").opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.height * 0.55)

                VStack(spacing: 16) {
                    Text("🎁")
                        .font(.system(size: 72))
                    Text("Mystery photo from\n\(otherName)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text(tx.description)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Text("Unlock for $\(String(format: "%.2f", tx.price))")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                }

                Button {
                    Task { await unlock() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 18))
                        Text("Unlock Now")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(AppTheme.accent)
                    .cornerRadius(200)
                    .padding(.horizontal, 24)
                }

                Button(action: onComplete) {
                    Text("Maybe later")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.bottom, 60)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Unlocking animation
    // ─────────────────────────────────────────────────────────

    private var unlockingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 48))
                    .foregroundColor(AppTheme.accent)
            }
            .scaleEffect(scaleEffect)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.6).repeatForever(autoreverses: true),
                value: scaleEffect
            )

            Text("Unlocking...")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Spacer()
        }
        .onAppear {
            scaleEffect = 1.1
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Revealed
    // ─────────────────────────────────────────────────────────

    private var revealedView: some View {
        ZStack {
            if let photoUrl {
                AsyncImage(url: URL(string: photoUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .ignoresSafeArea()
                } placeholder: {
                    ProgressView().tint(.white)
                }
                .opacity(imageOpacity)
                .animation(.easeIn(duration: 0.6), value: imageOpacity)
            }

            // Gradient overlay
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 280)
            }
            .ignoresSafeArea()

            // Bottom actions
            VStack {
                Spacer()
                VStack(spacing: 16) {
                    Text("✨ Revealed!")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.white)

                    Text("How was it?")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))

                    Button(action: onComplete) {
                        Text("Rate & Close")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.accent)
                            .cornerRadius(200)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            // Slight delay for drama
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                imageOpacity = 1
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Unlock action
    // ─────────────────────────────────────────────────────────

    private func unlock() async {
        isUnlocking = true
        withAnimation { phase = .unlocking }

        do {
            let result = try await functions.httpsCallable("unlockContent").call([
                "transactionId": tx.id
            ])

            guard let data    = result.data as? [String: Any],
                  let url     = data["photoUrl"] as? String else {
                throw NSError(domain: "SocialStar", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Could not retrieve photo"])
            }

            await MainActor.run {
                photoUrl = url
                isUnlocking = false
                Analytics.shared.track(
                    event: AnalyticsEvent.contentUnlocked,
                    properties: [
                        AnalyticsProperty.transactionId: tx.id,
                        AnalyticsProperty.transactionType: tx.type.rawValue,
                        AnalyticsProperty.amount: tx.price
                    ]
                )
                withAnimation { phase = .revealed }
            }
        } catch {
            await MainActor.run {
                isUnlocking = false
                errorMessage = error.localizedDescription
                withAnimation { phase = .confirm }
            }
        }
    }
}
