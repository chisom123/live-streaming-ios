import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// Mock models for demo competition
class DemoCompetition: ObservableObject, Identifiable {
    let id: String = "demo-competition"
    @Published var description: String = "besties"
    @Published var date: Date = Date()
    @Published var entriesNotVotedCount: Int = 5
    
    // Static demo competition instance
    static let demo = DemoCompetition()
}

// Mock entry model for demo
struct DemoEntry: Identifiable {
    let id: String
    let photoUrl: String
    let userName: String
    var stars: Int
    let userProfilePictureUrl: String?
    let isCurrentUser: Bool
    let overlayText: String? = nil // We're not using overlay text anymore
    let overlayVerticalPosition: CGFloat = 0
    let isFromCamera: Bool = true
    let themeName: String?
    
    // Mock demo photos from Firebase Storage - reduced to 5
    static let demoPhotoUrls = [
        "https://firebasestorage.googleapis.com/v0/b/pingbear-96b4c.appspot.com/o/demo%2Fentries%2F52c1d2168c708e20d41fa8538fde2307.jpg?alt=media&token=b1ae158f-1a6b-4dbd-8131-56624c0960ce",
        "https://firebasestorage.googleapis.com/v0/b/pingbear-96b4c.appspot.com/o/demo%2Fentries%2F76f9566b1a6c667929d300af2bd1686f.jpg?alt=media&token=24290cbe-1422-4c91-ac9f-4b81f22e96bc",
        "https://firebasestorage.googleapis.com/v0/b/pingbear-96b4c.appspot.com/o/demo%2Fentries%2Ff97258bcf7ba7776501612d8a5d99e35.jpg?alt=media&token=bbb571d3-ef10-4ba5-8279-53d237048b74",
        "https://firebasestorage.googleapis.com/v0/b/pingbear-96b4c.appspot.com/o/demo%2Fentries%2F1ebe0dd751d083ee302fd95727896dea.jpg?alt=media&token=33e036b7-1c09-41cd-86da-8f9d5e1335a1",
        "https://firebasestorage.googleapis.com/v0/b/pingbear-96b4c.appspot.com/o/demo%2Fentries%2Fbaa14cf89662b728ccdb6406caf5d4d9.jpg?alt=media&token=f9ffe8e0-4823-488f-b1b3-3261afc42057"
    ]
    
    // Mock usernames for the demo - reduced to 5
    static let demoUserNames = [
        "Olivia", "Alice", "Bella", "Morgan", "Mia"
    ]
    
    // Mock profile picture URLs - reduced to 5
    static let demoProfilePicUrls = [
        "https://firebasestorage.googleapis.com/v0/b/pingbear-96b4c.appspot.com/o/demo%2Fprofile_pictures%2F323603da40bb4e0311c533bc2c8db90e.jpg?alt=media&token=48deb646-56df-4c27-a6af-24b0b99137b2",
        "https://firebasestorage.googleapis.com/v0/b/pingbear-96b4c.appspot.com/o/demo%2Fprofile_pictures%2F83000bc4ce2150029b81061a27989e01.jpg?alt=media&token=3770f2ae-1ec6-46bc-aa33-06649bb55ad5",
        "https://firebasestorage.googleapis.com/v0/b/pingbear-96b4c.appspot.com/o/demo%2Fprofile_pictures%2F5b797f1008cdbd4489a372000d5f6954.jpg?alt=media&token=80a9fdea-6844-458e-a1b8-2d18ff880876",
        "https://firebasestorage.googleapis.com/v0/b/pingbear-96b4c.appspot.com/o/demo%2Fprofile_pictures%2Fbaa8ce3410462f4765376186ea7a94ff.jpg?alt=media&token=9700727c-2796-4960-8a59-90ec48c350e3",
        "https://firebasestorage.googleapis.com/v0/b/pingbear-96b4c.appspot.com/o/demo%2Fprofile_pictures%2Fdef37c9a2ee859f8fcd8c84a55e69a5d.jpg?alt=media&token=db3136b2-63e1-44a5-b7b7-3c1833b5b086"
    ]
    
