import SwiftUI
import PostHog

struct ContactInfoView: View {
    @State private var navigateToFriend = false
    
    var body: some View {
        VStack {
            
            Spacer()
            
            Image("Notifications")
                .resizable()
                .aspectRatio(contentMode: .fit) // Maintain aspect ratio
                .frame(maxWidth: 200)
                .onAppear {
                    PostHogSDK.shared.capture("Welcome View Opened")
                }
            
            Text("Turn on notifications")
                .font(.system(size: 25, weight: .bold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(.black)
                .padding(.top, 50)
                .padding(.bottom, 25)
                .padding(.horizontal)
            
            
            Text("Get notified when your friends share videos and give you stars.")
                .font(.system(size: 16, weight: .bold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(.gray)
                .padding(.horizontal, 25)
            
            Spacer()
            
            Button(action: {
                navigateToFriend = true
            }) {
                Text("Continue")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .background(Color(hex: "#1199FF")) // Change button
                    .foregroundColor(Color(hex: "#fff"))
                    .cornerRadius(200)
            }
            .padding(.top, 15)
            .padding(.bottom, 20)
            .padding(.horizontal)
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $navigateToFriend) {
            ContentView()
        }
    }
}
