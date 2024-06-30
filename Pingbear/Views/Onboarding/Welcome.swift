import SwiftUI
import PostHog

struct WelcomeView: View {
    @State private var navigateToFriend = false
    
    var body: some View {
        VStack {
            
            Image("Screenshot")
                .resizable()
                .aspectRatio(contentMode: .fit) // Maintain aspect ratio
                .padding(.top, 20)
                .onAppear {
                    PostHogSDK.shared.capture("Welcome View Opened")
                }
            
            Text("Rate your friend's videos")
                .font(.system(size: 25, weight: .bold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(.black)
                .padding(.top, 40)
                .padding(.bottom, 30)
                .padding(.horizontal)

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
            .padding(.top, 20)
            .padding(.bottom, 20)
            .padding(.horizontal)
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $navigateToFriend) {
            FriendWall(viewModel: MyFriendsModel(), viewModel2: AddFriendsModel()) // Replace this with the actual view you want to present
        }
    }
}
