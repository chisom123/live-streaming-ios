import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

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
                HStack {
                    Button(action: {
                        navigateToCompDetails = true
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable() // Allows resizing of the image
                            .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                            .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                            .foregroundColor(Color.black) // Your desired color
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        self.leaveGroupAlert = true
                    }) {
                        HStack {
                            Text("Leave Group") // Text to display next to the icon
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: "#ababab"))
                        }
                    }
                    .alert(isPresented: $leaveGroupAlert) {
                        Alert(title: Text("Are you sure?"),
                              primaryButton: .destructive(Text("Yes")) {
                            viewModel.leaveCompetition(competitionId: competition.id, userId: Auth.auth().currentUser?.uid ?? "")
                            goHome = true
                        },
                              secondaryButton: .cancel())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                Button(action: {
                    showingJoinSelectView = true
                }) {
                    HStack {
                        Text("Add Friends to Group")
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .foregroundColor(Color.white)
                            .frame(maxWidth: .infinity, alignment: .leading) // Align text to the left

                        Image(systemName: "plus") // System name for '+' icon
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.white)
                            .frame(alignment: .trailing) // Align icon to the right
                    }
                    .padding(20)
                    .background(Color(hex: "#1199FF"))
                    .foregroundColor(Color(hex: "#fff"))
                    .cornerRadius(5)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                
                HStack {
                    Text("Group Members")
                        .font(.system(size: 16, weight: .bold, design: .default))
                    
                    Spacer()
                    
                }
                .padding(.top, 25)
                .padding(.bottom, 25)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(viewModel.members) { member in
                            Group {
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
                                        memberCellContent(member: member, showAddButton: true)
                                    }
                                } else {
                                    memberCellContent(member: member, showAddButton: false)
                                }
                            }
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            viewModel.fetchMembersDetails(for: competition)
        }
        .fullScreenCover(isPresented: $goHome, content: {
            ContentView()
        })
        .fullScreenCover(isPresented: $showingJoinSelectView) {
            JoinSelectView(competition: competition, viewModel: MyFriendsModel(), viewModel2: AddFriendsModel())
        }
        .fullScreenCover(isPresented: $navigateToCompDetails) {
            CompDetails(competition: competition) // Adjust according to your needs
        }
    }
    
    func memberCellContent(member: MemberUser, showAddButton: Bool) -> some View {
        HStack {
            Text(member.username)
                .font(.system(size: 16, weight: .bold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(9)
                .foregroundColor(.black)
                .truncationMode(.tail)
                .padding(.leading, 10)

            if showAddButton {
                HStack(spacing: 6) {
                    Text("Add")
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#1199FF"))
                        .font(.system(size: 16, weight: .bold, design: .default))

                    Image(systemName: "plus.circle")
                        .foregroundColor(Color(hex: "#1199FF"))
                        .font(.system(size: 16, weight: .bold, design: .default))
                }
            } else if member.justAdded {
                HStack(spacing: 6) {
                    Text("Added")
                        .fontWeight(.bold)
                        .foregroundColor(Color.green)
                        .font(.system(size: 16, weight: .bold, design: .default))

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.green)
                        .font(.system(size: 16, weight: .bold, design: .default))
                }
            }
        }
        .padding(20)
        .padding(.vertical, 3)
    }

}
