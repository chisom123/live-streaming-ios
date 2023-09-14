import SwiftUI
import Firebase
import FirebaseFirestore

struct MyFriendsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: MyFriendsModel
    @State private var showRemoveFriendAlert: Bool = false
    @State private var friendToRemove: String? = nil
    
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

                ScrollView {
                    VStack(spacing: 25) {
                        ForEach(viewModel.friends, id: \.id) { friend in
                            Button(action: {
                                self.friendToRemove = friend.id
                                self.showRemoveFriendAlert = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 18) {
                                        Text(friend.name)
                                            .font(.system(size: 16, weight: .bold, design: .default))
                                            .foregroundColor(.black)
                                    }
                                    Spacer()
                                    
                                    Text("Remove")
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
            .onAppear {
                viewModel.fetchFriends()
            }
            .alert(isPresented: $showRemoveFriendAlert) {
                Alert(title: Text("Are you sure?"),
                      primaryButton: .destructive(Text("Yes")) {
                          if let id = self.friendToRemove {
                              viewModel.removeFriend(id: id)
                          }
                      },
                      secondaryButton: .cancel())
            }
        }
    }
}
