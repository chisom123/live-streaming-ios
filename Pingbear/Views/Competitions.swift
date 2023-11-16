import SwiftUI

struct CompetitionsView: View {
    @StateObject private var viewModel = CompetitionsModel()
    @State private var selectedCompetition: Competition?
    @State private var isPresentingNewCompetition = false // State to control the presentation of the New Competition View

    var body: some View {
        VStack {
            // Button at the top
            HStack {
                Text("Competitions")
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

            // Existing ScrollView content
            ScrollView {
                VStack(spacing: 20) {  // Increased spacing between items
                    ForEach(viewModel.competitions, id: \.id) { competition in
                        HStack {
                            // Position
                            Text("100")
                                .font(.system(size: 18, weight: .bold)) // Slightly larger font for position
                                .frame(width: 40, alignment: .center) // Centered and wider frame for position
                                .foregroundColor(Color(hex: "#DAA520"))

                            Divider() // Adds a visual separator
                            
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
                            self.selectedCompetition = competition  // Set the selected competition
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
    }
}
