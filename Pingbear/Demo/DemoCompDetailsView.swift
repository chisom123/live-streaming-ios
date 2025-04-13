import SwiftUI

struct DemoCompDetailsView: View {
    @StateObject private var demoViewModel = DemoEntryViewModel()
    @State private var goToMyComps = false
    @State private var isVotingPresented = false
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                HStack {
                    Button(action: {
                        goToMyComps = true
                        Analytics.shared.trackTap(
                            elementId: "back_button",
                            screenName: "demo_competition_details"
                        )
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(Color.white)
                    }
                    
                    Spacer()
                    
                    Text("besties")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .lineLimit(1)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .onAppear {
                            Analytics.shared.trackCompetition(
                                action: "view_demo",
                                competitionId: "demo-competition"
                            )
                        }
                    
                    Spacer()
                    
                    Button(action: {
                        provideDemoFeedback()
                    }) {
                        Image(systemName: "ellipsis")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                HStack(spacing: 10) {
                    Button(action: {
                        provideDemoFeedback()
                    }) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24, weight: .bold))
                            .frame(width: 45, height: 45)
                            .padding(6)
                            .foregroundColor(.white.opacity(0.5))
                            .clipShape(Circle())
                    }

                    Button(action: {
                        vote()
                        Analytics.shared.trackEntry(
                            action: "rate_demo",
                            competitionId: "demo-competition"
                        )
                    }) {
                        Text("Start Rating")
                            .frame(maxWidth: .infinity, minHeight: 45)
                            .font(.system(size: 20, weight: .bold, design: .default))
                            .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .background(Color(hex: "#FF4081"))
                            .foregroundColor(Color.white)
                            .cornerRadius(200)
                    }
                    
                    Button(action: {
                        provideDemoFeedback()
                    }) {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 24, weight: .bold))
                            .frame(width: 45, height: 45)
                            .padding(6)
                            .foregroundColor(.white.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 10)
                .background(Color(hex: "#1A2245"))
                .cornerRadius(10)
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
                
                // Leaderboard
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(demoViewModel.userLeaderboard.enumerated()), id: \.element.id) { index, userEntry in
                            VStack(spacing: 0) {
                                HStack {
                                    Text("\(index + 1)")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 30)
                                        .padding(.leading, 20)
                                    
                                    HStack(spacing: 20) {
                                        // Use the real ProfilePictureView for all users
                                        if userEntry.isCurrentUser {
                                            // For current user, use the real profile picture component
                                            ProfilePictureView(url: userEntry.profilePictureUrl, size: 40)
                                        } else {
                                            // For demo users, use real profile picture component with demo URL
                                            ProfilePictureView(url: userEntry.profilePictureUrl, size: 40)
                                        }
                                        
                                        Text(userEntry.userName)
                                            .font(.system(size: 16, weight: .bold))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 8) {
                                        Text("\(userEntry.totalStars)")
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
                                    .padding(.trailing, 30)
                                }
                                .padding(.vertical, 25)
                                .background(userEntry.isCurrentUser ? Color(hex: "#2A3255") : Color.clear)
                                
                                if userEntry.id != demoViewModel.userLeaderboard.last?.id {
                                    Divider()
                                        .background(Color.white.opacity(0.2))
                                }
                            }
                        }
                    }
                    .background(Color(hex: "#1A2245"))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                }
            }
        }
        .background(Color(hex: "#10183C"))
        .fullScreenCover(isPresented: $isVotingPresented, content: {
            DemoEntryView(viewModel: demoViewModel)
        })
        .fullScreenCover(isPresented: $goToMyComps) {
            MyCompsView()
        }
    }
    
    // Function to provide haptic feedback for disabled buttons
    private func provideDemoFeedback() {
        // This gives a 'feature unavailable' feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    func vote() {
        self.isVotingPresented = true
    }
}
