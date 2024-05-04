import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct MembersView: View {
    
    @Environment(\.presentationMode) var presentationMode
    var competition: Competition
    @ObservedObject private var viewModel = MembersViewModel()
    @State private var leaveGroupAlert = false
    @State private var goHome = false
    
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
                    
                    Button(action: {
                        self.leaveGroupAlert = true
                    }) {
                        HStack {
                            Text("Leave Group") // Text to display next to the icon
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: "#ababab"))
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                    .alert(isPresented: $leaveGroupAlert) {
                        Alert(title: Text("Are you sure?"),
                              primaryButton: .destructive(Text("Yes")) {
                            viewModel.leaveCompetition(competitionId: competition.id, userId: Auth.auth().currentUser?.uid ?? "")
                            goHome = true
                        },
                              secondaryButton: .cancel())
                    }
                }
                .padding(.bottom, 15)
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        ForEach(viewModel.joinUsernames, id: \.self) { username in
                            Text(username)
                                .font(.system(size: 16, weight: .bold))
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
                    .padding(.top, 30)
                    .padding(.horizontal, 20)
                }
            }
        }
        .refreshable {
            viewModel.fetchMembersDetails(for: competition)
        }
        .onAppear {
            viewModel.fetchMembersDetails(for: competition)
        }
        .fullScreenCover(isPresented: $goHome, content: {
            ContentView()
        })
    }

}
