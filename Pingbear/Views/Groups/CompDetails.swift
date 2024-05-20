import SwiftUI
import Firebase
import FirebaseFirestore
import UIKit
import FirebaseAuth
import PostHog
import NotificationBannerSwift

struct CompDetails: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var goHome = false
    @State private var isCameraPresented = false
    @State private var isMembersPresented = false
    @State private var isVotingPresented = false
    @State private var selectedEntryCreationDate: Date = Date() // Add this to hold the selected entry's creation date
    @State private var currentUserId: String = Auth.auth().currentUser?.uid ?? ""
    
    @ObservedObject var entryViewModel: EntryViewModel

    @ObservedObject var competition: Competition
    
    private let db = Firestore.firestore()

    init(competition: Competition) {
        self.competition = competition
        self.entryViewModel = EntryViewModel(competitionId: competition.id, mode: .compDetailsView)
    }

    
    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                HStack {
                    Button(action: {
                        goHome = true
                    }) {
                        Image("Close")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .padding(.leading, 20)
                            .padding(.top, 20)
                    }
                    
                    Spacer() // This spacer will ensure the two buttons are at opposite ends.
                    
                    // Step 2: Share Button
                    Button(action: {
                        isMembersPresented = true
                    }) {
                        HStack {
                            Text("Group Members") // Text to display next to the icon
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: "#1199FF"))
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
    
                
                Text(competition.description)
                    .font(.system(size: 19, weight: .bold, design: .default))
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.bottom, 20)
                    .padding(.top, 30)
                    .padding(.horizontal, 20)
        
                HStack(spacing: 20) { // Add an HStack with some spacing between the buttons
                    Button(action: {
                        joincomp()
                    }) {
                        Text("Add Video")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .font(.system(size: 17.5, weight: .bold, design: .default))
                            .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .background(Color(hex: "#1199FF"))
                            .foregroundColor(Color.white)
                            .cornerRadius(200)
                    }

                    Button(action: {
                        vote()
                    }) {
                        Text("Rate Videos")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .font(.system(size: 17.5, weight: .bold, design: .default))
                            .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .background(competition.entriesNotVotedCount > 0 ? Color(hex: "#7B68EE") : Color(hex: "#D3D3D3"))
                            .foregroundColor(Color.white)
                            .cornerRadius(200)
                    }
                    .disabled(competition.entriesNotVotedCount == 0)
                }
                .padding(.top, 10)
                .padding(.horizontal, 20)
                
                Text("Leaderboard")
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .foregroundColor(.black)
                    .padding(.top, 35)
                    .padding(.bottom, 20)
                    .padding(.horizontal, 20)

                ScrollView {
                    VStack(spacing: 15) { // Increased spacing between items
                        ForEach(Array(entryViewModel.entries.sorted { $0.stars > $1.stars }.enumerated()), id: \.element.id) { (index, entry) in
                            HStack {
                                
                                if entry.isCurrentUser {
                                    // Position
                                    Text("\(index + 1)")
                                        .font(.system(size: 18, weight: .bold)) // Slightly larger font for position
                                        .frame(width: 40, alignment: .center) // Centered and wider frame for position
                                        .foregroundColor(Color(hex: "#DAA520"))

                                    Divider() // Adds a visual separator

                                    // User's name
                                    Text("Me")
                                        .font(.system(size: 16, weight: .bold))
                                        .lineLimit(1)
                                        .foregroundColor(Color(hex: "#DAA520"))
                                        .truncationMode(.tail)
                                        .padding(.leading, 10) // Increased padding
                                } else {
                                    // Position
                                    Text("\(index + 1)")
                                        .font(.system(size: 18, weight: .bold)) // Slightly larger font for position
                                        .frame(width: 40, alignment: .center) // Centered and wider frame for position
                                        .foregroundColor(.black)

                                    Divider() // Adds a visual separator

                                    // User's name
                                    Text(entry.userName)
                                        .font(.system(size: 16, weight: .bold))
                                        .lineLimit(1)
                                        .foregroundColor(.black)
                                        .truncationMode(.tail)
                                        .padding(.leading, 10) // Increased padding
                                }

                                Spacer()

                                // Stars and symbol
                                HStack(spacing: 8) { // Increased spacing
                                    Text("\(entry.stars)")
                                        .font(.system(size: 17, weight: .bold)) // Slightly larger font for stars
                                        .foregroundColor(Color(hex: "#fff"))
                                    
                                    Image(systemName: "star.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 18, height: 18) // Slightly larger star icon
                                        .foregroundColor(Color(hex: "#fff"))
                                }
                                .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                                .background(Color(hex: "#DAA520"))
                                .cornerRadius(200)
                                .padding(.trailing, 10) // Increased padding
                            }
                            .padding(20)
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                            .padding(.horizontal, 20) // Padding on the sides of each row
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isCameraPresented, content: {
            CameraView(competition: competition)
        })
        .fullScreenCover(isPresented: $isVotingPresented, content: {
            EntryView(competitionId: competition.id)
        })
        .fullScreenCover(isPresented: $goHome, content: {
            ContentView()
        })
        .fullScreenCover(isPresented: $isMembersPresented) {
            MembersView(competition: competition) // Replace this with the actual view you want to present
        }
        .onDisappear {
            entryViewModel.deactivateListeners()
        }
    }
    func joincomp() {
        self.isCameraPresented = true
    }
    func vote() {
        self.isVotingPresented = true
    }
    func timeSince(date: Date) -> String {
        let currentTime = Date()
        let timeInterval = currentTime.timeIntervalSince(date)

        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return minutes == 1 ? "1 min ago" : "\(minutes) mins ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else {
            let days = Int(timeInterval / 86400)
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
    }
    var timeAgo: String {
        timeSince(date: selectedEntryCreationDate)
    }
}
