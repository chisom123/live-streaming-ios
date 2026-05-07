import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Kingfisher

struct ThemePhotosView: View {
    let themeName: String; let themeId: String; let competitionId: String
    @StateObject private var viewModel = ThemePhotosViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: ThemePhoto? = nil
    @State private var showingPredictionsView = false
    @State private var selectedPhotoForPredictions: ThemePhoto? = nil
    @StateObject private var interactionService = PhotoInteractionService()
    @State private var pendingUserProfiles: [String: (username: String, profilePictureUrl: String?)] = [:]
    private let db = Firestore.firestore()

    init(themeName: String, themeId: String, competitionId: String) {
        self.themeName = themeName; self.themeId = themeId; self.competitionId = competitionId
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left").resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27).foregroundColor(AppTheme.iconColor)
                    }
                    Spacer()
                    Text(themeName).font(.system(size: 18, weight: .bold, design: .default))
                        .multilineTextAlignment(.center).lineSpacing(10).foregroundColor(AppTheme.primaryText)
                        .truncationMode(.tail).lineLimit(1).padding(.horizontal)
                    Spacer()
                    Image(systemName: "arrow.left").resizable().aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27).foregroundColor(.clear)
                }
                .padding(.horizontal, 20).padding(.vertical, 20)
                .background(AppTheme.cardBackground)

                if viewModel.isLoading && viewModel.themePhotos.isEmpty {
                    Spacer(); ProgressView().progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryText)); Spacer()
                } else if viewModel.themePhotos.isEmpty && !viewModel.isLoading {
                    Spacer()
                    Text("No Photos Yet").font(.system(size: 18, weight: .bold, design: .default)).foregroundColor(AppTheme.primaryText).padding()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.themePhotos) { photo in
                                ThemePhotoCard(photo: photo, competitionId: competitionId, isEntryCreator: isEntryCreator(photo: photo),
                                    onTap: { selectedPhoto = photo },
                                    onPredictionsTap: {
                                        selectedPhotoForPredictions = photo; loadPredictionsData(for: photo)
                                        showingPredictionsView = true
                                        Analytics.shared.track(event: "my_predictions_button_tapped_from_theme")
                                    }
                                )
                                .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                            }
                            if viewModel.hasMorePhotos {
                                LoadMoreButton(isLoading: viewModel.isLoadingMore, onLoadMore: { viewModel.loadMorePhotos() })
                                    .padding(.vertical, 20)
                            }
                        }
                        .padding(.horizontal, 20).padding(.top, 20)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Text(errorMessage).font(.system(size: 14)).foregroundColor(.red)
                            .padding(.horizontal).padding(.vertical, 8).background(Color.red.opacity(0.1)).cornerRadius(8)
                    }.padding().transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
        }
        .onAppear { viewModel.fetchThemePhotos(themeId: themeId, competitionId: competitionId) }
        .fullScreenCover(item: $selectedPhoto) { photo in
            let userPhoto = UserPhoto(id: photo.id, photoUrl: photo.photoUrl, stars: photo.stars, isSuperstar: photo.isSuperstar,
                creationDate: photo.creationDate, themeName: photo.themeName, themeId: photo.themeId, overlayText: photo.overlayText,
                overlayVerticalPosition: photo.overlayVerticalPosition, isFromCamera: photo.isFromCamera, userId: photo.userId,
                parlayStatus: photo.parlayStatus, parlayPredictions: photo.parlayPredictions, parlayPayout: photo.parlayPayout, parlayStake: photo.parlayStake)
            let currentUserId = Auth.auth().currentUser?.uid
            let displayUserName = (photo.userId == currentUserId) ? "Me" : photo.userName
            FullScreenPhotoView(photo: userPhoto, userName: displayUserName, competitionId: competitionId,
                userProfilePictureUrl: photo.profilePictureUrl,
                onDismiss: { updatedStarCount in viewModel.updatePhotoStars(photoId: photo.id, newStarCount: updatedStarCount) })
        }
    }

    private func isEntryCreator(photo: ThemePhoto) -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return photo.userId == currentUserId
    }

    private func loadPredictionsData(for photo: ThemePhoto) {
        interactionService.loadRatingData(competitionId: competitionId, entryId: photo.id)
        interactionService.fetchInteractions(competitionId: competitionId, entryId: photo.id)
        if let predictions = photo.parlayPredictions {
            for userId in predictions.keys {
                if !interactionService.interactions.contains(where: { $0.userId == userId }) { fetchUserProfileForPendingUser(userId: userId) }
            }
        }
    }

    private func fetchUserProfileForPendingUser(userId: String) {
        guard pendingUserProfiles[userId] == nil else { return }
        db.collection("users").document(userId).getDocument { document, error in
            if let data = document?.data(), let username = data["name"] as? String {
                let profilePictureUrl = data["profilePictureUrl"] as? String
                DispatchQueue.main.async { self.pendingUserProfiles[userId] = (username: username, profilePictureUrl: profilePictureUrl) }
            }
        }
    }
}