    // Specific theme names for each demo entry - reduced to 5
    static let demoThemeNames = [
        "Selfie Wars!", "Outfit of the Day", "Caught in 4K", "Out n About", "Selfie Wars!"
    ]
}

// Mock user entry for leaderboard
struct DemoUserEntry: Identifiable {
    let id: String
    let userName: String
    let profilePictureUrl: String?
    var totalStars: Int
    var isCurrentUser: Bool
}

// View model for demo competition
class DemoEntryViewModel: ObservableObject {
    @Published var entries: [DemoEntry] = []
    @Published var userLeaderboard: [DemoUserEntry] = []
    @Published var hasEntriesToVoteOn: Bool = true
    @Published var currentIndex: Int = 0
    @Published var totalMemberCount: Int = 6
    @Published var currentUserProfileUrl: String? = nil
    
    init() {
        fetchCurrentUserProfilePicture()
        generateDemoEntries()
        generateDemoLeaderboard()
    }
    
    private func fetchCurrentUserProfilePicture() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { [weak self] document, error in
            if let document = document, document.exists {
                DispatchQueue.main.async {
                    self?.currentUserProfileUrl = document.data()?["profilePictureUrl"] as? String
                    self?.generateDemoLeaderboard() // Regenerate leaderboard with profile picture
                }
            }
        }
    }
    
    private func generateDemoEntries() {
        // Create 5 demo entries - each with specific photo and theme
        entries = (0..<DemoEntry.demoUserNames.count).map { index in
            DemoEntry(
                id: "demo-entry-\(index)",
                photoUrl: DemoEntry.demoPhotoUrls[index],
                userName: DemoEntry.demoUserNames[index],
                stars: Int.random(in: 0...15),
                userProfilePictureUrl: DemoEntry.demoProfilePicUrls[index],
                isCurrentUser: false,
                themeName: DemoEntry.demoThemeNames[index]
            )
        }
        
        // Shuffle the entries to make the experience more random
        entries.shuffle()
    }
    
    private func generateDemoLeaderboard() {
        // Add all demo users to leaderboard (excluding current user)
        userLeaderboard = (0..<DemoEntry.demoUserNames.count).map { index in
            DemoUserEntry(
                id: "demo-user-\(index)",
                userName: DemoEntry.demoUserNames[index],
                profilePictureUrl: DemoEntry.demoProfilePicUrls[index],
                totalStars: Int.random(in: 10...50),
                isCurrentUser: false
            )
        }
        
        // Sort demo users by stars
        userLeaderboard.sort { $0.totalStars > $1.totalStars }
        
        // Create current user with high stars value to ensure top position
        let highestStars = userLeaderboard.first?.totalStars ?? 50
        let currentUserStars = highestStars + Int.random(in: 5...15)
        
        // Add current user to leaderboard (will be at top position)
        let currentUser = DemoUserEntry(
            id: "current-user",
            userName: "Me",
            profilePictureUrl: currentUserProfileUrl,
            totalStars: currentUserStars,
            isCurrentUser: true
        )
        
        // Insert current user at the beginning (top position)
        userLeaderboard.insert(currentUser, at: 0)
    }
    
    func updateStarRating(for entryId: String, with stars: Int) {
        // Update stars for the rated entry
        if let index = entries.firstIndex(where: { $0.id == entryId }) {
            entries[index].stars += stars
        }
        
        // Find the user for this entry
        let userNameForEntry = entries.first(where: { $0.id == entryId })?.userName ?? ""
        
        // Don't update the current user's stars, only other users
        if let userIndex = userLeaderboard.firstIndex(where: { $0.userName == userNameForEntry && !$0.isCurrentUser }) {
            userLeaderboard[userIndex].totalStars += stars
            
            // Resort non-current users
            let currentUser = userLeaderboard.removeFirst() // Remove current user temporarily
            userLeaderboard.sort { $0.totalStars > $1.totalStars } // Sort remaining users
            userLeaderboard.insert(currentUser, at: 0) // Put current user back at the top
        }
    }
}
