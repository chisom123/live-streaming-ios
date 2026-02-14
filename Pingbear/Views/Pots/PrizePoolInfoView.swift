import SwiftUI

struct PrizePoolInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color(hex: "#10183C")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image("x")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(.white)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                    }
                    
                    Spacer()
                    
                    Text("How Prize Pools Work")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .opacity(0)
                    
                    Spacer()
                    
                    Button(action: {
                       
                    }) {
                        Image("x")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(.white)
                            .aspectRatio(contentMode: .fit)
                            .opacity(0)
                            .frame(width: 30, height: 30)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(Color(hex: "#1A2245"))
                .edgesIgnoringSafeArea(.top)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            Spacer()
                            Text("How Prize Pools Work")
                                .font(.system(size: 21, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 15)
                        
                        // Step 1
                        InfoStepView(
                            number: "1",
                            title: "Rate Photos",
                            description: "Win points by rating your friends' photos in competitions."
                        )
        
                        // Step 2
                        InfoStepView(
                            number: "2",
                            title: "Climb the Leaderboard",
                            description: "Your position is determined by your total points. The more points you win, the higher you rank."
                        )
                        
                        // Step 3
                        InfoStepView(
                            number: "3",
                            title: "Win Money",
                            description: "Top performers share the weekly prize pool. Rankings reset every week, giving everyone a fresh chance to win."
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

struct InfoStepView: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Number circle
            Text(number)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 35, height: 35)
                .background(Color(hex: "#4169E1"))
                .clipShape(Circle())
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(hex: "#1A2245"))
        .cornerRadius(12)
    }
}
