import SwiftUI
import FirebaseAuth

struct GlobalLeaderboardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = GlobalLeaderboardViewModel()
    @StateObject private var walletViewModel = WalletViewModel()
    @Binding var selectedTab: Int
    @State private var showStatsBar = true
    @State private var initialOffset: CGFloat?
    
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    NavigationLink(destination: WalletView()) {
                        ZStack(alignment: .topTrailing) {
                            Image("wallet")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(Color.white)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 30, height: 30)
                            
                            // Red badge indicator
                            if walletViewModel.balance > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 14, height: 14)
                                    .offset(x: 3, y: -3)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Text("Prizes")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .onAppear {
                            Analytics.shared.trackScreen(name: "global_leaderboard")
                        }
                    
                    Spacer()
                    
                    // Add history button
                    NavigationLink(destination: PotHistoryView()) {
                        Image(systemName: "clock.arrow.circlepath")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                            .foregroundColor(Color.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text(error)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                } else if !viewModel.isInPot {
                    // User not in pot yet
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 64))
                            .foregroundColor(Color(hex: "#FFD700"))
                        
                        Text("Join the $\(String(format: "%.0f", viewModel.firstPlacePrize)) Prize Pool!")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Get your first rating to enter the weekly prize pool")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        // Start Playing Button
                        Button(action: {
                            selectedTab = 0  // Switch to My Comps tab
                            Analytics.shared.trackTap(
                                elementId: "start_playing_cta",
                                screenName: "global_leaderboard"
                            )
                        }) {
                            Text("Start Playing")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 200, height: 50)
                                .background(Color(hex: "#4169E1"))
                                .cornerRadius(25)
                        }
                    }
                    Spacer()
                } else {
                    // Show leaderboard
                    ZStack {
                        VStack(spacing: 20) {
                            // Pot Info Card
                            VStack(spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Prize Pool")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.7))
                                            .padding(.bottom, 2)
                                        
                                        Text("$\(String(format: "%.0f", viewModel.totalPrizePool))")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(Color(hex: "#FFF"))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 3)
                                            .background(Color(hex: "#00AA00"))
                                            .cornerRadius(12)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Ends In")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.7))
                                            .padding(.bottom, 2)
                                        
                                        Text(viewModel.timeRemaining)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .padding(20)
                            .background(Color(hex: "#1A2245"))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            
                            // Track the scroll offset using overlay
                            ScrollView {
                                ScrollViewOffsetTracker()
                                    .onScrollOffsetChange { offset in
                                        handleScrollOffset(offset)
                                    }
                                
                                // Leaderboard - styled identical to CompDetails
                                VStack(spacing: 0) {
                                    ForEach(Array(viewModel.participants.prefix(50).enumerated()), id: \.element.id) { index, participant in
                                        VStack(spacing: 0) {
                                            HStack {
                                                // Position (1, 2, 3, 4, 5...)
                                                Text("\(participant.position)")
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .frame(width: 30)
                                                    .padding(.leading, 20)
                                                
                                                HStack(spacing: 20) {
                                                    // Profile Picture
                                                    ProfilePictureView(url: participant.profilePictureUrl, size: 40)
                                                    
                                                    // Username
                                                    Text(participant.isCurrentUser ? "Me" : participant.username)
                                                        .font(.system(size: 16, weight: .bold))
                                                        .lineLimit(1)
                                                        .truncationMode(.tail)
                                                        .foregroundColor(.white)
                                                }
                                                
                                                Spacer()
                                                
                                                VStack(alignment: .trailing, spacing: 8) {
                                                    // Prize badge (if applicable) - shows split prize
                                                    if participant.prize > 0 {
                                                        Text("$\(String(format: "%.2f", participant.prize))")
                                                            .font(.system(size: 17, weight: .bold))
                                                            .foregroundColor(Color(hex: "#FFF"))
                                                            .lineLimit(1)
                                                            .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                                                            .background(Color(hex: "#00AA00"))
                                                            .cornerRadius(200)
                                                    }
                                                    
                                                    // Stars badge
                                                    HStack(spacing: 8) {
                                                        Text("\(participant.totalStars)")
                                                            .font(.system(size: 17, weight: .bold))
                                                            .foregroundColor(Color(hex: "#FFF"))
                                                            .lineLimit(1)
                                                        
                                                        Image(systemName: "star.fill")
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: 18, height: 18)
                                                            .foregroundColor(Color(hex: "#FFF"))
                                                    }
                                                    .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                                                    .background(Color(hex: "#DAA520"))
                                                    .cornerRadius(200)
                                                }
                                                .padding(.trailing, 20)
                                            }
                                            .padding(.vertical, 25)
                                            .background(participant.isCurrentUser ? Color(hex: "#2A3255") : Color.clear)
                                            
                                            if index < min(49, viewModel.participants.count - 1) {
                                                Divider()
                                                    .background(Color.white.opacity(0.2))
                                            }
                                        }
                                    }
                                }
                                .background(Color(hex: "#1A2245"))
                                .cornerRadius(10)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20) // Add padding for fixed bottom bar
                            }
                        }
                        
                        // Fixed User Stats Bar at Bottom
                        VStack {
                            Spacer()
                            
                            HStack(spacing: 16) {
                                // Left side: Position number
                                Text("\(viewModel.userPosition > 0 ? String(viewModel.userPosition) : "--")")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 35)
                                
                                // Profile Picture
                                if let currentUser = viewModel.participants.first(where: { $0.isCurrentUser }) {
                                    ProfilePictureView(url: currentUser.profilePictureUrl, size: 40)
                                } else {
                                    Circle()
                                        .fill(Color.gray)
                                        .frame(width: 40, height: 40)
                                }
                                
                                // "Me" text
                                Text("Me")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                // Right side: Prize and Stars
                                HStack(spacing: 8) {
                                    if viewModel.userPrize > 0 {
                                        Text("$\(String(format: "%.2f", viewModel.userPrize))")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(Color(hex: "#FFF"))
                                            .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                                            .background(Color(hex: "#00AA00"))
                                            .cornerRadius(200)
                                    }
                                    
                                    HStack(spacing: 6) {
                                        Text("\(viewModel.userStars)")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(Color(hex: "#FFF"))
                                        
                                        Image(systemName: "star.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 18, height: 18)
                                            .foregroundColor(Color(hex: "#FFF"))
                                    }
                                    .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                                    .background(Color(hex: "#DAA520"))
                                    .cornerRadius(200)
                                }
                            }
                            .padding(20)
                            .background(Color(hex: "#2A3255"))
                        }
                        .offset(y: showStatsBar ? 0 : 100) // Animate off screen when hidden
                        .animation(.easeInOut(duration: 0.3), value: showStatsBar)
                        .opacity(showStatsBar ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: showStatsBar)
                    }
                }
            }
            .background(Color(hex: "#10183C"))
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.loadLeaderboard()
            walletViewModel.loadWalletData()
            // Reset initial offset when view appears
            initialOffset = nil
        }
    }
    
    private func handleScrollOffset(_ offset: CGFloat) {
        // Set initial offset on first call
        if initialOffset == nil {
            initialOffset = offset
            return
        }
        
        guard let baseOffset = initialOffset else { return }
        
        // Calculate relative scroll distance from initial position
        let relativeOffset = baseOffset - offset
        let threshold: CGFloat = 50 // Hide after scrolling 50 points down
        
        if relativeOffset > threshold && showStatsBar {
            // Scrolling down, hide the bar
            withAnimation(.easeInOut(duration: 0.3)) {
                showStatsBar = false
            }
        } else if relativeOffset <= threshold && !showStatsBar {
            // Scrolling up or at top, show the bar
            withAnimation(.easeInOut(duration: 0.3)) {
                showStatsBar = true
            }
        }
    }
}

// Helper view to track scroll offset
struct ScrollViewOffsetTracker: View {
    var onScrollOffsetChange: ((CGFloat) -> Void)?
    
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(
                    key: ScrollOffsetKey.self,
                    value: geometry.frame(in: .global).minY
                )
        }
        .frame(height: 0)
        .onPreferenceChange(ScrollOffsetKey.self) { offset in
            onScrollOffsetChange?(offset)
        }
    }
}

// Key for tracking scroll offset
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// Extension for easier use
extension View {
    func onScrollOffsetChange(_ action: @escaping (CGFloat) -> Void) -> some View {
        self.background(
            ScrollViewOffsetTracker(onScrollOffsetChange: action)
        )
    }
}
