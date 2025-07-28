import SwiftUI

struct PredictionsDetailView: View {
    let parlayStatus: String
    let parlayPredictions: [String: Any]
    let parlayPayout: Int
    let parlayStake: Int
    let pendingUserProfiles: [String: (username: String, profilePictureUrl: String?)]
    let interactionService: PhotoInteractionService
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header styled like EditCompetitionView
            HStack {
                Button(action: {
                    onDismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("My Predictions")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(.white)
                
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
            .background(Color(hex: "#1A2245"))
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // Parlay Status Section
                    VStack(spacing: 12) {
                        HStack {
                            Image("Logo-T")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 25, height: 25)
                            
                            Spacer()
                            
                            parlayStatusBadge
                        }
                        .padding(.bottom)
                        
                        if parlayStatus == "pending" {
                            parlayProgressView
                        } else if parlayStatus == "won" {
                            parlayWonView
                        } else if parlayStatus == "lost" {
                            parlayLostView
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }
                .padding(.top, 20)
            }
            .background(Color(hex: "#10183C"))
        }
        .background(Color(hex: "#10183C"))
        .ignoresSafeArea()
    }
    
    private var parlayStatusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(parlayStatusColor)
                .frame(width: 8, height: 8)
            
            Text(parlayStatusText)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(parlayStatusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(parlayStatusColor.opacity(0.15))
        .cornerRadius(20)
    }
    
    private var parlayStatusColor: Color {
        switch parlayStatus {
        case "won": return Color(hex: "#00FF00")
        case "lost": return Color(hex: "#FF4444")
        default: return Color(hex: "#FFD700")
        }
    }
    
    private var parlayStatusText: String {
        switch parlayStatus {
        case "won": return "Win"
        case "lost": return "Lost"
        default: return "In Progress"
        }
    }
    
    private var parlayProgressView: some View {
        VStack(spacing: 8) {
            VStack(spacing: 8) {
                let totalPredictions = parlayPredictions.count
                let completedPredictions = parlayPredictions.values.compactMap { predictionData in
                    (predictionData as? [String: Any])?["actualRating"]
                }.count
                
                HStack {
                    Text("Correct")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    let (correct, total) = getCorrectPredictionsCount()
                    Text("\(correct)/\(total)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                HStack {
                    Text("Entry")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("\(parlayStake)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image("coin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 19, height: 19)
                    }
                }
                
                HStack {
                    Text("To Win")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("\(parlayPayout)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image("coin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 19, height: 19)
                    }
                }
                
                let profit = parlayPayout - parlayStake
                HStack {
                    Text("Profit")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Text("+\(profit)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#00FF00"))
                }
            }
            
