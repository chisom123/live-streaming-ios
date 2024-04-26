import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct MembersView: View {
    
    @Environment(\.presentationMode) var presentationMode
    var competition: Competition
    @State private var showingJoinSelectView = false
    @State private var isLoadingCurrentUser = true
    @ObservedObject private var viewModel = MembersViewModel()
    
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
                    .padding(.top, 30)
                    .padding(.horizontal, 20)
                }
            }
        }
        .fullScreenCover(isPresented: $showingJoinSelectView) {
            JoinSelectView(competition: competition, viewModel: MyFriendsModel(), viewModel2: AddFriendsModel())
        }
        .refreshable {
            viewModel.fetchMembersDetails(for: competition)
        }
        .onAppear {
            viewModel.fetchMembersDetails(for: competition)
        }
    }

}
