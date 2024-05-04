import SwiftUI
import Firebase
import FirebaseFirestore

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
                        Image("Close")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .padding(.leading, 20)
                            .padding(.top, 20)
                    }
                    Spacer()
                }
                .padding(.bottom, 10)

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
                    .padding(.top, 30)
                    .padding(.bottom, 30)
                    .padding(.horizontal, 20)
                }
            }
            .refreshable {
                viewModel.fetchFriends()
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
