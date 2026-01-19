import SwiftUI
import FirebaseFirestore
import PhotosUI
import FirebaseStorage

struct RecruitsView: View {
    @StateObject private var viewModel = RecruitsViewModel()
    @State private var showAssignFriendSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Color.clear
                        .frame(width: 30, height: 30)
                    
                    Spacer()
                    
                    Text("Stories")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    Button(action: {
                        showAssignFriendSheet = true
                        
                        Analytics.shared.trackTap(
                            elementId: "add_link_toolbar_button",
                            screenName: "recruits",
                            properties: [
                                "total_links": viewModel.ratingLinks.count
                            ]
                        )
                    }) {
                        Image(systemName: "plus.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                            .foregroundColor(Color.white)
                    }
                    .disabled(viewModel.isLoading)
                    .opacity(viewModel.isLoading ? 0.6 : 1.0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                
                // Content
                if viewModel.isInitialDataLoad && viewModel.ratingLinks.isEmpty {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                    }
                    .frame(maxHeight: .infinity)
                } else if viewModel.ratingLinks.isEmpty {
                    // Empty state - no ScrollView needed
                    VStack(spacing: 0) {
                        // Header
                        Text("No Story Links Yet")
                            .font(.system(size: 21, weight: .bold, design: .default))
                            .foregroundColor(.white)
                            .padding(.top, 30)
                            .padding(.bottom, 30)
                        
                        // Button container - fixed width for consistency
                        VStack() {
                            Button(action: {
                                showAssignFriendSheet = true
                                
                                Analytics.shared.trackTap(
                                    elementId: "create_first_link_button",
                                    screenName: "recruits",
                                    properties: [
                                        "total_links": viewModel.ratingLinks.count
                                    ]
                                )
                            }) {
                                HStack {
                                    Text("New Story")
                                        .font(.system(size: 17, weight: .bold, design: .default))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(viewModel.isLoading ? Color(hex: "#4169E1").opacity(0.5) : Color(hex: "#4169E1"))
                                .foregroundColor(viewModel.isLoading ? .white.opacity(0.6) : .white)
                                .cornerRadius(25)
                            }
                            .disabled(viewModel.isLoading)
                        }
                        .frame(width: 280)
                        .padding(.bottom, 30)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .background(Color(hex: "#1A2245"))
                    .cornerRadius(14)
                    .padding(.horizontal, 20)
                    .frame(maxHeight: .infinity)
                } else {
                    // Links list - wrapped in ScrollView
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(viewModel.ratingLinks.sorted(by: { $0.createdAt > $1.createdAt })) { link in
                                RecruitLinkCard(
                                    link: link,
                                    assignedUserName: viewModel.getAssignedUserName(for: link),
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                        .padding(.top, 8)
                    }
                }
            }
            .background(Color(hex: "#10183C"))
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            let totalRatings = viewModel.ratingLinks.reduce(0) { $0 + $1.ratingCount }
            
            Analytics.shared.trackScreen(
                name: "recruits",
                properties: [
                    "total_links": viewModel.ratingLinks.count,
                    "total_ratings": totalRatings,
                    "average_ratings_per_link": viewModel.ratingLinks.isEmpty ? 0 : Double(totalRatings) / Double(viewModel.ratingLinks.count)
                ]
            )
            
            viewModel.loadData()
        }
        .sheet(isPresented: $showAssignFriendSheet) {
            AssignLinkToFriendView { selectedFriend in
                viewModel.createNewLink(for: selectedFriend) { newLink in
                    if let link = newLink {
                        Analytics.shared.track(
                            event: viewModel.ratingLinks.count == 1 ? "first_link_created" : "link_created",
                            properties: [
                                AnalyticsProperty.screenName: "recruits",
                                "link_id": link.id,
                                "link_title": link.title,
                                "total_links_after": viewModel.ratingLinks.count,
                                "assigned_user_id": link.assignedUserId ?? "",
                                "assigned_user_name": selectedFriend.name
                            ]
                        )
                    }
                }
            }
        }
    }
}

struct RecruitLinkCard: View {
    let link: RatingLink
    let assignedUserName: String?
    @State private var hasTrackedView = false
    @FocusState private var isTitleFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    // Show assigned user
                    if let userName = assignedUserName {
                        HStack(spacing: 4) {
                            Text("Assigned to \(userName)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    Text(timeAgoString(from: link.createdAt))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gray)
                }
                
                Spacer()
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
        }
        .padding()
        .background(Color(hex: "#1A2245"))
        .cornerRadius(10)
        .onAppear {
            if !hasTrackedView {
                Analytics.shared.track(
                    event: "link_card_viewed",
                    properties: [
                        AnalyticsProperty.screenName: "recruits",
                        "link_id": link.id,
                        "link_rating_count": link.ratingCount,
                        "link_average_rating": link.averageRating,
                        "link_age_days": Calendar.current.dateComponents([.day], from: link.createdAt, to: Date()).day ?? 0,
                        "has_ratings": link.hasRatings,
                        "has_photo": link.photoUrl != nil,
                        "assigned_user_id": link.assignedUserId ?? ""
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
