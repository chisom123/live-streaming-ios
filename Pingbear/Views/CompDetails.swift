import SwiftUI
import Firebase
import FirebaseFirestore
import UIKit

struct CompDetails: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var competitionDescription: String = ""
    @State private var competitionTimestamp: Date
    @State private var isCameraPresented = false
    @State private var isVotingPresented = false
    @State private var selectedImageUrl: String = ""
    @State private var showBigImageView = false
    @ObservedObject var entryViewModel: EntryViewModel

    @State private var timeRemaining: String = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var competition: Competition // this holds the selected competition details

    func timeLeft(until endTime: Date) -> String {
        let currentTime = Date()
        let timeInterval = endTime.timeIntervalSince(currentTime)

        // Ensure the time interval is not negative (event has not passed)
        if timeInterval > 0 {
            let hours = Int(timeInterval) / 3600
            let minutes = Int(timeInterval) / 60 % 60
            let seconds = Int(timeInterval) % 60

            // Return as a formatted string
            return String(format: "%02i : %02i : %02i", hours, minutes, seconds)
        } else {
            // If the event is over, you might want to return something relevant
            return "00 : 00 :00"
        }
    }

    init(competition: Competition) {
        self.competition = competition
        _competitionTimestamp = State(initialValue: competition.date)  // Set initial timestamp
        // Initialize EntryViewModel with the competition ID
        self.entryViewModel = EntryViewModel(competitionId: competition.id)
    }

    
    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
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
                    
                    Spacer() // This spacer will ensure the two buttons are at opposite ends.
                }
    
                
                Text(competition.description)
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.bottom, 20)
                    .padding(.top, 30)
                    .padding(.horizontal, 20)

                Text(timeRemaining)
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .lineSpacing(10)
                    .foregroundColor(Color(hex: "#ababab"))
                    .padding(.bottom, 20)
                    .padding(.horizontal, 20)
                    .onReceive(timer) { _ in
                        // Calculate the end time (i.e., competition timestamp + 24 hours)
                        let endTime = competitionTimestamp.addingTimeInterval(24 * 60 * 60)

                        // Update the time remaining
                        timeRemaining = timeLeft(until: endTime)
                    }
                    .onDisappear {
                        timer.upstream.connect().cancel()
                    }
        
                Button(action: {
                    joincomp()
                }) {
                    Text("Join Competition")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(Color(hex: "#1199FF"))
                        .foregroundColor(Color(hex: "#fff"))
                        .cornerRadius(200)
                }
                .padding(.top, 10)
                .padding(.horizontal, 20)

                Button(action: {
                    vote()
                }) {
                    Text("Vote Now")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(Color(hex: "#7B68EE"))
                        .foregroundColor(Color(hex: "#fff"))
                        .cornerRadius(200)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                Text("Leaderboard")
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundColor(.black)
                    .padding(.top, 35)
                    .padding(.bottom, 20)
                    .padding(.horizontal, 20)

                ScrollView {
                    VStack(spacing: 10) { // Increased spacing between items
                        ForEach(Array(entryViewModel.entries.sorted { $0.stars > $1.stars }.enumerated()), id: \.element.id) { (index, entry) in
                            HStack {
                                // Position
                                Text("\(index + 1)")
                                    .font(.system(size: 18, weight: .bold)) // Slightly larger font for position
                                    .frame(width: 40, alignment: .center) // Centered and wider frame for position
                                    .foregroundColor(.black)

                                Divider() // Adds a visual separator

                                // User's name
                                Text(entry.userName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .lineLimit(1)
                                    .foregroundColor(.black)
                                    .truncationMode(.tail)
                                    .padding(.leading, 10) // Increased padding

                                Spacer()

                                // Stars and symbol
                                HStack(spacing: 10) { // Increased spacing
                                    Text("\(entry.stars)")
                                        .font(.system(size: 18, weight: .semibold)) // Slightly larger font for stars
                                        .foregroundColor(Color(hex: "#DAA520"))
                                    
                                    Image(systemName: "star.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20) // Slightly larger star icon
                                        .foregroundColor(Color(hex: "#DAA520"))
                                }
                                .padding(.trailing, 15) // Increased padding
                            }
                            .padding(20)
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                            .padding(.horizontal, 20) // Padding on the sides of each row
                            .onTapGesture {
                                self.selectedImageUrl = entry.imageUrl
                                self.showBigImageView = true
                            }
                        }
                    }
                }
                // Present BigImageView when an entry is tapped
                .fullScreenCover(isPresented: $showBigImageView) {
                    BigImageView(imageUrl: selectedImageUrl)
                }
                
            }
        }
        .onAppear {
            // Now that the view has appeared, we can calculate the initial time remaining
            let endTime = competitionTimestamp.addingTimeInterval(24 * 60 * 60)  // 12 hours from timestamp
            timeRemaining = timeLeft(until: endTime)
        }
        .fullScreenCover(isPresented: $isCameraPresented, content: {
            CameraView(competitionId: competition.id, viewModel: EntryViewModel(competitionId: competition.id))
        })
        .fullScreenCover(isPresented: $isVotingPresented, content: {
            EntryView(competitionId: competition.id)
        })
    }
    func joincomp() {
        self.isCameraPresented = true
    }
    func vote() {
        self.isVotingPresented = true
    }
}
