import SwiftUI

struct PotHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PotHistoryViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .resizable() // Allows resizing of the image
                        .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                        .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                        .foregroundColor(Color.white) // Your desired color
                }
                
                Spacer()
                
                Text("My Prize Pool History")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .onAppear {
                        Analytics.shared.trackScreen(name: "pot_history")
                    }
                
                Spacer()
                
                Button(action: {
                 
                }) {
                    Image(systemName: "arrow.left")
                        .resizable() // Allows resizing of the image
                        .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                        .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                        .foregroundColor(Color.white) // Your desired color
                }
                .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            
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
            } else if viewModel.pastPots.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "trophy")
                        .font(.system(size: 64))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("No Past Prize Pools")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Your prize pool history will appear here")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(viewModel.pastPots) { pot in
                            PotHistoryCard(pot: pot)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .background(Color(hex: "#10183C"))
        .navigationBarHidden(true)
        .onAppear {
            viewModel.loadPotHistory()
        }
    }
}

struct PotHistoryCard: View {
    let pot: PotHistoryViewModel.PastPotParticipation
    
    private var statusText: String {
        guard let status = pot.potStatus else { return "Unknown" }
        if status == "active" {
            return "Active"
        } else if status == "closed" {
            return "Ended"
        }
        return status.capitalized
    }
    
    private var statusColor: Color {
        guard let status = pot.potStatus else { return .gray }
        if status == "active" {
            return Color(hex: "#00AA00")
        } else if status == "closed" {
            return Color.white.opacity(0.5)
        }
        return .gray
    }
    
    private var endDateText: String {
        guard let endDate = pot.potEndDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: endDate)
    }
    
    private var isEndDateInFuture: Bool {
        guard let endDate = pot.potEndDate else { return false }
        return endDate > Date()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with status and date
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(statusText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(statusColor)
                        .cornerRadius(200)
                    
                    Spacer()
                    
                    if let endDate = pot.potEndDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                            
                            Text("\(isEndDateInFuture ? "Ends" : "Ended") \(endDateText)")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(16)
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Stats section - Grid layout to prevent overlap
            VStack(spacing: 12) {
                // Row 1: Stars and Rank
                HStack(spacing: 12) {
                    // Stars earned
                    StatCard(
                        icon: "gem_icon",
                        iconColor: Color(hex: "#FFF"),
                        value: "\(pot.totalStars)",
                        label: "Points"
                    )
                    
                    // Rank (if available)
                    if let finalRank = pot.finalRank {
                        StatCard(
                            icon: finalRank <= 3 ? "trophy.fill" : "medal.fill",
                            iconColor: Color(hex: "#FFF"),
                            value: "#\(finalRank)",
                            label: "Rank"
                        )
                    } else {
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Row 2: Prize (if applicable)
                if let prize = pot.prizeAmount, prize > 0 {
                    HStack(spacing: 12) {
                        StatCard(
                            icon: "gift.fill",
                            iconColor: Color(hex: "#FFF"),
                            value: "$\(String(format: "%.2f", prize))",
                            label: "Prize Won"
                        )
                        
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(hex: "#1A2245"))
        .cornerRadius(12)
    }
}

// Reusable stat card component
struct StatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 10) {
            // Use custom gem image for star.fill, otherwise use SF Symbol
            if icon == "gem_icon" {
                Image("gem")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(iconColor)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                    .frame(width: 24)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}
