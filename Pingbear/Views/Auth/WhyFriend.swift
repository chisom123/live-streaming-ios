import SwiftUI
import PostHog

struct WhyFriendView: View {
    
    @State private var navigateToUsernameShield = false // Updated for navigation link

    
    var body: some View {
        VStack {
            Text("Oh sorry, you can only rate your friend's pictures")
                .font(.system(size: 20, weight: .bold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(.black)
                .padding(.bottom, 40)
                .padding(.horizontal)
            
            HStack { // Add an HStack with some spacing between the buttons
                Button(action: {
                    navigateToUsernameShield = true
                    PostHogSDK.shared.capture("Username Shield Opened")
                }) {
                    Text("Add Friends")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 17.5, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6))
                        .background(Color(hex: "#1199FF"))
                        .foregroundColor(Color.white)
                        .cornerRadius(200)
                }
            }
            .padding(.top, 10)
            .padding(.horizontal, 10)
            
            
        }
        .padding()
        .fullScreenCover(isPresented: $navigateToUsernameShield) {
            UsernameShieldView(addFriendModel: AddFriendsModel())
        }
    }
}
