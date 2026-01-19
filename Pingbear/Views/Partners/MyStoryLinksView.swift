import SwiftUI
import FirebaseFirestore
import PhotosUI
import FirebaseStorage
import FirebaseAuth

struct MyStoryLinksView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = MyStoryLinksViewModel()
    @StateObject private var profileManager = ProfilePictureManager.shared
    @State private var selectedLinkForInstructions: RatingLink?
    @State private var userProfilePictureUrl: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    Analytics.shared.trackTap(
                        elementId: "back_button",
                        screenName: "my_story_links"
                    )
                    dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("Story Links")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                
                Spacer()
                
                Color.clear
                    .frame(width: 27, height: 27)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            
            // Content
            if viewModel.isInitialDataLoad && viewModel.assignedLinks.isEmpty {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                }
                .frame(maxHeight: .infinity)
            } else if !hasProfilePicture {
                // Profile picture required state
                VStack(spacing: 20) {
                    Text("Profile Picture Required")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Please upload a profile picture to access your story links")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    VStack(spacing: 16) {
                        ProfilePictureView(url: profileManager.currentProfileUrl ?? userProfilePictureUrl, size: 100)
                        
                        ProfilePictureSelector(onUpdateSuccess: { newUrl in
                            userProfilePictureUrl = newUrl
                            profileManager.currentProfileUrl = newUrl
                            Analytics.shared.track(
                                event: "profile_picture_uploaded_from_links",
                                properties: ["has_url": !newUrl.isEmpty]
                            )
                        })
                    }
                    .padding(.top, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 40)
                .background(Color(hex: "#1A2245"))
                .cornerRadius(14)
                .padding(.horizontal, 20)
                .frame(maxHeight: .infinity)
            } else if viewModel.assignedLinks.isEmpty {
                // Empty state - no ScrollView needed
                VStack(spacing: 20) {
                    Image("link")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.white.opacity(0.5))
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                    
                    Text("No Story Links Yet")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Links assigned to you will appear here")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxHeight: .infinity)
            } else {
                // Links list - wrapped in ScrollView
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(viewModel.assignedLinks.sorted(by: { $0.createdAt > $1.createdAt })) { link in
                            MyStoryLinkCard(
                                link: link,
                                recruiterName: viewModel.getRecruiterName(for: link),
                                onUseLink: {
                                    selectedLinkForInstructions = link
                                    
                                    Analytics.shared.trackTap(
                                        elementId: "use_story_link_button",
                                        screenName: "my_story_links",
                                        properties: [
                                            "link_id": link.id,
                                            "link_rating_count": link.ratingCount,
                                            "link_average_rating": link.averageRating,
                                            "recruiter_id": link.recruiterId,
                                            "has_photo": link.photoUrl != nil
                                        ]
                                    )
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
        }
        .background(Color(hex: "#10183C"))
        .onAppear {
            fetchUserProfilePicture()
            
            let totalRatings = viewModel.assignedLinks.reduce(0) { $0 + $1.ratingCount }
            
            Analytics.shared.trackScreen(
                name: "my_story_links",
                properties: [
                    "total_assigned_links": viewModel.assignedLinks.count,
                    "total_ratings": totalRatings,
                    "links_with_photos": viewModel.assignedLinks.filter { $0.photoUrl != nil }.count,
                    "has_profile_picture": hasProfilePicture
                ]
            )
            
            viewModel.loadData()
        }
        .sheet(item: $selectedLinkForInstructions) { link in
            MyStoryLinkInstructionsView(link: link, viewModel: viewModel)
        }
    }
    
    private var hasProfilePicture: Bool {
        let url = profileManager.currentProfileUrl ?? userProfilePictureUrl
        return url != nil && !url!.isEmpty
    }
    
    private func fetchUserProfilePicture() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        Firestore.firestore().collection("users").document(userId).getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                self.userProfilePictureUrl = data?["profilePictureUrl"] as? String
                self.profileManager.currentProfileUrl = self.userProfilePictureUrl
            }
        }
    }
}

struct MyStoryLinkCard: View {
    let link: RatingLink
    let recruiterName: String?
    let onUseLink: () -> Void
    
    @State private var hasTrackedView = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                // Show who created it
                if let recruiterName = recruiterName {
                    HStack(spacing: 4) {
                        Text("Link from \(recruiterName)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                Text(timeAgoString(from: link.createdAt))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 10)
            
            HStack(spacing: 16) {
                // Rating Section
                VStack(alignment: .center, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("\(link.averageRating, specifier: "%.1f")")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(link.hasRatings ? .orange : .gray)
                        
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Text("★")
                                    .font(.system(size: 14))
                                    .foregroundColor(link.hasRatings && Double(star) <= link.averageRating.rounded() ? .orange : .gray.opacity(0.5))
                            }
                        }
                    }
                    
                    Text("\(link.ratingCount) rating\(link.ratingCount != 1 ? "s" : "")")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
            
            // Use Link Button
            Button(action: {
                onUseLink()
            }) {
                Text("Use Link")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color(hex: "#4169E1"))
                    .foregroundColor(.white)
                    .cornerRadius(200)
            }
        }
        .padding()
        .background(Color(hex: "#1A2245"))
        .cornerRadius(8)
        .onAppear {
            if !hasTrackedView {
                Analytics.shared.track(
                    event: "story_link_card_viewed",
                    properties: [
                        AnalyticsProperty.screenName: "my_story_links",
                        "link_id": link.id,
                        "link_rating_count": link.ratingCount,
                        "link_average_rating": link.averageRating,
                        "link_age_days": Calendar.current.dateComponents([.day], from: link.createdAt, to: Date()).day ?? 0,
                        "has_ratings": link.hasRatings,
                        "has_photo": link.photoUrl != nil,
                        "recruiter_id": link.recruiterId
                    ]
                )
                hasTrackedView = true
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let diff = now.timeIntervalSince(date)
        
        let minutes = Int(diff / 60)
        let hours = Int(diff / 3600)
        let days = Int(diff / 86400)
        
        if minutes < 1 {
            return "Just now"
        } else if minutes < 60 {
            return "\(minutes)m ago"
        } else if hours < 24 {
            return "\(hours)h ago"
        } else {
            return "\(days)d ago"
        }
    }
}
