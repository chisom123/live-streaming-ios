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
    @State private var currentUserId: String = Auth.auth().currentUser?.uid ?? ""
    @State private var showAggregate = false
    @State private var selectedEntry: Entry?
    
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
                        entryViewModel.removeListeners()
                        goHome = true
                        PostHogSDK.shared.capture("Close Competition Details")
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable() // Allows resizing of the image
                            .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                            .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                            .foregroundColor(Color.black) // Your desired color
                    }
                    
                    Spacer() // This spacer will ensure the two buttons are at opposite ends.
                    
                    Text(competition.description)
                        .font(.system(size: 17, weight: .bold, design: .default))
                        .lineLimit(1)
                        .foregroundColor(.black)
                        .padding(.horizontal)
                        .onAppear {
                            PostHogSDK.shared.capture("Comp Details View Opened")
                        }
                    
                    Spacer()
                    
                    // Step 2: Share Button
                    Button(action: {
                        entryViewModel.removeListeners()
                        isMembersPresented = true
                        PostHogSDK.shared.capture("View Group Members")
                    }) {
                        Image(systemName: "ellipsis")
                            .resizable() // Allows resizing of the image
                            .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                            .frame(width: 30, height: 30) // Adjust the width and height to decrease the size
                            .foregroundColor(Color.gray) // Your desired color
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                HStack(spacing: 10) { // Add an HStack with some spacing between the buttons
                    // Button positioned at the bottom right
                    Button(action: {
                        initiateVideoCapture()
                    }) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24, weight: .bold))
                            .frame(width: 45, height: 45)
                            .padding(6)
                            .background(Color(hex: "#F5F5F5"))
                            .foregroundColor(Color(hex: "#000"))
                            .clipShape(Circle())
                    }

                    Button(action: {
                        entryViewModel.removeListeners()
                        vote()
                        PostHogSDK.shared.capture("Voting Initiated")
                    }) {
                        Text("Start Rating")
                            .frame(maxWidth: .infinity, minHeight: 45)
                            .font(.system(size: 20, weight: .bold, design: .default))
                            .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .background(entryViewModel.hasEntriesToVoteOn ? Color(hex: "#7B68EE") : Color(hex: "#D3D3D3"))
                            .foregroundColor(Color.white)
                            .cornerRadius(200)
                    }
                    .disabled(!entryViewModel.hasEntriesToVoteOn)
                    
                    Button(action: {
                        showAggregate.toggle()
                        let viewType = showAggregate ? "Aggregate" : "Individual"
                        PostHogSDK.shared.capture("Leaderboard View Toggled", properties: ["View Type": viewType])
                    }) {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 25, height: 25)
                            .foregroundColor(showAggregate ? Color.black : Color.gray)
                    }
                    .padding(.horizontal)
                    
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 10)
                .background(Color(hex: "#F5F5F5"))
                .cornerRadius(5)
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
                
                if showAggregate {
                    if entryViewModel.userLeaderboard.isEmpty {
                        EmptyLeaderboardView(action: initiateVideoCapture)
                        Spacer()
                    } else {
                        aggregateLeaderboardView
                    }
                } else {
                    if entryViewModel.entries.isEmpty {
                        EmptyLeaderboardView(action: initiateVideoCapture)
                        Spacer()
                    } else {
                        individualLeaderboardView
                    }
                }
                
            }
        }
        .fullScreenCover(isPresented: $isCameraPresented, content: {
            CameraView(competition: competition)
        })
        .fullScreenCover(isPresented: $isVotingPresented, content: {
            EntryView(competitionId: competition.id, competition: competition)
        })
        .fullScreenCover(isPresented: $goHome, content: {
            ContentView()
        })
        .fullScreenCover(isPresented: $isMembersPresented) {
            MembersView(competition: competition) // Replace this with the actual view you want to present
        }
        .onDisappear {
            entryViewModel.removeListeners()
        }
    }
    var aggregateLeaderboardView: some View {
        ScrollView {
            VStack(spacing: 15) {
                // Ensure the ForEach uses the updated userLeaderboard property
                ForEach(entryViewModel.userLeaderboard) { userEntry in
                    leaderboardRowView(userEntry.userName, userEntry.totalStars)
                }
            }
        }
    }

    var individualLeaderboardView: some View {
        ScrollView {
            VStack(spacing: 15) {
                ForEach(entryViewModel.entries, id: \.id) { entry in
                    Button(action: {
                        entryViewModel.removeListeners()
                        self.selectedEntry = entry
                        PostHogSDK.shared.capture("Starboard Video Tapped")
                    }) {
                        leaderboardRowView(entry.userName, entry.stars)
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedEntry) { entry in
            StarboardVideoPlayer(entry: entry, competition: competition)
        }
        .refreshable {
            entryViewModel.fetchEntries(mode: .compDetailsView)  // Refresh the entries based on current mode
        }
    }

    func leaderboardRowView(_ userName: String, _ stars: Int) -> some View {
        HStack {
            Text(userName)
                .font(.system(size: 16, weight: .bold))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, 10)
                .foregroundColor(userName == "Me" ? Color(hex: "#DAA520") : Color.black)  // Change text color if it's the current user

            Spacer()

            HStack(spacing: 8) {
                Text("\(stars)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color.white)
                
                Image(systemName: "star.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundColor(Color.white)
            }
            .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
            .background(Color(hex: "#DAA520"))
            .cornerRadius(200)
            .padding(.trailing, 10)
        }
        .padding(20)
        .background(Color(hex: "#F5F5F5"))
        .cornerRadius(5)
        .padding(.horizontal, 20)
    }
    
    func initiateVideoCapture() {
        entryViewModel.removeListeners()
        PostHogSDK.shared.capture("Add Video Initiated")
        joincomp()
    }
    
    func joincomp() {
        self.isCameraPresented = true
    }
    func vote() {
        self.isVotingPresented = true
    }
}

struct EmptyLeaderboardView: View {
    var action: () -> Void
    
    var body: some View {
        VStack {
            Image("Empty")
                .resizable() // Allows the image to resize
                .aspectRatio(contentMode: .fit) // Keeps the aspect ratio and fits within the given space
                .frame(width: 150)
            
            Text("Share a Video")
                .font(.system(size: 22, weight: .bold, design: .default))
                .foregroundColor(.black) // Set the text color as needed
                .padding(.top, 25)
                .padding(.bottom, 25)
            
            Button(action: action) {  // This button now uses the passed function
                Text("New Video")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .background(Color(hex: "#1199FF"))
                    .foregroundColor(Color(hex: "#fff"))
                    .cornerRadius(200)
            }
            
 
        }
        .padding(20)
        .background(Color(hex: "#F5F5F5"))
        .cornerRadius(5)
        .padding(.horizontal, 20)
    }
}
