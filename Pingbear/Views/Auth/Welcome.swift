import SwiftUI

struct WelcomeView: View {
    @State private var showPhoneEntry = false
    // Use a StateObject for the animation controller to ensure continuous animation
    @StateObject private var animationController = AnimationController()
    
    var body: some View {
        ZStack {
            // Background with animated elements
            Color(hex: "#10183C")
                .edgesIgnoringSafeArea(.all)
            
            // Animated background elements
            ZStack {
                // Animated light beams
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 100)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "#32CD32").opacity(0.3),
                                    Color(hex: "#3B4374").opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 300, height: 300)
                        .rotationEffect(.degrees(Double(index * 45) + animationController.rotationAngle))
                        .offset(x: CGFloat(index * 40) - 100, y: CGFloat(index * 20) - 200)
                        .blur(radius: 70)
                }
                
                // Glowing orbs with smooth sine wave animations
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#32CD32").opacity(0.4),
                                Color(hex: "#10183C").opacity(0)
                            ]),
                            center: .center,
                            startRadius: 50,
                            endRadius: 200
                        )
                    )
                    .scaleEffect(1.0 + sin(animationController.sineWaveValue) * 0.3)
                    .position(x: UIScreen.main.bounds.width * 0.8,
                             y: UIScreen.main.bounds.height * 0.2)
                    .blur(radius: 40)
                
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#3B4374").opacity(0.4),
                                Color(hex: "#10183C").opacity(0)
                            ]),
                            center: .center,
                            startRadius: 50,
                            endRadius: 200
                        )
                    )
                    .scaleEffect(1.0 + cos(animationController.sineWaveValue) * 0.3)
                    .position(x: UIScreen.main.bounds.width * 0.2,
                             y: UIScreen.main.bounds.height * 0.7)
                    .blur(radius: 40)
            }
            .onAppear {
                // Start the continuous animations
                animationController.startAnimations()
            }
            
            // Content
            VStack(spacing: 0) {
                Spacer()
                
                // Logo
                Image("Logo-T")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 70, height: 70)
                    .shadow(color: Color(hex: "#32CD32").opacity(0.5), radius: 15, x: 0, y: 0)
                
                // Title and tagline
                Text("Welcome to SocialStar")
                    .font(.system(size: 30, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .padding(.top, 30)
                
                Text("Social Competition with Friends")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.8))
                    .padding(.top, 15)
                
                Spacer()
                
                // Disclaimer
                DisclaimerText()
                
                // CTA Button
                Button(action: {
                    Analytics.shared.trackTap (
                        elementId: "welcome_cta",
                        screenName: "welcome"
                    )
                    showPhoneEntry = true
                }) {
                    Text("Agree & Continue")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color(hex: "#32CD32"))
                        .cornerRadius(200)
                }
                .padding(.horizontal, 25)
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 20)
            .onAppear {
                Analytics.shared.trackScreen(name: "welcome")
            }
            
            NavigationLink(destination: PhoneEntryView(), isActive: $showPhoneEntry) {
                EmptyView()
            }.isDetailLink(false)
        }
    }
}

// Animation controller to manage smooth continuous animations
class AnimationController: ObservableObject {
    @Published var rotationAngle: Double = 0
    @Published var sineWaveValue: Double = 0
    
    private var rotationTimer: Timer?
    private var sineWaveTimer: Timer?
    
    func startAnimations() {
        // Create timer for rotation at 60fps
        rotationTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Increment by small amount for smooth rotation (full 360° rotation in 8 seconds)
            self.rotationAngle = (self.rotationAngle + 0.75) .truncatingRemainder(dividingBy: 360)
        }
        
        // Create timer for sine wave animation at 60fps
        sineWaveTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Small increment for smooth sine wave (completes a cycle in about 4 seconds)
            self.sineWaveValue = (self.sineWaveValue + 0.025) .truncatingRemainder(dividingBy: 2 * Double.pi)
        }
    }
    
    deinit {
        rotationTimer?.invalidate()
        sineWaveTimer?.invalidate()
    }
}

struct DisclaimerText: View {
    var body: some View {
        VStack {
            let readOurText = Text("Read our ")
            let privacyText = Text("Privacy Policy").underline()
            let andText = Text(" and Tap \"Agree & Continue\" to accept the ")
            let termsText = Text("Terms of Use (EULA)").underline()
            
            (readOurText + privacyText + andText + termsText)
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundColor(.white)
                .padding(.bottom, 30)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }
}
