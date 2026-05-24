import SwiftUI

struct HowItWorksView: View {

    var onComplete: (() -> Void)? = nil
    @State private var stage: Int = 0
    @State private var hasCompleted = false

    private let buttonLabels = ["Next", "Next", "Let's go!"]

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer()

                Text(captionText)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .animation(.easeInOut(duration: 0.3), value: stage)

                PhoneFrame(stage: $stage)
                    .frame(width: 260, height: 480)
                    .padding(.top, 25)

                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        Capsule()
                            .fill(pipColor(i))
                            .frame(width: stage == i ? 20 : 8, height: 4)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: stage)
                    }
                }
                .padding(.top, 25)

                Spacer()

                Button(action: advance) {
                    Text(buttonLabels[stage])
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(AppTheme.accent)
                        .cornerRadius(200)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
            .animation(.easeInOut(duration: 0.4), value: stage)
        }
        .navigationBarHidden(true)
        .onAppear {
            Analytics.shared.trackScreen(name: "how_it_works")
        }
    }

    private var captionText: String {
        switch stage {
        case 0: return "Everyone submits a photo"
        case 1: return "AI judges every photo"
        case 2: return "Best photo wins the prize"
        default: return ""
        }
    }

    private func pipColor(_ index: Int) -> Color {
        if index < stage { return AppTheme.divider }
        if index == stage { return AppTheme.accent }
        return AppTheme.divider.opacity(0.5)
    }

    private func advance() {
        Analytics.shared.trackTap(
            elementId: "how_it_works_step_\(stage + 1)",
            screenName: "how_it_works"
        )
        if stage < 2 {
            withAnimation { stage += 1 }
        } else {
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        guard !hasCompleted else { return }
        hasCompleted = true
        Analytics.shared.track(event: "how_it_works_completed")
        if let onComplete {
            onComplete()
        } else {
            UserDefaults.standard.set(true, forKey: "isLoggedIn")
            UserDefaults.standard.set(true, forKey: "isFriendActivated")
            UserDefaults.standard.synchronize()
            NotificationCenter.default.post(name: .authStateDidChange, object: nil)
        }
    }
}

private struct PhoneFrame: View {

    @Binding var stage: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36)
                .fill(AppTheme.pageBackground)

            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.black.opacity(0.07), lineWidth: 10)
                .padding(6)

            ClipShape(cornerRadius: 30) {
                ZStack {
                    AppTheme.pageBackground

                    LobbyStage()
                        .opacity(stage == 0 ? 1 : 0)

                    JudgingStage()
                        .opacity(stage == 1 ? 1 : 0)

                    ResultsStage(active: stage == 2)
                        .opacity(stage == 2 ? 1 : 0)
                }
            }
            .padding(6)
        }
    }
}

private struct ClipShape<Content: View>: View {
    let cornerRadius: CGFloat
    let content: () -> Content

    var body: some View {
        content()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

private struct LobbyStage: View {

    private let fakeNames = ["You", "Sofia", "Jake", "Ella"]

    var body: some View {
        VStack(spacing: 0) {

            HStack(spacing: 8) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.iconColor)

                HStack(spacing: 5) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.primaryText)
                    Text("Outfit")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                    Spacer()
                    Text("$4.00")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppTheme.green)
                        .clipShape(Capsule())
                }
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(AppTheme.cardBackground)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 8)
            .background(AppTheme.pageBackground)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
                spacing: 6
            ) {
                ForEach(0..<4) { i in
                    ZStack(alignment: .topLeading) {
                        Image("outfit\(i + 1)")
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 130)
                            .clipped()

                        Text(fakeNames[i])
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.top, 6)

                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("$1.00")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.green)
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 7)
                            .padding(.bottom, 6)
                        }
                    }
                    .frame(height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 10)
            .background(AppTheme.pageBackground)

            Text("4 players ready")
                .font(.system(size: 10))
                .foregroundColor(AppTheme.secondaryText)
                .padding(.top, 8)
                .padding(.vertical, 5)
                .background(AppTheme.pageBackground)

            Spacer()

            HStack {
                Text("Leave")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.secondaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.cardBackground)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.divider, lineWidth: 1))

                Spacer()

                Text("Start Round")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(AppTheme.accent)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
            .background(AppTheme.pageBackground)
        }
        .background(AppTheme.pageBackground)
    }
}

private struct JudgingStage: View {

    @State private var dotPhase = 0
    private let dotTimer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AppTheme.accent.ignoresSafeArea()

            VStack(spacing: 20) {

                Spacer()

                ZStack {
                    ForEach(0..<3) { i in
                        SonarRing(delay: Double(i) * 0.93)
                    }
                    Circle()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 48, height: 48)
                }
                .frame(width: 130, height: 130)

                VStack(spacing: 8) {
                    Text("AI is judging")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Outfit")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    HStack(spacing: 5) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(dotPhase == i ? Color.white : Color.white.opacity(0.25))
                                .frame(width: 5, height: 5)
                                .scaleEffect(dotPhase == i ? 1.3 : 0.8)
                                .animation(.easeInOut(duration: 0.2), value: dotPhase)
                        }
                    }
                }

                Spacer()
                Spacer()
            }
        }
        .onReceive(dotTimer) { _ in dotPhase = (dotPhase + 1) % 3 }
    }
}

private struct SonarRing: View {

    let delay: Double
    @State private var animating = false

    var body: some View {
        Circle()
            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
            .frame(width: 130, height: 130)
            .scaleEffect(animating ? 1.2 : 0.3)
            .opacity(animating ? 0 : 0.7)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeOut(duration: 2.8).repeatForever(autoreverses: false)) {
                        animating = true
                    }
                }
            }
    }
}

private struct ResultsStage: View {

    let active: Bool

    @State private var scores: [Double] = [8.4, 7.1, 5.2]

    private let targetScores: [Double] = [8.4, 7.1, 5.2]
    private let names   = ["You", "Sofia", "Jake"]
    private let reasons = ["Effortless fit, the accessories make it", "Casual and cool, sneakers tie it together", "Decent jacket but the pizza's stealing the show"]

    var body: some View {
        VStack(spacing: 0) {

            VStack(spacing: 6) {
                Text("You won!")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(AppTheme.primaryText)
                Text("+$3.60")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(AppTheme.green)
                    .clipShape(Capsule())
                Text("Platform fee (10%)")
                    .font(.system(size: 9))
                    .foregroundColor(AppTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.top)
            .background(AppTheme.pageBackground)

            VStack(spacing: 6) {
                ForEach(0..<3) { i in
                    HStack(spacing: 6) {
                        Text("\(i + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(i == 0 ? AppTheme.gold : AppTheme.secondaryText)
                            .frame(width: 16)

                        HStack(spacing: 8) {
                            Image("outfit\(i + 1)")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 46, height: 58)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(names[i])
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(AppTheme.primaryText)
                                Text(reasons[i])
                                    .font(.system(size: 9))
                                    .foregroundColor(AppTheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            VStack(spacing: 0) {
                                Text(String(format: "%.1f", scores[i]))
                                    .font(.system(size: 17, weight: .black))
                                    .foregroundColor(i == 0 ? AppTheme.gold : AppTheme.primaryText)
                                Text("/ 9.9")
                                    .font(.system(size: 9))
                                    .foregroundColor(AppTheme.secondaryText)
                            }
                        }
                        .padding(8)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            Spacer()

            Text("Play Again")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AppTheme.accent)
                .clipShape(Capsule())
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .background(AppTheme.pageBackground)
    }
}
