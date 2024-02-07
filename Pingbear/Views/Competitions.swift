import SwiftUI

struct CompetitionsView: View {
    @StateObject private var viewModel = CompetitionsModel()
    @State private var selectedCompetition: Competition?
    @State private var isPresentingNewCompetition = false // State to control the presentation of the New Competition View

    var body: some View {
        VStack {
            // Button at the top
            HStack {
                Text("All Competitions")
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
                            
                            VStack(alignment: .leading) { // Use VStack for vertical stacking
                                Text(competition.description)
                                    .font(.system(size: 16, weight: .semibold))
                                    .lineLimit(2)
                                    .lineSpacing(9)
                                    .foregroundColor(.black)
                                    .truncationMode(.tail)
                                    .padding(.leading, 10) // Increased padding
                                
                                Text(competition.username) // Display the username
                                    .font(.system(size: 14.5, weight: .semibold))
                                    .lineLimit(1)
                                    .lineSpacing(9)
                                    .foregroundColor(.gray)
                                    .truncationMode(.tail)
                                    .padding(.leading, 10) // Increased padding
                                    .padding(.top, 0.75)
                            }

                            Spacer()
                
                            // Stars and symbol
                            HStack(spacing: 8) { // Increased spacing
                                if competition.entriesNotVotedCount > 0 {
                                    Text("\(competition.entriesNotVotedCount)")
                                        .font(.system(size: 17, weight: .semibold)) // Slightly larger font for stars
                                        .foregroundColor(Color(hex: "#fff"))
                        
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 18, height: 18) // Slightly larger star icon
                                        .foregroundColor(Color(hex: "#fff"))
                                } else {
                                    Text("0")
                                        .font(.system(size: 17, weight: .semibold)) // Slightly larger font for stars
                                        .foregroundColor(Color(hex: "#fff"))
                                    
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 18, height: 18) // Slightly larger star icon
                                        .foregroundColor(Color(hex: "#fff"))
                                }
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
                            self.selectedCompetition = competition  // Set the selected competition
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .refreshable {
                viewModel.fetchCompetitions()
            }
            .onAppear {
                viewModel.fetchCompetitions()
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
