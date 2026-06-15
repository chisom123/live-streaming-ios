import SwiftUI

struct WelcomeView: View {
    @State private var showPhoneEntry = false
    @StateObject private var animationController = AnimationController()

    var body: some View {
        ZStack {
            AppTheme.pageBackground.edgesIgnoringSafeArea(.all)

            ZStack {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 100)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [AppTheme.accent.opacity(0.3), AppTheme.cardHighlight.opacity(0.1)]),
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 300, height: 300)
                        .rotationEffect(.degrees(Double(index * 45) + animationController.rotationAngle))
                        .offset(x: CGFloat(index * 40) - 100, y: CGFloat(index * 20) - 200)
                        .blur(radius: 70)
                }
                Circle()
                    .fill(RadialGradient(gradient: Gradient(colors: [AppTheme.accent.opacity(0.4), AppTheme.pageBackground.opacity(0)]),
                        center: .center, startRadius: 50, endRadius: 200))
                    .scaleEffect(1.0 + sin(animationController.sineWaveValue) * 0.3)
                    .position(x: UIScreen.main.bounds.width * 0.8, y: UIScreen.main.bounds.height * 0.2)
                    .blur(radius: 40)
                Circle()
                    .fill(RadialGradient(gradient: Gradient(colors: [AppTheme.cardHighlight.opacity(0.4), AppTheme.pageBackground.opacity(0)]),
                        center: .center, startRadius: 50, endRadius: 200))
                    .scaleEffect(1.0 + cos(animationController.sineWaveValue) * 0.3)
                    .position(x: UIScreen.main.bounds.width * 0.2, y: UIScreen.main.bounds.height * 0.7)
                    .blur(radius: 40)
            }
            .onAppear { animationController.startAnimations() }

            VStack(spacing: 0) {
                
                Image("Logo-T").resizable().aspectRatio(contentMode: .fit).frame(width: 50, height: 50).cornerRadius(2000).padding(.top)
                
                Spacer()
                Text("Welcome to SocialStar")
                    .font(.system(size: 30, weight: .bold, design: .default))
                    .foregroundColor(AppTheme.primaryText).padding(.vertical, 30)
                DisclaimerText()
                Button(action: {
                    Analytics.shared.trackTap(elementId: "welcome_cta", screenName: "welcome")
                    showPhoneEntry = true
                }) {
                    Text("Agree & Continue").font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(AppTheme.accent).cornerRadius(200)
                }
                .padding(.horizontal, 25).padding(.bottom, 30)
                Spacer()
            }
            .padding(.horizontal, 20)
            .onAppear { Analytics.shared.trackScreen(name: "welcome") }

            NavigationLink(destination: PhoneEntryView(), isActive: $showPhoneEntry) { EmptyView() }.isDetailLink(false)
        }
    }
}

class AnimationController: ObservableObject {
    @Published var rotationAngle: Double = 0
    @Published var sineWaveValue: Double = 0
    private var rotationTimer: Timer?
    private var sineWaveTimer: Timer?

    func startAnimations() {
        rotationTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.rotationAngle = (self.rotationAngle + 0.75).truncatingRemainder(dividingBy: 360)
        }
        sineWaveTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.sineWaveValue = (self.sineWaveValue + 0.025).truncatingRemainder(dividingBy: 2 * Double.pi)
        }
    }

    deinit { rotationTimer?.invalidate(); sineWaveTimer?.invalidate() }
}

struct DisclaimerText: View {
    @State private var showingActionSheet = false

    var body: some View {
        VStack {
            let youMustBe18Text = Text("You must be at least 13 years old to use this app. ")
            let byTappingText = Text("By tapping \"Agree & Continue\", you confirm you meet this requirement and accept our ")
            let termsText = Text("Terms of Use").underline()
            let andText = Text(" and ")
            let privacyText = Text("Privacy Policy").underline()
            let periodText = Text(".")
            (youMustBe18Text + byTappingText + termsText + andText + privacyText + periodText)
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundColor(AppTheme.primaryText).padding(.bottom, 30)
                .multilineTextAlignment(.center).lineSpacing(4)
                .onTapGesture { showingActionSheet = true }
                .actionSheet(isPresented: $showingActionSheet) {
                    ActionSheet(title: Text("Choose Document"), message: Text("Which document would you like to view?"),
                        buttons: [
                            .default(Text("Terms of Use")) { openURL("https://www.notion.so/Terms-of-Use-2aaae3bec803804b83c4fa30721168d8") },
                            .default(Text("Privacy Policy")) { openURL("https://www.notion.so/Privacy-Policy-2aaae3bec80380838551eb321015a92f") },
                            .cancel()
                        ])
                }
        }
    }

    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) { UIApplication.shared.open(url) }
    }
}
