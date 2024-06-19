import SwiftUI
import FirebaseAuth
import FirebaseMessaging

struct MyCompsView: View {
    @StateObject private var viewModel = CompetitionsModel()
    @State private var selectedCompetition: Competition?
    @State private var isPresentingNewCompetition = false // State to control the presentation of the New Competition View
    @State private var searchText = ""
    @State private var userId: String? = Auth.auth().currentUser?.uid
    @StateObject private var pushNotificationManager = PushNotificationManager()  // StateObject for lifecycle management
    
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
                        .frame(width: 44, height: 44) // Adjust the size as needed
                        .foregroundColor(Color(hex: "#1199FF")) // Your desired color
                        .background(Color.white)
                        .clipShape(Circle())
                        .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 15)

            Spacer()
            
//            // Search box
//            TextField("Search", text: $searchText)
//                .padding()
//                .background(Color(.systemGray6))
//                .foregroundColor(Color(hex: "#000"))
//                .font(.system(size: 16, weight: .medium, design: .default))
//                .cornerRadius(5)
//                .padding(.horizontal, 20)
//                .padding(.bottom, 15)
            
            ScrollView {
                VStack(spacing: 20) {  // Increased spacing between items
                    ForEach(viewModel.competitions.filter { competition in
                        searchText.isEmpty ||
                        competition.description.localizedCaseInsensitiveContains(searchText)
                    }, id: \.id) { competition in
                        HStack {
                            
                            Text(competition.description)
                                .font(.system(size: 16, weight: .bold))
                                .lineLimit(2)
                                .lineSpacing(9)
                                .foregroundColor(.black)
                                .truncationMode(.tail)
                                .padding(.leading, 10) // Increased padding

                            Spacer()
                            
                            // Stars and symbol
                            HStack(spacing: 8) { // Increased spacing
                                if competition.entriesNotVotedCount > 0 {
                                    Text("\(competition.entriesNotVotedCount)")
                                        .font(.system(size: 17, weight: .bold)) // Slightly larger font for stars
                                        .foregroundColor(Color(hex: "#fff"))
                                } else {
                                    Text("0")
                                        .font(.system(size: 17, weight: .bold)) // Slightly larger font for stars
                                        .foregroundColor(Color(hex: "#fff"))
                                }
                                
                                Image(systemName: "film.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18) // Slightly larger star icon
                                    .foregroundColor(Color(hex: "#fff"))
                            }
                            .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                            .background(Color(hex: "#7B68EE"))
                            .cornerRadius(200)
                            .padding(.trailing, 10) // Increased padding

                        }
                        .padding(20)
                        .background(Color(hex: "#F5F5F5"))
                        .cornerRadius(5)
                        .padding(.horizontal, 20)
                        .onTapGesture {
                            viewModel.cleanupListeners()
                            self.selectedCompetition = competition  // Set the selected competition
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(item: $selectedCompetition) { comp in
                CompDetails(competition: comp)
            }
            .fullScreenCover(isPresented: $isPresentingNewCompetition) {
                NewCompetition() // Replace this with the actual view you want to present
            }
        }
        .onAppear {
            self.userId = Auth.auth().currentUser?.uid
            if let userId = self.userId {
                viewModel.setupCompetitionListeners(userId: userId)
                if pushNotificationManager.userID == nil {
                    pushNotificationManager.setupWithUserID(userId)
                }
            }
        }
        .onDisappear {
            viewModel.cleanupListeners()
        }
    }
}
