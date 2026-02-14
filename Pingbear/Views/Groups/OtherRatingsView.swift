import SwiftUI
import FirebaseAuth

struct OtherRatingsView: View {
    let interactions: [PhotoInteraction]
    @Environment(\.dismiss) private var dismiss
    
    private var otherRatings: [PhotoInteraction] {
        // Filter out current user
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return interactions
        }
        return interactions.filter { $0.userId != currentUserId }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("Other Ratings")
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
            ZStack {
                Color(hex: "#10183C")
                    .ignoresSafeArea()
                
                if otherRatings.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "star.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text("No other ratings yet")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else {
                    // Ratings list
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(otherRatings) { interaction in
                                ratingRow(interaction: interaction)
                                
                                if interaction.id != otherRatings.last?.id {
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                }
                            }
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .background(Color(hex: "#10183C"))
        .ignoresSafeArea()
    }
    
    private func ratingRow(interaction: PhotoInteraction) -> some View {
        HStack(spacing: 16) {
            // Profile picture
            ProfilePictureView(url: interaction.profilePictureUrl, size: 44)
            
            // Name and timestamp
            VStack(alignment: .leading, spacing: 4) {
                Text(interaction.userName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text(timeAgo(from: interaction.ratedAt))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(-1)
            
            // Rating and points badges side by side
            HStack(spacing: 8) {
                // Star rating badge
                HStack(spacing: 4) {
                    Text("\(interaction.rating)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#FFF"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: "#DAA520"))
                .cornerRadius(200)
                
                // Points badge
                HStack(spacing: 4) {
                    Text("\(interaction.points)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    
                    Image("gem")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.white)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: "#6A5ACD"))
                .cornerRadius(200)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    private func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfYear], from: date, to: now)
        
        if let weeks = components.weekOfYear, weeks > 0 {
            return weeks == 1 ? "1w ago" : "\(weeks)w ago"
        } else if let days = components.day, days > 0 {
            return days == 1 ? "1d ago" : "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1h ago" : "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1m ago" : "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
}
