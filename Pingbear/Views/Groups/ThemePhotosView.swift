import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Kingfisher

struct ThemePhotosView: View {
    let themeName: String
    let themeId: String
    let competitionId: String
    
    @StateObject private var viewModel = ThemePhotosViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: ThemePhoto? = nil
    
    // Predictions sheet state
    @State private var showingPredictionsView = false
    @State private var selectedPhotoForPredictions: ThemePhoto? = nil
    
    // Interaction service for predictions view
    @StateObject private var interactionService = PhotoInteractionService()
    
    // Cache for pending user profiles
    @State private var pendingUserProfiles: [String: (username: String, profilePictureUrl: String?)] = [:]
    
    private let db = Firestore.firestore()
    
    init(themeName: String, themeId: String, competitionId: String) {
        self.themeName = themeName
        self.themeId = themeId
        self.competitionId = competitionId
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text(themeName)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(.white)
                        .truncationMode(.tail)
                        .lineLimit(1)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    // Invisible placeholder for balance
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(Color(hex: "#1A2245"))
                
                if viewModel.isLoading && viewModel.themePhotos.isEmpty {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                } else if viewModel.themePhotos.isEmpty && !viewModel.isLoading {
                    Spacer()
                    VStack(spacing: 16) {
                        Text("No Photos Yet")
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.themePhotos) { photo in
                                ThemePhotoCard(
                                    photo: photo,
                                    competitionId: competitionId,
                                    isEntryCreator: isEntryCreator(photo: photo),
                                    onTap: {
                                        selectedPhoto = photo
                                    },
                                    onPredictionsTap: {
                                        selectedPhotoForPredictions = photo
                                        loadPredictionsData(for: photo)
                                        showingPredictionsView = true
                                        Analytics.shared.track(event: "my_predictions_button_tapped_from_theme")
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .opacity
                                ))
                            }
                            
                            // Load More Section
                            if viewModel.hasMorePhotos {
                                LoadMoreButton(
                                    isLoading: viewModel.isLoadingMore,
                                    onLoadMore: {
                                        viewModel.loadMorePhotos()
                                    }
                                )
                                .padding(.vertical, 20)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
                
                // Error handling
                if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding()
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .background(Color(hex: "#10183C").ignoresSafeArea())
        }
        .onAppear {
            viewModel.fetchThemePhotos(themeId: themeId, competitionId: competitionId)
            Analytics.shared.trackScreen(
                name: "theme_photos",
                properties: [
                    "theme": themeName
                ]
            )
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            // Convert ThemePhoto to UserPhoto for FullScreenPhotoView
            let userPhoto = UserPhoto(
                id: photo.id,
                photoUrl: photo.photoUrl,
                stars: photo.stars,
                isSuperstar: photo.isSuperstar,
                creationDate: photo.creationDate,
                themeName: photo.themeName,
                themeId: photo.themeId,
                overlayText: photo.overlayText,
                overlayVerticalPosition: photo.overlayVerticalPosition,
                isFromCamera: photo.isFromCamera,
                userId: photo.userId,
                parlayStatus: photo.parlayStatus,
                parlayPredictions: photo.parlayPredictions,
                parlayPayout: photo.parlayPayout,
                parlayStake: photo.parlayStake
            )
            
            // Check if the photo belongs to the current user
            let currentUserId = Auth.auth().currentUser?.uid
            let displayUserName = (photo.userId == currentUserId) ? "Me" : photo.userName
            
            FullScreenPhotoView(
                photo: userPhoto,
                userName: displayUserName,
                competitionId: competitionId,
                userProfilePictureUrl: photo.profilePictureUrl,
                onDismiss: { updatedStarCount in
                    // Update the star count for this specific photo
                    viewModel.updatePhotoStars(photoId: photo.id, newStarCount: updatedStarCount)
                }
            )
        }
        .sheet(isPresented: $showingPredictionsView) {
            if let photo = selectedPhotoForPredictions {
                PredictionsDetailView(
                    parlayStatus: photo.parlayStatus ?? "",
                    parlayPredictions: photo.parlayPredictions ?? [:],
                    parlayPayout: photo.parlayPayout ?? 0,
                    parlayStake: photo.parlayStake ?? 0,
                    pendingUserProfiles: pendingUserProfiles,
                    interactionService: interactionService,
                    onDismiss: { showingPredictionsView = false }
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func isEntryCreator(photo: ThemePhoto) -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return photo.userId == currentUserId
    }
    
    private func loadPredictionsData(for photo: ThemePhoto) {
        // Load interaction data for the selected photo
        interactionService.loadRatingData(
            competitionId: competitionId,
            entryId: photo.id
        )
        
        interactionService.fetchInteractions(
            competitionId: competitionId,
            entryId: photo.id
        )
        
        // Load user profiles for pending predictions
        if let predictions = photo.parlayPredictions {
            for userId in predictions.keys {
                if !interactionService.interactions.contains(where: { $0.userId == userId }) {
                    fetchUserProfileForPendingUser(userId: userId)
                }
            }
        }
    }
    
    private func fetchUserProfileForPendingUser(userId: String) {
        guard pendingUserProfiles[userId] == nil else { return }
        
        db.collection("users").document(userId).getDocument { document, error in
            if let data = document?.data(),
               let username = data["username"] as? String {
                let profilePictureUrl = data["profilePictureUrl"] as? String
                DispatchQueue.main.async {
                    self.pendingUserProfiles[userId] = (username: username, profilePictureUrl: profilePictureUrl)
                }
            }
        }
    }
}

// MARK: - Theme Photo Card Component
struct ThemePhotoCard: View {
    let photo: ThemePhoto
    let competitionId: String
    let isEntryCreator: Bool
    let onTap: () -> Void
    let onPredictionsTap: () -> Void
    
    @State private var hasDragged = false
    
    private var parlayStatusColor: Color {
        switch photo.parlayStatus {
        case "won": return Color(hex: "#00FF00")
        case "lost": return Color(hex: "#FF4444")
        default: return Color(hex: "#FFD700")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Make only the image tappable
            KFImage(URL(string: photo.photoUrl))
                .placeholder {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 180)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
                .onFailure { _ in }
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
                .overlay(
                    VStack {
                        HStack {
                            Spacer()
                            Text(timeAgoString(from: photo.creationDate))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(15)
                        }
                        .padding(10)
                        Spacer()
                    },
                    alignment: .bottomLeading
                )
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let dragDistance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                            if dragDistance > 10 {
                                hasDragged = true
                            }
                        }
                        .onEnded { value in
                            let dragDistance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                            
                            // Only trigger tap if drag distance is less than 10 points
                            if dragDistance < 10 && !hasDragged {
                                onTap()
                            }
                            
                            hasDragged = false
                        }
                )

            
            // Stats section - NOT TAPPABLE
            HStack(spacing: 8) {
                // Profile picture and username on the left
                HStack(spacing: 12) {
                    ProfilePictureView(url: photo.profilePictureUrl, size: 30)
                    
                    Text(photo.userId == Auth.auth().currentUser?.uid ? "Me" : photo.userName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .truncationMode(.tail)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Star count
                HStack(spacing: 6) {
                    Text("\(photo.stars)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Image(systemName: "star.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: "#DAA520"))
                .cornerRadius(20)
                
                // My Predictions Button (Only for entry creator with parlay)
                if isEntryCreator && photo.parlayStatus != nil {
                    Button(action: onPredictionsTap) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(parlayStatusColor)
                                .frame(width: 10, height: 10)
                            
                            Text("Predictions")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .truncationMode(.tail)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(parlayStatusColor.opacity(0.15))
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
        }
        .background(Color(hex: "#1A2245"))
        .cornerRadius(10)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let seconds = Int(interval)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        let weeks = days / 7
        let months = days / 30
        let years = days / 365
        
        if years > 0 {
            return years == 1 ? "1 year ago" : "\(years) years ago"
        } else if months > 0 {
            return months == 1 ? "1 month ago" : "\(months) months ago"
        } else if weeks > 0 {
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        } else if days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        } else if hours > 0 {
            return hours == 1 ? "1h ago" : "\(hours)h ago"
        } else if minutes > 0 {
            return minutes == 1 ? "1m ago" : "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Load More Button Component
struct LoadMoreButton: View {
    let isLoading: Bool
    let onLoadMore: () -> Void
    
    var body: some View {
        Button(action: onLoadMore) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                    Text("Loading...")
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 16))
                    Text("Load More")
                }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "#3B4374"))
            )
        }
        .disabled(isLoading)
    }
}
