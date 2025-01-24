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
                    
                    Button(action: {
                        navigateToCompDetails = true
                    }) {
                        Text(competition.description)
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                Button(action: {
                    showingJoinSelectView = true
                }) {
                    HStack {
                        Text("Add Friends to Competition")
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .foregroundColor(Color(hex: "#1199FF"))
                            .frame(maxWidth: .infinity, alignment: .leading) // Align text to the left
                    }
                    .padding(20)
                    .background(Color(hex: "#F5F5F5"))
                    .cornerRadius(5)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                
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
                
                Spacer()
                
                Button(action: {
                    self.leaveGroupAlert = true
                }) {
                    HStack {
                        Text("Leave Competition") // Text to display next to the icon
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .foregroundColor(Color(hex: "#ababab"))
                    }
                    .padding(10)
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
