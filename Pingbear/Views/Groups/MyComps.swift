import SwiftUI
import FirebaseAuth
import FirebaseMessaging

struct MyCompsView: View {
    @StateObject private var viewModel = CompetitionsModel()
    @State private var selectedCompetition: Competition?
    @State private var isPresentingNewCompetition = false // State to control the presentation of the New Competition View
    @StateObject private var pushNotificationManager = PushNotificationManager()  // StateObject for lifecycle management
    @State private var isLoading = true
    @State private var hasInitiallyLoaded = false
    
    var body: some View {
        VStack {
            // Top Bar with Title
            HStack {
                Text("Groups")
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .foregroundColor(.black) // Set the text color as needed
                    .padding(.horizontal, 20)

                Spacer() // Pushes the remaining content to the trailing edge
                
                Button(action: {
                    viewModel.cleanupListeners()
                    isPresentingNewCompetition = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40) // Adjust the size as needed
                        .foregroundColor(Color(hex: "#1199FF")) // Your desired color
                        .background(Color.white)
                        .clipShape(Circle())
                        .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 15)

            Spacer()
            
            if !hasInitiallyLoaded {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.competitions.isEmpty {
                EmptyCompsView(action: {
                    viewModel.cleanupListeners()
                    isPresentingNewCompetition = true
                })
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(viewModel.competitions, id: \.id) { competition in
                            HStack {
                                Text(competition.description)
                                    .font(.system(size: 16, weight: .bold))
                                    .lineLimit(2)
                                    .lineSpacing(9)
                                    .foregroundColor(.black)
                                    .truncationMode(.tail)
                                    .padding(.leading, 10)
                                
                                Spacer()
                                
                                HStack(spacing: 8) {
                                    Text("\(competition.entriesNotVotedCount)")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(Color(hex: "#fff"))
                                    
                                    Image(systemName: "photo.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 18, height: 18)
                                        .foregroundColor(Color(hex: "#fff"))
                                }
                                .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                                .background(Color(hex: "#7B68EE"))
                                .cornerRadius(200)
                                .padding(.trailing, 10)
                            }
                            .padding(20)
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                            .padding(.horizontal, 20)
                            .onTapGesture {
                                viewModel.cleanupListeners()
                                self.selectedCompetition = competition
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(item: $selectedCompetition) { comp in
            CompDetails(competition: comp)
        }
        .fullScreenCover(isPresented: $isPresentingNewCompetition) {
            NewCompetition()
        }
        .onAppear {
            if !hasInitiallyLoaded {
                fetchData()
            }
        }
        .onDisappear {
            viewModel.cleanupListeners()
        }
    }
    
    private func fetchData() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        hasInitiallyLoaded = false
        
        viewModel.setupCompetitionListeners(userId: userId) {
            self.isLoading = false
            self.hasInitiallyLoaded = true
            
            if self.pushNotificationManager.userID == nil {
                self.pushNotificationManager.setupWithUserID(userId)
            }
        }
    }
}

struct EmptyCompsView: View {
    var action: () -> Void
    
    var body: some View {
        VStack {
            Text("No Groups Yet")
                .font(.system(size: 23, weight: .bold, design: .default))
                .foregroundColor(.black) // Set the text color as needed
                .padding(.bottom, 20)
            
            Text("Create a group or wait to be added")
                .font(.system(size: 18, weight: .bold, design: .default))
                .foregroundColor(.gray) // Set the text color as needed
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .padding(.bottom, 25)
            
            Button(action: action) {  // This button now uses the passed function
                Text("New Group")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .padding(EdgeInsets(top: 12, leading: 25, bottom: 12, trailing: 25))
                    .background(Color(hex: "#1199FF"))
                    .foregroundColor(Color(hex: "#fff"))
                    .cornerRadius(200)
            }
        }
        .padding(.horizontal, 20)
    }
}
