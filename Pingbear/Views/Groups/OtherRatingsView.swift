import SwiftUI
import FirebaseAuth

struct OtherRatingsView: View {
    let interactions: [PhotoInteraction]
    @Environment(\.dismiss) private var dismiss
    
    private var currentUserRating: PhotoInteraction? {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return nil
        }
        return interactions.first { $0.userId == currentUserId }
    }
    
    private var otherRatings: [PhotoInteraction] {
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
                
                Text("Ratings")
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
                
                if interactions.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "star.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text("No ratings yet")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else {
                    // Ratings list
                    ScrollView {
                        VStack(spacing: 0) {
                            // Current user's rating (if exists)
                            if let currentRating = currentUserRating {
                                ratingRow(interaction: currentRating, isCurrentUser: true)
                                
                                if !otherRatings.isEmpty {
                                    Divider()
                                        .background(Color.white.opacity(0.2))
                                }
                            }
                            
                            // Other users' ratings
                            ForEach(Array(otherRatings.enumerated()), id: \.element.id) { index, interaction in
                                ratingRow(interaction: interaction, isCurrentUser: false)
                                
                                if index < otherRatings.count - 1 {
                                    Divider()
                                        .background(Color.white.opacity(0.2))
                                }
                            }
                        }
                        .background(Color(hex: "#1A2245"))
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .background(Color(hex: "#10183C"))
        .ignoresSafeArea()
    }
    
    private func ratingRow(interaction: PhotoInteraction, isCurrentUser: Bool) -> some View {
        HStack(spacing: 20) {
            // Profile picture
            ProfilePictureView(url: interaction.profilePictureUrl, size: 40)
                .padding(.leading, 20)
            
            // Username
            Text(isCurrentUser ? "Me" : interaction.userName)
                .font(.system(size: 16, weight: .bold))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(.white)
            
            Spacer()
            
            // Rating and points badges stacked vertically
            VStack(alignment: .trailing, spacing: 8) {
                // Star rating badge
                HStack(spacing: 8) {
                    Text("\(interaction.rating)")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: "#FFF"))
                        .lineLimit(1)
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#FFF"))
                }
                .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                .background(Color(hex: "#DAA520"))
                .cornerRadius(200)
            }
            .padding(.trailing, 20)
        }
        .padding(.vertical, 20)
        .background(isCurrentUser ? Color(hex: "#2A3255") : Color.clear)
    }
}
