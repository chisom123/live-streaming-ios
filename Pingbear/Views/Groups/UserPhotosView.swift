import SwiftUI

struct UserPhotosView: View {
    let userId: String
    let userName: String
    let competitionId: String
    
    @StateObject private var viewModel = UserPhotosViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedPhoto: UserPhoto? = nil
    
    init(userId: String, userName: String, competitionId: String) {
        self.userId = userId
        self.userName = userName
        self.competitionId = competitionId
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) { // Add spacing: 0 to ensure no automatic spacing
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
                    
                    Text(userName == "Me" ? "My Photos" : "\(userName)'s photos")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .truncationMode(.tail)
                        .lineLimit(1)
                    
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
                
                // Boost privacy notice - only show for user's own photos if they have any boosts
                if userName == "Me" && viewModel.userPhotos.contains(where: { $0.isSuperstar }) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Your boosts are private. Other players cannot see which photos have been boosted")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.leading)
                            .lineSpacing(2)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                } else if viewModel.userPhotos.isEmpty {
                    Spacer()
                    Text("No photos in the last 24 hours")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .padding()
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(viewModel.userPhotos) { photo in
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
                                        
                                        if photo.isSuperstar && userName == "Me" {
                                            HStack(spacing: 6) {
                                                Text("Boost")
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Image(systemName: "arrow.up.square.fill")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 16, height: 16)
                                                    .foregroundColor(.white)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.green)
                                            .cornerRadius(20)
                                        }
                                        
                                        if let themeName = photo.themeName, let themeId = photo.themeId {
                                            ThemeBadgeClickable(themeName: themeName, themeId: themeId, competitionId: competitionId)
                                                .layoutPriority(-1)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 12)
                                }
                                .background(Color(hex: "#1A2245"))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, userName == "Me" && viewModel.userPhotos.contains(where: { $0.isSuperstar }) ? 0 : 20)
                    }
                }
            }
            .background(Color(hex: "#10183C").ignoresSafeArea())
        }
        .onAppear {
            // Force a fresh fetch when view appears
            viewModel.userPhotos = []
            viewModel.isLoading = true
            viewModel.fetchUserPhotos(userId: userId, competitionId: competitionId)
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            FullScreenPhotoView(
                photo: photo,
                userName: userName,
                competitionId: competitionId,
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
