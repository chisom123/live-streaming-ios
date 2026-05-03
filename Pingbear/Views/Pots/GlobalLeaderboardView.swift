import SwiftUI
import FirebaseAuth

struct GlobalLeaderboardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = GlobalLeaderboardViewModel()
    @StateObject private var walletViewModel = WalletViewModel()
    @Binding var selectedTab: Int
    @State private var showPrizePoolInfo = false
    @State private var showRedeemCode = false
    
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
                    Spacer()
                   
                    VStack(spacing: 20) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 64))
                            .foregroundColor(Color(hex: "#FFD700"))
                        
                        Text("Join the $\(Int(ceil(viewModel.maxPrizePool))) Prize Pool")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Win points in photo competitions")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        Button(action: {
                            showPrizePoolInfo = true
                            Analytics.shared.trackTap(
                                elementId: "learn_more_cta",
                                screenName: "global_leaderboard"
                            )
                        }) {
                            Text("Learn More")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 200, height: 50)
                                .background(Color(hex: "#4169E1"))
                                .cornerRadius(200)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 40)
                    .background(Color(hex: "#1A2245"))
                    .cornerRadius(14)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                } else {
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
                                        
                                        Text("$\(Int(ceil(viewModel.potMaxPrizePool)))")
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
                            
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(Array(viewModel.participants.prefix(50).enumerated()), id: \.element.id) { index, participant in
                                        VStack(spacing: 0) {
                                            HStack {
                                                Text("\(participant.position)")
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .frame(width: 30)
                                                    .padding(.leading, 20)
                                                
                                                HStack(spacing: 20) {
                                                    ProfilePictureView(url: participant.profilePictureUrl, size: 40)
                                                    
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(participant.isCurrentUser ? "Me" : participant.username)
                                                            .font(.system(size: 16, weight: .bold))
                                                            .lineLimit(1)
                                                            .truncationMode(.tail)
                                                            .foregroundColor(.white)
                                                        
                                                        if participant.prize > 0 {
                                                            Text("$\(String(format: "%.2f", participant.prize))")
                                                                .font(.system(size: 14, weight: .bold))
                                                                .foregroundColor(.white)
                                                                .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                                                                .background(Color(hex: "#00AA00"))
                                                                .cornerRadius(200)
                                                        }
                                                    }
                                                }
                                                
                                                Spacer()
                                                
                                                VStack(alignment: .trailing, spacing: 8) {
                                                    HStack(spacing: 8) {
                                                        Text("\(participant.totalStars)")
                                                            .font(.system(size: 17, weight: .bold))
                                                            .foregroundColor(Color(hex: "#FFF"))
                                                            .lineLimit(1)
                                                        
                                                        Image("gem")
                                                            .resizable()
                                                            .renderingMode(.template)
                                                            .foregroundColor(Color.white)
                                                            .aspectRatio(contentMode: .fit)
                                                            .frame(width: 18, height: 18)
                                                    }
                                                    .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                                                    .background(Color(hex: "#6A5ACD"))
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
                                .padding(.bottom, 100)
                            }
                        }
                        
                        // Fixed User Stats Bar at Bottom
                        VStack {
                            Spacer()
                            
                            HStack(spacing: 16) {
                                Text("\(viewModel.userPosition > 0 ? String(viewModel.userPosition) : "--")")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 35)
                                
                                if let currentUser = viewModel.participants.first(where: { $0.isCurrentUser }) {
                                    ProfilePictureView(url: currentUser.profilePictureUrl, size: 40)
                                } else {
                                    Circle()
                                        .fill(Color.gray)
                                        .frame(width: 40, height: 40)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Me")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    if viewModel.userPrize > 0 {
                                        Text("$\(String(format: "%.2f", viewModel.userPrize))")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                                            .background(Color(hex: "#00AA00"))
                                            .cornerRadius(200)
                                    }
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 6) {
                                    Text("\(viewModel.userStars)")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(Color(hex: "#FFF"))
                                    
                                    Image("gem")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(Color.white)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 18, height: 18)
                                }
                                .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                                .background(Color(hex: "#6A5ACD"))
                                .cornerRadius(200)
                            }
                            .padding(20)
                            .background(Color(hex: "#2A3255"))
                        }
                    }
                }
            }
            .background(Color(hex: "#10183C"))
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showPrizePoolInfo) {
            PrizePoolInfoView()
        }
        .fullScreenCover(isPresented: $showRedeemCode) {
            RedeemWinCodeView(onSuccess: {
                viewModel.loadLeaderboard()
            })
        }
        .onReceive(NotificationCenter.default.publisher(for: .winCodeRedeemed)) { _ in
            viewModel.loadLeaderboard()
        }
        .onAppear {
            viewModel.loadLeaderboard()
//            walletViewModel.loadWalletData()
        }
    }
}
