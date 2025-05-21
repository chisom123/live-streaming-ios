import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct FullScreenPhotoView: View {
    let photo: UserPhoto
    let userName: String
    let competitionId: String?
    let disableRating: Bool
    let userProfilePictureUrl: String?
    @Environment(\.presentationMode) var presentationMode
    
    // Rating state
    @State private var rating: Int = 0
    @State private var isRatingEnabled: Bool = true
    @State private var hasAlreadyVoted: Bool = false
    @State private var animateRating: Bool = false
    @State private var currentStarCount: Int
    
    let onDismiss: ((Int) -> Void)?
    
    init(photo: UserPhoto, userName: String, competitionId: String?, userProfilePictureUrl: String? = nil, disableRating: Bool = false, onDismiss: ((Int) -> Void)? = nil) {
        self.photo = photo
        self.userName = userName
        self.competitionId = competitionId
        self.userProfilePictureUrl = userProfilePictureUrl
        self.disableRating = disableRating
        self.onDismiss = onDismiss
        self._currentStarCount = State(initialValue: photo.stars)
    }
    
    private let db = Firestore.firestore()
    
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            
            ZStack {
                // Background
                Color(hex: "#10183C")
                    .edgesIgnoringSafeArea(.all)
                
                // Photo with text overlay
                AsyncImage(url: URL(string: photo.photoUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: photo.isFromCamera ? .fill : .fit)
                        .frame(width: size.width, height: size.height)
                        .position(x: size.width/2, y: size.height/2)
                        .clipped()
                        .overlay {
                            if let overlayText = photo.overlayText {
                                Text(overlayText)
                                    .foregroundColor(.white)
                                    .font(.system(size: 24, weight: .bold))
                                    .multilineTextAlignment(.center)
                                    .frame(width: size.width * 0.8)
                                    .position(x: size.width / 2, y: photo.overlayVerticalPosition)
                            }
                        }
                } placeholder: {
                    ZStack {
                        Color(hex: "#10183C")
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                    .frame(width: size.width, height: size.height)
                }
                
                // Top bar with close button on left
                VStack {
                    HStack {
                        // Close button on left
                        Button(action: {
                            onDismiss?(currentStarCount)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .shadow(radius: 10)
                        }

                        Spacer()
                        
                        // Show username and profile picture inline
                        HStack(spacing: 15) {
                            ProfilePictureView(url: userProfilePictureUrl, size: 35)
                            
                            Text(userName)
                                .foregroundColor(.white)
                                .font(.system(size: 20, weight: .bold, design: .default))
                                .shadow(radius: 10)
                                .truncationMode(.tail)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: 250)

                        Spacer()

                        // Placeholder for visual balance
                        Image(systemName: "flag")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .shadow(radius: 10)
                            .opacity(0)
                    }
                    .padding(.top, (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0) + 5)
                    .padding()
                    
                    Spacer()
                }
                
                // Bottom rating bar (show disabled state when user can't rate)
                if userName != "Me" && competitionId != nil && !disableRating {
                    VStack(spacing: 0) {
                        Spacer()

                        // Theme container if theme exists
                        if let themeName = photo.themeName {
                            // Theme container with only top corners rounded
                            RoundedCorner(radius: 200, corners: [.topLeft, .topRight])
                                .fill(hasAlreadyVoted ? Color(hex: "#989898").opacity(0.9) : Color(hex: "#253063").opacity(0.9))
                                .frame(height: 50)
                                .overlay(
                                    Text(themeName)
                                        .foregroundColor(.white)
                                        .font(.system(size: 18, weight: .bold))
                                        .truncationMode(.tail)
                                        .lineLimit(1)
                                        .padding(.horizontal)
                                )
                                .padding(.horizontal, 30) // Same padding as rating bar
                        }
                        
                        // Container view for stars with background
                        ZStack {
                            if photo.themeName != nil {
                                RoundedCorner(radius: 200, corners: [.bottomLeft, .bottomRight])
                                    .fill(hasAlreadyVoted ? Color(hex: "#A9A9A9") : Color(hex: "#1A2245"))
                            } else {
                                RoundedRectangle(cornerRadius: 200)
                                    .fill(hasAlreadyVoted ? Color(hex: "#A9A9A9") : Color(hex: "#1A2245"))
                            }
                            
                            HStack(alignment: .center, spacing: 12) {
                                let maxStars = 5
                                
                                ForEach(1...maxStars, id: \.self) { star in
                                    Button(action: {
                                        // Check both hasAlreadyVoted AND isRatingEnabled to prevent double-clicks
                                        if !hasAlreadyVoted && isRatingEnabled {
                                            submitRating(stars: star)
                                        }
                                    }) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(hasAlreadyVoted ? Color(hex: "#c2c2c2") : star <= rating ? Color(hex: "#FFD700") : Color.white)
                                            .font(.system(size: 34))
                                            .scaleEffect(animateRating && star <= rating ? 1.3 : 1.0)
                                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animateRating && star <= rating)
                                    }
                                    .disabled(hasAlreadyVoted || !isRatingEnabled) // Disable based on both conditions
                                    .padding(5)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 15)
                        }
                        .frame(height: 80)
                        .padding(.horizontal, 30)
                        .padding(.bottom, (UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0) + 40)
                    }
                    .frame(width: size.width)
                }
            }
        }
        .ignoresSafeArea(edges: .all)
        .onAppear {
            checkVotingStatus()
            
            Analytics.shared.trackScreen(
                name: "fullscreen_photo",
                properties: [
                    "user_name": userName,
                    "can_rate": userName != "Me" && competitionId != nil
                ]
            )
        }
    }
    
    private func checkVotingStatus() {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              let competitionId = competitionId,
              userName != "Me" else {
            return
        }
        
        // Check if the user has already voted on this photo
        let voteRef = db.collection("groupMemberships")
            .document(currentUserId)
            .collection("competitions")
            .document(competitionId)
            .collection("votes")
            .document(photo.id)
        
        voteRef.getDocument { document, error in
            if let error = error {
                print("Error checking vote status: \(error)")
                return
            }
            
            DispatchQueue.main.async {
                self.hasAlreadyVoted = document?.exists ?? false
                self.isRatingEnabled = !self.hasAlreadyVoted
            }
        }
    }
    
    private func submitRating(stars: Int) {
        guard let competitionId = competitionId,
              !hasAlreadyVoted,
              isRatingEnabled else { // Add isRatingEnabled check here too
            return
        }
        
        // Immediately disable rating to prevent double-clicks
        isRatingEnabled = false
        rating = stars
        
        let starIncrement = photo.isSuperstar ? stars + 1 : stars
        currentStarCount += starIncrement
        
        // Animate the rating
        animateRating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            animateRating = false
        }
        
        // Track analytics
        Analytics.shared.trackEntry(
            action: "rate",
            entryId: photo.id,
            competitionId: competitionId,
            properties: ["rating": stars, "location": "fullscreen_view"]
        )
        
        // Trigger haptic feedback
        triggerHapticFeedback(for: stars)
        
        // Update the star rating using identical logic to EntryViewModel
        updateStarRating(for: photo.id, with: stars, competitionId: competitionId)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            // Mark as voted
            hasAlreadyVoted = true
        }
    }
    
    // Identical implementation to EntryViewModel's updateStarRating function
    private func updateStarRating(for entryId: String, with stars: Int, competitionId: String) {
        // Fetching the current Firebase user's ID
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: No authenticated user found.")
            return
        }
        
        let entryRef = db.collection("competitions").document(competitionId).collection("entries").document(entryId)
        let voteRef = db.collection("groupMemberships").document(currentUserId)
                         .collection("competitions").document(competitionId)
                         .collection("votes").document(entryId)
        
        let batch = db.batch()

        // Fetch the entry to determine if it is a superstar
        entryRef.getDocument { (document, error) in
            if let error = error {
                print("Error fetching entry: \(error)")
                return
            }
            
            guard let document = document, let data = document.data() else {
                print("Entry data not found")
                return
            }
            
            let ownerId = data["userId"] as? String ?? ""
            let isSuperstar = data["superstar"] as? Bool ?? false
            let starIncrement = isSuperstar ? stars + 1 : stars
            
            // Add operations to the batch
            batch.setData(["entryId": entryId], forDocument: voteRef, merge: true)
            batch.updateData(["stars": FieldValue.increment(Int64(starIncrement))], forDocument: entryRef)

            // Commit the batch
            batch.commit { err in
                if let err = err {
                    print("Batch commit failed: \(err)")
                } else {
                    print("Batch commit succeeded!")
                }
            }
        }
    }
    
    private func triggerHapticFeedback(for star: Int) {
        // Enhanced haptic feedback based on star value
        let intensity = Float(star) / 5.0
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred(intensity: CGFloat(intensity))
        
        // Add a short vibration pattern for casino-like feel
        let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            heavyGenerator.impactOccurred()
        }
    }
}