struct ThemePhotoCard: View {
    let photo: ThemePhoto; let competitionId: String; let isEntryCreator: Bool
    let onTap: () -> Void; let onPredictionsTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            KFImage(URL(string: photo.photoUrl))
                .placeholder {
                    Rectangle().fill(AppTheme.cardHighlight).frame(height: 180)
                        .overlay(ProgressView().progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryText)))
                }
                .onFailure { _ in }.resizable().aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity).frame(height: 180).clipped()
                .overlay(
                    VStack {
                        HStack {
                            Spacer()
                            Text(timeAgoString(from: photo.creationDate)).font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.primaryText).padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.black.opacity(0.6)).cornerRadius(15)
                        }.padding(10)
                        Spacer()
                    }, alignment: .bottomLeading
                )
                .contentShape(Rectangle()).onTapGesture { onTap() }

            HStack(spacing: 8) {
                HStack(spacing: 12) {
                    ProfilePictureView(url: photo.profilePictureUrl, size: 30)
                    Text(photo.userId == Auth.auth().currentUser?.uid ? "Me" : photo.userName)
                        .font(.system(size: 16, weight: .bold)).foregroundColor(AppTheme.primaryText).truncationMode(.tail).lineLimit(1)
                }
                Spacer()
                HStack(spacing: 6) {
                    Text("\(photo.stars)").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    Image(systemName: "star.fill").resizable().scaledToFit().frame(width: 16, height: 16).foregroundColor(.white)
                }
                .padding(.horizontal, 10).padding(.vertical, 5).background(AppTheme.gold).cornerRadius(20)
            }
            .padding(.horizontal, 15).padding(.vertical, 12)
            .background(AppTheme.cardBackground)
        }
        .background(AppTheme.cardBackground).cornerRadius(10)
    }

    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date); let seconds = Int(interval); let minutes = seconds / 60
        let hours = minutes / 60; let days = hours / 24; let weeks = days / 7; let months = days / 30; let years = days / 365
        if years > 0 { return years == 1 ? "1 year ago" : "\(years) years ago" }
        else if months > 0 { return months == 1 ? "1 month ago" : "\(months) months ago" }
        else if weeks > 0 { return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago" }
        else if days > 0 { return days == 1 ? "1 day ago" : "\(days) days ago" }
        else if hours > 0 { return hours == 1 ? "1h ago" : "\(hours)h ago" }
        else if minutes > 0 { return minutes == 1 ? "1m ago" : "\(minutes)m ago" }
        else { return "Just now" }
    }
}

struct LoadMoreButton: View {
    let isLoading: Bool; let onLoadMore: () -> Void
    var body: some View {
        Button(action: onLoadMore) {
            HStack {
                if isLoading { ProgressView().scaleEffect(0.8).tint(AppTheme.primaryText); Text("Loading...") }
                else { Image(systemName: "arrow.down.circle").font(.system(size: 16)); Text("Load More") }
            }
            .font(.system(size: 14, weight: .medium)).foregroundColor(AppTheme.primaryText)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 20).fill(AppTheme.cardHighlight))
        }
        .disabled(isLoading)
    }
}
