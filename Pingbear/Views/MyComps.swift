import SwiftUI
import FirebaseAuth // Ensure you have imported FirebaseAuth


struct MyCompsView: View {
    @StateObject private var viewModel = CompetitionsModel()
    @State private var selectedCompetition: Competition?
    @State private var isPresentingNewCompetition = false // State to control the presentation of the New Competition View


    var body: some View {
        VStack {
            // Top Bar with Title
            HStack {
                Text("My Competitions")
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .foregroundColor(.black) // Set the text color as needed
                    .padding(.horizontal, 20)

                Spacer() // Pushes the remaining content to the trailing edge
                
                Button(action: {
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
            .padding(.vertical, 20)

            Spacer()
            
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(viewModel.competitions, id: \.id) { competition in
                        HStack {
                            
                            Text(competition.description)
                                .font(.system(size: 16, weight: .semibold))
                                .lineLimit(2)
                                .lineSpacing(9)
                                .foregroundColor(.black)
                                .truncationMode(.tail)
                                .padding(.leading, 10) // Increased padding

                            Spacer()
                        }
                        .padding(20)
                        .background(Color(hex: "#F5F5F5"))
                        .cornerRadius(5)
                        .padding(.horizontal, 20)
                        .onTapGesture {
                            self.selectedCompetition = competition
                        }
                    }
                }
            }
            .fullScreenCover(item: $selectedCompetition) { comp in
                CompDetails(competition: comp)
            }
            .fullScreenCover(isPresented: $isPresentingNewCompetition) {
                NewCompetition() // Replace this with the actual view you want to present
            }
        }
        .onAppear {
            viewModel.fetchUserCompetitions()
        }
    }
}
