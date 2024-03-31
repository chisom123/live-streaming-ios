import SwiftUI
import Firebase
import FirebaseFirestore
import UIKit
import FirebaseAuth
import PostHog
import NotificationBannerSwift

struct ImageDisplayState {
    var imageUrl: String = ""
    var show: Bool = false
}

struct CompDetails: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var competitionDescription: String = ""
    @State private var competitionTimestamp: Date
    @State private var isCameraPresented = false
    @State private var isMembersPresented = false
    @State private var isVotingPresented = false
    @State private var selectedEntryCreationDate: Date = Date() // Add this to hold the selected entry's creation date
    @State private var imageDisplayState = ImageDisplayState()
    @State private var currentUserId: String = Auth.auth().currentUser?.uid ?? ""
    @EnvironmentObject var sharedViewModel: SharedViewModel
    
    @State private var competitionUsername: String = ""
    
    @ObservedObject var entryViewModel: EntryViewModel

    @ObservedObject var competition: Competition

    var fromLocationCheckView: Bool // Add this line
    @State private var listeners: [ListenerRegistration] = []
    
    private let db = Firestore.firestore()
    
    private func refreshEntriesNotVotedCount() {
        let competitionId = competition.id
        let userId = currentUserId // Ensure this is the current user's ID
        
        // Define the timestamp for entries within the last 24 hours
        let twentyFourHoursAgoTimestamp = Timestamp(date: Date().addingTimeInterval(-86400)) // 24 hours ago

        // Reference to the competition entries
        let entriesRef = db.collection("competitions").document(competitionId).collection("entries")
        
        // Query to fetch entries added within the last 24 hours
        let listener = entriesRef.whereField("timestamp", isGreaterThanOrEqualTo: twentyFourHoursAgoTimestamp).addSnapshotListener { (entriesSnapshot, error) in
            if let error = error {
                print("Error getting entries: \(error.localizedDescription)")
                return
            }
            
            let totalEntriesCount = entriesSnapshot?.documents.count ?? 0
            let userEntriesCount = entriesSnapshot?.documents.filter { $0["userId"] as? String == userId }.count ?? 0
            
            // Reference to the participant's voted entries
            let participantRef = self.db.collection("competitions").document(competitionId).collection("participants").document(userId)
            
            // Fetch the document containing the voted entries
            let listener_part = participantRef.addSnapshotListener { (participantDocument, error) in
                if let error = error {
                    print("Error getting participant document: \(error.localizedDescription)")
                    return
                }
                
                let votedEntries = participantDocument?.data()?["voted_entries"] as? [String] ?? []
                let notVotedCount = totalEntriesCount - votedEntries.count - userEntriesCount
                
                DispatchQueue.main.async {
                    self.competition.entriesNotVotedCount = notVotedCount
                }
            }
            listeners.append(listener_part)
        }
        listeners.append(listener)
    }

    
    private func refreshCompetitionData() {
        let competitionRef = db.collection("competitions").document(competition.id)

        let listener_comp = competitionRef.addSnapshotListener { (document, error) in
            guard let document = document, document.exists, error == nil else {
                print("Error fetching document: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            let data = document.data()
            DispatchQueue.main.async {
                // Update the properties of the Competition object directly.
                // Being in a struct (the SwiftUI view), we don't have the same concerns about strong reference cycles here.
                self.competition.description = data?["description"] as? String ?? ""
                self.competition.date = (data?["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                self.competition.username = data?["username"] as? String ?? ""
                self.competition.allow_join = data?["allow_join"] as? [String] ?? []
                self.competition.allow_vote = data?["allow_vote"] as? [String] ?? []
            }
            
            self.refreshEntriesNotVotedCount()
        }
        listeners.append(listener_comp)
    }

    private func fetchCompetitionCreatorUsername(userId: String) {
        let userRef = db.collection("users").document(userId)
        userRef.getDocument { (document, error) in
            if let document = document, document.exists {
                let username = document.data()?["username"] as? String ?? "Unknown"
                DispatchQueue.main.async {
                    self.competitionUsername = username
                }
            } else {
                print("Document does not exist or error: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    init(competition: Competition, fromLocationCheckView: Bool) {
        self.competition = competition
        self.fromLocationCheckView = fromLocationCheckView // Initialize the fromLocationCheckView property
        _competitionTimestamp = State(initialValue: competition.date)
        self.entryViewModel = EntryViewModel(competitionId: competition.id, mode: .compDetailsView)
        fetchCompetitionCreatorUsername(userId: competition.userId) // Assuming competition has a userId attribute
    }

    
    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                HStack {
                    Button(action: {
                        if fromLocationCheckView {
                            sharedViewModel.shouldNavigateToCompetitionsView = true
                        } else {
                            presentationMode.wrappedValue.dismiss()
                        }
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
                            Text("View Members") // Text to display next to the icon
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: "#1199FF"))
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
    
                
                Text(competition.description)
                    .font(.system(size: 19, weight: .semibold, design: .default))
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.bottom, 20)
                    .padding(.top, 30)
                    .padding(.horizontal, 20)
        
                HStack(spacing: 20) { // Add an HStack with some spacing between the buttons
                    Button(action: {
                        joincomp()
                    }) {
                        Text("Add")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .background(competition.allow_join.contains("Everyone") || competition.allow_join.contains(currentUserId) ? Color(hex: "#1199FF") : Color(hex: "#D3D3D3"))
                            .foregroundColor(Color.white)
                            .cornerRadius(200)
                    }
                    .disabled(!(competition.allow_join.contains("Everyone") || competition.allow_join.contains(currentUserId))) // Disable if not allowed to join

                    Button(action: {
                        vote()
                    }) {
                        Text("Rate")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .background((competition.allow_vote.contains("Everyone") || competition.allow_vote.contains(currentUserId)) && competition.entriesNotVotedCount > 0 ? Color(hex: "#7B68EE") : Color(hex: "#D3D3D3"))
                            .foregroundColor(Color.white)
                            .cornerRadius(200)
                    }
                    .disabled(!(competition.allow_vote.contains("Everyone") || competition.allow_vote.contains(currentUserId)) || competition.entriesNotVotedCount == 0)
//                    .disabled(!(competition.allow_vote.contains("Everyone") || competition.allow_vote.contains(currentUserId)))
                }
                .padding(.top, 10)
                .padding(.horizontal, 20)
                
                Text("Leaderboard")
                    .font(.system(size: 17, weight: .semibold, design: .default))
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
                                        .font(.system(size: 16, weight: .semibold))
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
                                        .font(.system(size: 16, weight: .semibold))
                                        .lineLimit(1)
                                        .foregroundColor(.black)
                                        .truncationMode(.tail)
                                        .padding(.leading, 10) // Increased padding
                                }

                                Spacer()

                                // Stars and symbol
                                HStack(spacing: 8) { // Increased spacing
                                    Text("\(entry.stars)")
                                        .font(.system(size: 17, weight: .semibold)) // Slightly larger font for stars
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
                            .onTapGesture {
                                if competition.allow_join.contains("Everyone") ||
                                   competition.allow_vote.contains("Everyone") ||
                                   competition.allow_join.contains(currentUserId) ||
                                   competition.allow_vote.contains(currentUserId) {
                                    self.imageDisplayState.imageUrl = entry.imageUrl
                                    self.imageDisplayState.show = true
                                    self.selectedEntryCreationDate = entry.creationDate
                                    PostHogSDK.shared.capture("Leaderboard Image Open")
                                } else {
                                    let banner = NotificationBanner(title: "Contact the group admin for access", style: .warning)
                                    banner.show()
                                }
                            }
                        }
                    }
                }
                // Present BigImageView when an entry is tapped
                .fullScreenCover(isPresented: $imageDisplayState.show) {
                    BigImageView(imageUrl: imageDisplayState.imageUrl, creationDate: selectedEntryCreationDate)
                }
                
            }
        }
        .onAppear {
            refreshCompetitionData()
            refreshEntriesNotVotedCount()
        }
        .onDisappear {
            for listener in listeners {
                listener.remove()
            }
            listeners.removeAll()
        }
        .fullScreenCover(isPresented: $isCameraPresented, content: {
            CameraView(competitionId: competition.id, viewModel: EntryViewModel(competitionId: competition.id, mode: .entryView), competition: competition)
        })
        .fullScreenCover(isPresented: $isVotingPresented, content: {
            EntryView(competitionId: competition.id)
        })
        .fullScreenCover(isPresented: $isMembersPresented) {
            MembersView(competition: competition) // Replace this with the actual view you want to present
        }
    }
    func joincomp() {
        self.isCameraPresented = true
    }
    func vote() {
        self.isVotingPresented = true
    }
}
