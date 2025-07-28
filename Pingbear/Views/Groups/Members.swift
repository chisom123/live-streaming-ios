import SwiftUI

struct MembersView: View {
    
    var competition: Competition
    @StateObject private var viewModel = MembersViewModel()
    @StateObject private var myFriendsModel = MyFriendsModel()
    @State private var showingJoinSelectView = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            
            VStack {
                // Header
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text(competition.description)
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                // Combined Action Buttons Container
                VStack(spacing: 0) {
                    // Add Players Button
                    Button(action: {
                        showingJoinSelectView = true
                    }) {
                        HStack {
                            Text("Add Players to Competition")
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: "#FFF"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 10)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color(hex: "#D3D3D3"))
                                .font(.system(size: 15, weight: .bold))
                                .padding(.trailing, 10)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .padding(.vertical, 5)
                    }
                }
                .background(Color(hex: "#1A2245"))
                .cornerRadius(10)
                .padding(.horizontal, 20)
                
                // Members List
                HStack {
                    Text("Players")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(20)
                .padding(.top, 5)
                
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.members) { member in
                            VStack(spacing: 0) {
                                HStack {
                                    HStack(spacing: 20) {
                                        ProfilePictureView(url: member.profileurl, size: 40)
                                        
                                        Text(member.username)
                                            .font(.system(size: 16, weight: .bold))
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .lineSpacing(9)
                                            .foregroundColor(.white)
                                            .truncationMode(.tail)
                                    }
                                    .padding(.leading, 30)

                                    if member.id != viewModel.currentUserId && !member.isAdded {
                                        Button(action: {
                                            viewModel.addFriend(member: member) { success, error in
                                                if success {
                                                    // Handle success if needed
                                                } else {
                                                    // Handle error if needed
                                                }
                                            }
                                        }) {
                                            HStack(spacing: 8) {
                                                Text("Add")
                                                    .font(.system(size: 17, weight: .bold))
                                                    .foregroundColor(Color(hex: "#FFF"))
                                            }
                                            .padding(EdgeInsets(top: 3, leading: 15, bottom: 3, trailing: 15))
                                            .background(Color(hex: "#4169E1"))
                                            .cornerRadius(200)
                                        }
                                        .padding(.trailing, 30)
                                    } else if member.justAdded {
                                        HStack(spacing: 8) {
                                            Text("Added")
                                                .font(.system(size: 17, weight: .bold))
                                                .foregroundColor(Color(hex: "#FFF"))
                                            
                                            Image(systemName: "checkmark.circle.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 18, height: 18)
                                                .foregroundColor(Color(hex: "#FFF"))
                                        }
                                        .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                                        .background(Color(hex: "#00FF00"))
                                        .cornerRadius(200)
                                        .padding(.trailing, 30)
                                        .opacity(0)
                                    }
                                }
                                .padding(.vertical, 20)

                                if member.id != viewModel.members.last?.id {
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
        }
        .background(Color(hex: "#10183C"))
        .navigationBarHidden(true)
        .onAppear {
            if viewModel.members.isEmpty {
                viewModel.fetchMembersDetails(for: competition)
            }
        }
        .fullScreenCover(isPresented: $showingJoinSelectView, onDismiss: {
            viewModel.fetchMembersDetails(for: competition)
        }) {
            JoinSelectView(competition: competition, viewModel: myFriendsModel)
        }
    }
}
