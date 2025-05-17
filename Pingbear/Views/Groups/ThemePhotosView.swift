import SwiftUI
import FirebaseAuth

struct ThemePhotosView: View {
    let themeName: String
    let themeId: String
    let competitionId: String
    let disableAllRating: Bool
    
    @StateObject private var viewModel = ThemePhotosViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedPhoto: ThemePhoto? = nil
    
    init(themeName: String, themeId: String, competitionId: String, disableAllRating: Bool = false) {
        self.themeName = themeName
        self.themeId = themeId
        self.competitionId = competitionId
        self.disableAllRating = disableAllRating
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
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
                    
                    Button(action: {
                    
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(.white)
                            .opacity(0)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                } else if viewModel.themePhotos.isEmpty {
                    Spacer()
                    Text("No photos for this theme in the last 24 hours")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .padding()
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(viewModel.themePhotos) { photo in
                                VStack(spacing: 0) {
                                    // Make only the image tappable
                                    Button(action: {
                                        selectedPhoto = photo
                                    }) {
                                        AsyncImage(url: URL(string: photo.photoUrl)) { phase in
                                            switch phase {
                                            case .empty:
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(height: 180)
                                                    .overlay(
                                                        ProgressView()
                                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    )
                                            case .success(let image):
                                                ZStack(alignment: .bottomLeading) {
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(maxWidth: .infinity)
                                                        .frame(height: 180)
                                                        .clipped()
                                                    
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
                                                    }
                                                }
                                            case .failure:
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(height: 180)
                                                    .overlay(
                                                        Image(systemName: "photo")
                                                            .foregroundColor(.white)
                                                            .font(.system(size: 40))
                                                    )
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                    }
                                    
                                    // Stats section - NOT TAPPABLE
                                    HStack {
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
                                        
                                        // Star count on the right
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
                                    }
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 12)
                                }
                                .background(Color(hex: "#1A2245"))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
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
                isFromCamera: photo.isFromCamera
            )
            
            // Check if the photo belongs to the current user
            let currentUserId = Auth.auth().currentUser?.uid
            let displayUserName = (photo.userId == currentUserId) ? "Me" : photo.userName
            
            FullScreenPhotoView(
                photo: userPhoto,
                userName: displayUserName,
                competitionId: competitionId,
                disableRating: disableAllRating,
                onDismiss: { updatedStarCount in
                    // Update the star count for this specific photo
                    viewModel.updatePhotoStars(photoId: photo.id, newStarCount: updatedStarCount)
                }
            )
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours >= 24 {
            return "24h ago"
        } else if hours > 0 {
            return "\(hours)h ago"
        } else if minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
}
