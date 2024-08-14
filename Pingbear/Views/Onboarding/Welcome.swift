import SwiftUI
import PostHog

struct DotIndicatorView: View {
    var currentIndex: Int
    var totalDots: Int = 3
    
    var body: some View {
        HStack {
            ForEach(0..<totalDots, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.blue : Color(hex: "#D3D3D3"))
                    .frame(width: 8, height: 8)
                    .padding(.horizontal, 4)
            }
        }
    }
}

struct WelcomeView: View {
    @State private var navigateToPhoneEntry = false
    @State private var currentStep = 0
    
    let steps = [
        ("Screenshot1", "Share Videos with Your Friends"),
        ("Screenshot", "Your Friends Rate Your Videos"),
        ("Screenshot2", "See Where Your Videos Rank")
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Spacer()
                    
                    Button("Skip") {
                        navigateToPhoneEntry = true
                        PostHogSDK.shared.capture("Skip Button Pressed (Welcome View)")
                    }
                    .font(.system(size: 15.5, weight: .bold, design: .default))
                    .foregroundColor(Color(hex: "#A9A9A9"))
                }
                .padding(.horizontal, 25)
                .padding(.vertical)
                
                Image(steps[currentStep].0)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.top, 5)
                    .onAppear {
                        PostHogSDK.shared.capture("Welcome View Opened")
                    }
                
                Text(steps[currentStep].1)
                    .font(.system(size: 25, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.top, 40)
                    .padding(.bottom, 30)
                    .padding(.horizontal, 25)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                DotIndicatorView(currentIndex: currentStep)

                Button(action: {
                    if currentStep < steps.count - 1 {
                        currentStep += 1
                    } else {
                        navigateToPhoneEntry = true
                    }
                    PostHogSDK.shared.capture("Continue Button Pressed (Welcome View)")
                }) {
                    Text("Continue")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(Color(hex: "#1199FF"))
                        .foregroundColor(Color(hex: "#fff"))
                        .cornerRadius(200)
                }
                .padding(.top, 30)
                .padding(.bottom, 20)
                .padding(.horizontal)
            }
            .navigationBarHidden(true)
            .background(
                NavigationLink(
                    destination: PhoneEntryView(),
                    isActive: $navigateToPhoneEntry,
                    label: { EmptyView() }
                )
            )
        }
        .accentColor(.black)
    }
}
