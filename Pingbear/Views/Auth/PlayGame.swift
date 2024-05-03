import SwiftUI
import PostHog

struct PlayGameView: View {
    @State private var navigateToNextView = false
    
    var body: some View {
        VStack {
            Spacer()
            
            ZStack {
                // Star with rotation animation
                Image(systemName: "star.fill")
                    .font(.system(size: 55, weight: .bold, design: .default))
                    .foregroundColor(Color(hex: "#FF4500"))
            }
            .padding()
            
            
            Button(action: {
                navigateToNextView = true
                PostHogSDK.shared.capture("Start new Game Button Pressed")
            }) {
                Text("Start Game!")
            }
            .buttonStyle(ChunkyButton())
            .padding(.top, 50)
            .padding(.horizontal)
            
            
            Spacer()
            
        }
        .fullScreenCover(isPresented: $navigateToNextView) {
            DemoView()
        }
        .padding()
        .navigationBarBackButtonHidden(true)
        .background(Color(hex: "#FFD700")) 
    }
    
    struct ChunkyButton: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    ZStack{
                        if #available(iOS 17.0, *) {
                            Capsule()
                                .fill(.blue)
                                .stroke(.black, lineWidth:3)
                                .offset(y:configuration.isPressed ? 0 : 10)
                        } else {
                            Capsule()
                                .fill(Color.blue)
                                .overlay(
                                    Capsule().stroke(Color.black, lineWidth: 3)
                                        .offset(y:configuration.isPressed ? 0 : 10)
                                )
                        }
                        
                        if #available(iOS 17.0, *) {
                            Capsule()
                                .fill(.white)
                                .stroke(.black, lineWidth:3)
                        } else {
                            Capsule()
                                .fill(Color.white)
                                .overlay(
                                    Capsule().stroke(Color.black, lineWidth: 3)
                                )
                        }
                    }
                )
                .offset(y:configuration.isPressed ? 10 : 0)
        }
    }
}
