import SwiftUI
import PostHog

struct MyFriendsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: MyFriendsModel
    @State private var showActionSheet: Bool = false
    @State private var friendToManage: String? = nil
    
    var body: some View {
        ZStack {
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
                    
                    Text("My Friends")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(.black)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    Button(action: {
                 
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable() // Allows resizing of the image
                            .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                            .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                            .foregroundColor(Color.black) // Your desired color
                            .opacity(0)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)

                ScrollView {
                    VStack(spacing: 25) {
                        ForEach(viewModel.friends, id: \.id) { friend in
                            Button(action: {
                                self.friendToManage = friend.id
                                self.showActionSheet = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 18) {
                                        Text(friend.name)
                                            .font(.system(size: 16, weight: .bold, design: .default))
                                            .foregroundColor(.black)
                                    }
                                    Spacer()
                                    
                                    Text("Options")
                                        .font(.system(size: 16, weight: .bold, design: .default))
                                        .foregroundColor(Color(hex: "#1199FF"))
                                }
                                .padding(.vertical, 25)
                                .padding(.horizontal, 20)
                                .background(Color(hex: "#F5F5F5"))
                                .cornerRadius(5)
                            }
                            .buttonStyle(PlainButtonStyle())  // This will ensure the default blue color overlay on tap is not applied.
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .onAppear {
                viewModel.fetchFriends()
            }
            .actionSheet(isPresented: $showActionSheet) {
                ActionSheet(
                    title: Text("Select an option for \(viewModel.friends.first(where: { $0.id == friendToManage })?.name ?? "this friend")"),
                    message: Text("Remove or Block?"),
                    buttons: [
                        .destructive(Text("Remove Friend")) {
                            if let id = self.friendToManage {
                                viewModel.removeFriend(id: id)
                                PostHogSDK.shared.capture("Remove Friend Tapped")
                            }
                        },
                        .default(Text("Block Friend")) {
                            if let id = self.friendToManage {
                                viewModel.removeFriend(id: id)
                                PostHogSDK.shared.capture("Block Friend Tapped")
                            }
                        },
                        .cancel()
                    ]
                )
            }
        }
    }
}
