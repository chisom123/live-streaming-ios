import SwiftUI

struct MyFriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MyFriendsModel
    @State private var showActionSheet: Bool = false
    @State private var friendToManage: String? = nil
    
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(Color.white)
                    }
                    
                    Spacer()
                    
                    Text("My Friends")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(Color.white)
                    }
                    .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.friends, id: \.id) { friend in
                            VStack(spacing: 0) {
                                Button(action: {
                                    self.friendToManage = friend.id
                                    self.showActionSheet = true
                                }) {
                                    HStack {
                                        HStack(spacing: 20) {
                                            ProfilePictureView(url: friend.profileImageUrl, size: 40)
                                            
                                            Text(friend.name)
                                                .font(.system(size: 16, weight: .bold))
                                                .lineLimit(1)
                                                .lineSpacing(9)
                                                .foregroundColor(.white)
                                                .truncationMode(.tail)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.leading, 5)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(Color(hex: "#D3D3D3"))
                                            .font(.system(size: 15, weight: .bold))
                                            .padding(.trailing, 5)
                                    }
                                    .padding(.vertical, 20)
                                    .padding(.horizontal, 20)
                                    .background(Color(hex: "#1A2245"))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())

                                if friend.id != viewModel.friends.last?.id {
                                    Divider()
                                        .background(Color.white.opacity(0.2))
                                }
                            }
                        }
                    }
                    .background(Color(hex: "#1A2245"))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                }
            }
            .background(Color(hex: "#10183C"))
            .onAppear {
                viewModel.fetchFriends()
                Analytics.shared.trackScreen(name: "my_friends")
            }
            .actionSheet(isPresented: $showActionSheet) {
                ActionSheet(
                    title: Text("Select an option for \(viewModel.friends.first(where: { $0.id == friendToManage })?.name ?? "this friend")"),
                    message: Text("Remove or Block?"),
                    buttons: [
                        .destructive(Text("Remove Friend")) {
                            if let id = self.friendToManage {
                                viewModel.removeFriend(id: id)
                            }
                        },
                        .default(Text("Block Friend")) {
                            if let id = self.friendToManage {
                                viewModel.removeFriend(id: id)
                            }
                        },
                        .cancel()
                    ]
                )
            }
        }
    }
}
