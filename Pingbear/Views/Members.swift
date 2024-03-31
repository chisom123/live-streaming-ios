import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct MembersView: View {
    
    @Environment(\.presentationMode) var presentationMode
    var competition: Competition
    @State private var showingJoinSelectView = false
    @State private var showingVoteSelectView = false
    @State private var currentUsername: String?
    @State private var competitionUsername: String?
    @State private var isLoadingCurrentUser = true
    @ObservedObject private var viewModel = MembersViewModel()
    
    func fetchCurrentUsername() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Error: User not logged in")
            isLoadingCurrentUser = false
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { (document, error) in
            if let document = document, document.exists {
                let data = document.data()
                currentUsername = data?["username"] as? String
            } else {
                print("Document does not exist")
            }
            isLoadingCurrentUser = false
        }
    }
    
    func fetchCompetitionCreatorUsername() {
        let userId = competition.userId // Directly using userId assuming it's non-optional

        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { (document, error) in
            if let document = document, document.exists {
                let data = document.data()
                // Since self is not captured weakly, no need to check for self being nil
                self.competitionUsername = data?["username"] as? String ?? "Unknown"
            } else {
                print("Document does not exist: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    
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
                .padding(.bottom, 15)
                
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Group Admin")
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .frame(maxWidth: .infinity, alignment: .leading) // Align text to the left
                            .padding(.top, 20)
                            .padding(.bottom, 20)
                        
                        HStack {
                            Text(competitionUsername ?? "Unknown")
                                .font(.system(size: 16, weight: .semibold))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineSpacing(9)
                                .foregroundColor(.black)
                                .truncationMode(.tail)
                                .padding(.leading, 10)
                        }
                        .padding(20)
                        .background(Color(hex: "#F5F5F5"))
                        .cornerRadius(5)
                        
                        HStack {
                            // Text view
                            Text("Allowed to add images")
                                .font(.system(size: 16, weight: .bold, design: .default))

                            Spacer() // Pushes the text to the left and the button to the right

                            // Conditional rendering of the button
                            if !isLoadingCurrentUser && currentUsername == competitionUsername {
                                Button(action: {
                                    showingJoinSelectView = true
                                }) {
                                    Text("Edit")
                                        .font(.system(size: 16, weight: .bold, design: .default))
                                        .foregroundColor(Color(hex: "#1199FF"))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity) // Ensures the HStack fills the available width
                        .padding(.vertical, 20) // Combined top and bottom padding
                        
                        if viewModel.joinUsernames.isEmpty {
                            HStack {
                                Text("Everyone")
                                    .font(.system(size: 16, weight: .semibold))
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineSpacing(9)
                                    .foregroundColor(.black)
                                    .truncationMode(.tail)
                                    .padding(.leading, 10)
                            }
                            .padding(20)
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                        } else {
                            ForEach(viewModel.joinUsernames, id: \.self) { username in
                                Text(username)
                                    .font(.system(size: 16, weight: .semibold))
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineSpacing(9)
                                    .foregroundColor(.black)
                                    .truncationMode(.tail)
                                    .padding(.leading, 10)
                            }
                            .padding(20)
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                        }
        
                        HStack {
                            // Text view
                            Text("Allowed to rate images")
                                .font(.system(size: 16, weight: .bold, design: .default))

                            Spacer() // Pushes the text to the left and the button to the right

                            // Conditional rendering of the button
                            if !isLoadingCurrentUser && currentUsername == competitionUsername {
                                Button(action: {
                                    showingVoteSelectView = true
                                }) {
                                    Text("Edit")
                                        .font(.system(size: 16, weight: .bold, design: .default))
                                        .foregroundColor(Color(hex: "#1199FF"))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity) // Ensures the HStack fills the available width
                        .padding(.vertical, 20) // Combined top and bottom padding
                        
                        if viewModel.voteUsernames.isEmpty {
                            HStack {
                                Text("Everyone")
                                    .font(.system(size: 16, weight: .semibold))
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineSpacing(9)
                                    .foregroundColor(.black)
                                    .truncationMode(.tail)
                                    .padding(.leading, 10)
                            }
                            .padding(20)
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                        } else {
                            ForEach(viewModel.voteUsernames, id: \.self) { username in
                                Text(username)
                                    .font(.system(size: 16, weight: .semibold))
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineSpacing(9)
                                    .foregroundColor(.black)
                                    .truncationMode(.tail)
                                    .padding(.leading, 10)
                            }
                            .padding(20)
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .fullScreenCover(isPresented: $showingJoinSelectView) {
            JoinSelectView(competition: competition, fromLocationCheckView: false, viewModel: MyFriendsModel())
        }
        .fullScreenCover(isPresented: $showingVoteSelectView) {
            VoteSelectView(competition: competition, fromLocationCheckView: false, viewModel: MyFriendsModel())
        }
        .refreshable {
            viewModel.fetchMembersDetails(for: competition)
        }
        .onAppear {
            viewModel.fetchMembersDetails(for: competition)
            fetchCurrentUsername()
            fetchCompetitionCreatorUsername()
        }
    }

}
