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
                        Image("Close")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .padding(.leading, 20)
                            .padding(.top, 20)
                    }
                    
                    Spacer() // This spacer will ensure the two buttons are at opposite ends.
                    
                    // Step 2: Share Button
                    Button(action: {
                        entryViewModel.removeListeners()
                        isMembersPresented = true
                        PostHogSDK.shared.capture("View Group Members")
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
                    .lineLimit(2)
                    .foregroundColor(.black)
                    .padding(.bottom, 20)
                    .padding(.top, 30)
                    .padding(.horizontal, 20)
        
                HStack(spacing: 20) { // Add an HStack with some spacing between the buttons
                    Button(action: {
                        entryViewModel.removeListeners()
                        PostHogSDK.shared.capture("Add Video Initiated")
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
                        entryViewModel.removeListeners()
                        vote()
                        PostHogSDK.shared.capture("Voting Initiated")
                    }) {
                        Text("Rate Videos")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .font(.system(size: 17.5, weight: .bold, design: .default))
                            .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .background(entryViewModel.hasEntriesToVoteOn ? Color(hex: "#7B68EE") : Color(hex: "#D3D3D3"))
                            .foregroundColor(Color.white)
                            .cornerRadius(200)
                    }
                    .disabled(!entryViewModel.hasEntriesToVoteOn)
                }
                .padding(.top, 10)
                .padding(.horizontal, 20)
                
                HStack {
                    Text("Starboard")
                        .font(.system(size: 17, weight: .bold, design: .default))
                        .foregroundColor(.black)
                    
                    Toggle("", isOn: $showAggregate)
                        .onChange(of: showAggregate) { value in
                            let viewType = value ? "Aggregate" : "Individual"
                            PostHogSDK.shared.capture("Leaderboard View Toggled", properties: ["View Type": viewType])
                        }
                }
                .padding(.top, 35)
                .padding(.bottom, 20)
                .padding(.horizontal, 20)
                
                if showAggregate {
                    aggregateLeaderboardView  // Display aggregate leaderboard
                } else {
                    individualLeaderboardView // Display individual entries
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
    
    func joincomp() {
        self.isCameraPresented = true
    }
    func vote() {
        self.isVotingPresented = true
    }
}
