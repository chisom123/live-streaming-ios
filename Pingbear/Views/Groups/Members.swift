import SwiftUI
import FirebaseAuth

struct MembersView: View {
    
    var competition: Competition
    @ObservedObject private var viewModel: MembersViewModel
    @State private var leaveGroupAlert = false
    @State private var goHome = false
    @State private var showingJoinSelectView = false
    @State private var navigateToCompDetails = false
    
    init(competition: Competition) {
        self.competition = competition
        self.viewModel = MembersViewModel()
    }

    var body: some View {
        ZStack {
            
            VStack {
                // Header
                HStack {
                    Button(action: {
                        navigateToCompDetails = true
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        navigateToCompDetails = true
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
                        
                        Image(systemName: "person.badge.plus.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .font(.system(size: 25, weight: .bold))
                            .foregroundColor(Color(hex: "#FF4081"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color(hex: "#1A2245"))
                    .cornerRadius(10)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
                
                // Members List
                // Replace the existing ScrollView section with this:

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.members) { member in
                            VStack(spacing: 0) {
                                HStack {
                                    Text(member.username)
                                        .font(.system(size: 16, weight: .bold))
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .lineSpacing(9)
                                        .foregroundColor(.white)
                                        .truncationMode(.tail)
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
                                                
                                                Image(systemName: "plus.circle.fill")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 18, height: 18)
                                                    .foregroundColor(Color(hex: "#FFF"))
                                            }
                                            .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                                            .background(Color(hex: "#FF4081"))
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
                                .padding(.vertical, 25)

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
                
                Spacer()
                
                // Leave Competition Button
                Button(action: {
                    self.leaveGroupAlert = true
                }) {
                    Text("Leave Competition")
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .foregroundColor(Color(hex: "#FFF"))
                        .frame(maxWidth: .infinity)
                        .padding(15)
                        .cornerRadius(200)
                        .padding(.horizontal, 20)
                }
                .alert(isPresented: $leaveGroupAlert) {
                    Alert(
                        title: Text("Are you sure?"),
                        primaryButton: .destructive(Text("Yes")) {
                            viewModel.leaveCompetition(competitionId: competition.id, userId: Auth.auth().currentUser?.uid ?? "")
                            goHome = true
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        .background(Color(hex: "#10183C"))
        .onAppear {
            viewModel.fetchMembersDetails(for: competition)
        }
        .fullScreenCover(isPresented: $goHome, content: {
            MyCompsView()
        })
        .fullScreenCover(isPresented: $showingJoinSelectView) {
            JoinSelectView(competition: competition, viewModel: MyFriendsModel())
        }
        .fullScreenCover(isPresented: $navigateToCompDetails) {
            CompDetails(competition: competition)
        }
    }
}