            predictionsList
        }
    }
    
    private var parlayWonView: some View {
        VStack(spacing: 8) {
            VStack(spacing: 8) {
                HStack {
                    Text("Correct")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    let (correct, total) = getCorrectPredictionsCount()
                    Text("\(correct)/\(total)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                HStack {
                    Text("Entry")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("\(parlayStake)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image("coin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 19, height: 19)
                    }
                }
                
                HStack {
                    Text("Win")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("\(parlayPayout)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image("coin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 19, height: 19)
                    }
                }
                
                let profit = parlayPayout - parlayStake
                HStack {
                    Text("Profit")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Text("+\(profit)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#00FF00"))
                }
            }
            
            predictionsList
        }
    }
    
    private var parlayLostView: some View {
        VStack(spacing: 8) {
            VStack(spacing: 8) {
                HStack {
                    Text("Correct")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    let (correct, total) = getCorrectPredictionsCount()
                    Text("\(correct)/\(total)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                HStack {
                    Text("Entry")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("\(parlayStake)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image("coin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 19, height: 19)
                    }
                }
                
                HStack {
                    Text("Win")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("0")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image("coin")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 19, height: 19)
                    }
                }
            }
            
            predictionsList
        }
    }
    
    private var predictionsList: some View {
        VStack(spacing: 0) {
            if !parlayPredictions.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.2))
                    .padding(.vertical, 8)
                
                VStack(spacing: 0) {
                    ForEach(Array(parlayPredictions.keys.sorted()), id: \.self) { userId in
                        predictionRow(for: userId)
                        
                        if userId != Array(parlayPredictions.keys.sorted()).last {
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.leading, 50)
                        }
                    }
                }
            }
        }
    }
    
    private func predictionRow(for userId: String) -> some View {
        guard let predictionData = parlayPredictions[userId] as? [String: Any],
              let predictedRating = predictionData["predictedRating"] as? Int else {
            return AnyView(EmptyView())
        }
        
        let actualRating = predictionData["actualRating"] as? Int
        let isCorrect = predictionData["correct"] as? Bool ?? false
        
        // Get user info - try interaction first, then pending cache, then fetch
        let interaction = interactionService.interactions.first { $0.userId == userId }
        let userName: String
        let profilePictureUrl: String?
        
        if let interaction = interaction {
            // User has rated - use interaction data
            userName = interaction.userName
            profilePictureUrl = interaction.profilePictureUrl
        } else if let cachedProfile = pendingUserProfiles[userId] {
            // User hasn't rated but we have cached profile
            userName = cachedProfile.username
            profilePictureUrl = cachedProfile.profilePictureUrl
        } else {
            // Need to fetch user profile
            userName = "Friend"
            profilePictureUrl = nil
        }
        
        return AnyView(
            HStack(spacing: 12) {
                // Profile Picture
                ProfilePictureView(url: profilePictureUrl, size: 35)
                
                // User Info
                VStack(alignment: .leading, spacing: 5) {
                    Text(userName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    // Visual comparison of predicted vs actual
                    if let actualRating = actualRating {
                        HStack(alignment: .center, spacing: 0) {
                           // Main tab
                           HStack(spacing: 3) {
                               Image(systemName: "star.fill")
                                   .font(.system(size: 11))
                                   .foregroundColor(.white)
                               
                               Text("\(predictedRating)")
                                   .font(.system(size: 13, weight: .bold))
                                   .foregroundColor(.white)
                           }
                           .frame(height: 28) // Same fixed height
                           .padding(.horizontal, 8)
                           .background(
                            (isCorrect ? Color(hex: "#00FF00").opacity(0.6) : Color(hex: "#FF4444"))
                                   .clipShape(
                                       RoundedCorner(
                                           radius: 6,
                                           corners: isCorrect ? [.topLeft, .bottomLeft, .topRight, .bottomRight] : [.topLeft, .bottomLeft]
                                       )
                                   )
                           )
                           
                           // Connected side tab (only show if incorrect)
                           if !isCorrect {
                               HStack(spacing: 4) {
                                   Text("\(actualRating)")
                                       .font(.system(size: 13, weight: .bold)) // Same size as main
                                       .foregroundColor(.white.opacity(0.8))
                               }
                               .frame(height: 28) // Same fixed height
                               .padding(.horizontal, 8)
                               .background(
                                    Color.gray.opacity(0.6) // Dark grey/black background
                                       .clipShape(
                                           RoundedCorner(
                                               radius: 6,
                                               corners: [.topRight, .bottomRight]
                                           )
                                       )
                               )
                           }
                        }
                    } else {
                        HStack(spacing: 3) {
                           Image(systemName: "star.fill")
                               .font(.system(size: 11))
                               .foregroundColor(.white)
                           
                           Text("\(predictedRating)")
                               .font(.system(size: 13, weight: .bold))
                               .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(height: 28)
                        .padding(.horizontal, 8)
                        .background(
                            Color.gray.opacity(0.6)
                               .clipShape(
                                   RoundedCorner(
                                       radius: 6,
                                       corners: [.topLeft, .bottomLeft, .topRight, .bottomRight]
                                   )
                               )
                           )
                    }
                }
                
                Spacer()
                
                // Status indicator with icon
                if actualRating != nil {
                    Text(isCorrect ? "✓" : "✗")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isCorrect ? Color(hex: "#00FF00") : Color(hex: "#FF4444"))
                } else {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#FFD700"))
                }
            }
            .padding(.vertical, 8)
        )
    }
    
    private func getCorrectPredictionsCount() -> (correct: Int, total: Int) {
        var correctCount = 0
        let totalCount = parlayPredictions.count
        
        for (_, predictionData) in parlayPredictions {
            if let prediction = predictionData as? [String: Any],
               let isCorrect = prediction["correct"] as? Bool,
               isCorrect {
                correctCount += 1
            }
        }
        
        return (correctCount, totalCount)
    }
}
