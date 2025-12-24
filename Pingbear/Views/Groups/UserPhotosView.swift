import SwiftUI
import Kingfisher
import FirebaseAuth
import FirebaseFirestore

struct UserPhotosView: View {
    let userId: String
    let userName: String
    let competitionId: String
    let userProfilePictureUrl: String?
    
    @StateObject private var viewModel = UserPhotosViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: UserPhoto? = nil
    
    // Predictions sheet state
    @State private var showingPredictionsView = false
    @State private var selectedPhotoForPredictions: UserPhoto? = nil
    
    // Interaction service for predictions view
    @StateObject private var interactionService = PhotoInteractionService()
    
    // Cache for pending user profiles
    @State private var pendingUserProfiles: [String: (username: String, profilePictureUrl: String?)] = [:]
    
    private let db = Firestore.firestore()
    
    init(userId: String, userName: String, competitionId: String, userProfilePictureUrl: String? = nil) {
        self.userId = userId
        self.userName = userName
        self.competitionId = competitionId
        self.userProfilePictureUrl = userProfilePictureUrl
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
                    
                    HStack(spacing: 12) {
                        ProfilePictureView(url: userProfilePictureUrl, size: 30)
                        
                        Text(userName == "Me" ? "Me" : userName)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .foregroundColor(.white)
                            .truncationMode(.tail)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: 250)
                    
                    Spacer()
                    
                    // Invisible placeholder for balance to match the arrow size
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(Color(hex: "#1A2245"))
                
                if viewModel.isLoading && viewModel.userPhotos.isEmpty {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                } else if viewModel.userPhotos.isEmpty && !viewModel.isLoading {
                    Spacer()
                    VStack(spacing: 16) {
                        Text("No Photos Yet")
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .foregroundColor(.white)
                    }
                    .padding()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.userPhotos) { photo in
                                PhotoCard(
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
                                        Analytics.shared.track(event: "my_predictions_button_tapped_from_grid")
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .opacity
                                ))
                            }
                            
                            // Load More Section
                            if viewModel.hasMorePhotos {
                                LoadMoreView(
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
            viewModel.fetchUserPhotos(userId: userId, competitionId: competitionId)
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            FullScreenPhotoView(
                photo: photo,
                userName: userName,
                competitionId: competitionId,
                userProfilePictureUrl: userProfilePictureUrl,
                onDismiss: { updatedStarCount in
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
    
    private func isEntryCreator(photo: UserPhoto) -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return photo.userId == currentUserId
    }
    
    private func loadPredictionsData(for photo: UserPhoto) {
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

// MARK: - Photo Card Component
struct PhotoCard: View {
    let photo: UserPhoto
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
            
            // Stats section
            HStack(spacing: 8) {
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
                
                if let themeName = photo.themeName, let themeId = photo.themeId {
                    ThemeBadgeClickable(
                        themeName: themeName,
                        themeId: themeId,
                        competitionId: competitionId
                    )
                    .layoutPriority(-1)
                }
                
                Spacer()
                
                // My Predictions Button (Only for entry creator with parlay)
//                if isEntryCreator && photo.parlayStatus != nil {
//                    Button(action: onPredictionsTap) {
//                        HStack(spacing: 6) {
//                            Circle()
//                                .fill(parlayStatusColor)
//                                .frame(width: 10, height: 10)
//                            
//                            Text("Predictions")
//                                .font(.system(size: 16, weight: .bold))
//                                .foregroundColor(.white)
//                                .truncationMode(.tail)
//                                .lineLimit(1)
//                        }
//                        .padding(.horizontal, 10)
//                        .padding(.vertical, 5)
//                        .background(parlayStatusColor.opacity(0.15))
//                        .cornerRadius(20)
//                    }
//                }
            
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

// MARK: - Load More View Component
struct LoadMoreView: View {
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
