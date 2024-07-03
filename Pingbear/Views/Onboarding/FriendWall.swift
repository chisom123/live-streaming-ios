import SwiftUI
import NotificationBannerSwift
import PostHog

struct FriendWall: View {
    @State private var searchText = "" // State variable to hold search text
    @State private var username: String = ""
    @State private var goHome = false
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var viewModel: MyFriendsModel // Add this line
    @ObservedObject var viewModel2: AddFriendsModel

    func processUsername(_ username: String) -> String {
        return username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    
    var body: some View {
        VStack {
            
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .resizable() // Allows resizing of the image
                        .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                        .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                        .foregroundColor(Color.black) // Your desired color
                }
                
                Spacer()
                
                Text("Add Friends")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    .padding(.horizontal)
                    .onAppear {
                        PostHogSDK.shared.capture("Friend Wall View Opened")
                    }
                
                Spacer()
                
                Button("Skip") {
                    goHome = true
                    PostHogSDK.shared.capture("Skip button Pressed (Friend Wall)")
                }
                .font(.system(size: 15.5, weight: .bold, design: .default))
                .foregroundColor(Color.gray)
            }
            .padding(.horizontal, 5)
            .padding()
            
            HStack(alignment: .center, spacing: 10) {
                TextField("Enter Friend's Username", text: $username)
                    .padding()
                    .padding(.vertical, 5)
                    .background(Color(hex: "#F5F5F5"))
                    .foregroundColor(Color(hex: "#000"))
                    .cornerRadius(10)
                    .font(.system(size: 16, weight: .bold, design: .default))
                
                Button(action: {
                    let processedUsername = processUsername(username)
                    viewModel2.addFriend(byUsername: processedUsername) { (success, error) in
                        if success {
                            viewModel.fetchFriends()
                            let banner = NotificationBanner(title: "Friend Added", style: .success)
                            banner.show()
                            username = ""
                            PostHogSDK.shared.capture("Friend Added", properties: ["friend_username": processedUsername])
                        } else {
                            let banner = NotificationBanner(title: "Failed to Add Friend", style: .danger)
                            banner.show()
                        }
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .padding()
                        .padding(.vertical, 5)
                        .background(Color(hex: "#1199FF"))
                        .foregroundColor(Color(hex: "#fff"))
                        .cornerRadius(10)
                }
            }
            .padding()
            
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(Array(viewModel.friends.enumerated()), id: \.element.id) { index, friend in
                        HStack {
                            Text(friend.name) // Assuming 'friend' has a 'name' property
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundColor(.black)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 25)
                        .padding(.horizontal, 25)
                        .background(Color(hex: "#F5F5F5"))
                        .cornerRadius(5)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
            }
            
            Spacer() // Pushes everything to the top
            
            if !viewModel.friends.isEmpty {
                Button(action: {
                    goHome = true
                    PostHogSDK.shared.capture("Friend Wall Continue Pressed")
                }) {
                    Text("Continue")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(Color(hex: "#1199FF")) // Change button
                        .foregroundColor(Color(hex: "#fff"))
                        .cornerRadius(200)
                }
                .padding(.top, 10)
                .padding(.bottom, 10)
                .padding(.horizontal)
            }
        }
        .onAppear {
            viewModel.fetchFriends()
        }
        .fullScreenCover(isPresented: $goHome, content: {
            ContentView()
        })
    }
}
