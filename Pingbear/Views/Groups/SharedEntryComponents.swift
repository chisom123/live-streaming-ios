import SwiftUI
import Kingfisher

// MARK: - Shared Constants
struct PhotoViewConstants {
    static let starFooterHeight: CGFloat = 100 // Fixed - good for consistency
    
    // Dynamic heights based on screen size
    static let minHeight: CGFloat = 80 // Fixed minimum - always small enough
    
    static func midHeight(withFooter: Bool = true) -> CGFloat {
        let baseMidHeight = UIScreen.main.bounds.height * 0.25
        
        // If there's no footer, add the footer height to maintain consistent visual positioning
        if !withFooter {
            return baseMidHeight + starFooterHeight
        }
        
        return baseMidHeight
    }
    
    static func maxHeight(withFooter: Bool = true) -> CGFloat {
        let safeAreaTop = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first?.safeAreaInsets.top ?? 0
        
        let navigationHeight: CGFloat = 80
        let bottomPadding: CGFloat = 20
        let footerHeight = withFooter ? starFooterHeight : 0
        
        return UIScreen.main.bounds.height
               - safeAreaTop
               - navigationHeight
               - bottomPadding
               - footerHeight
    }
}

// MARK: - Entry to UserPhoto Conversion Extension
extension Entry {
    func toUserPhoto() -> UserPhoto {
        return UserPhoto(
            id: self.id,
            photoUrl: self.photoUrl,
            stars: self.stars,
            isSuperstar: self.isSuperstar,
            creationDate: self.creationDate,
            themeName: self.themeName,
            themeId: self.themeId,
            overlayText: self.overlayText,
            overlayVerticalPosition: self.overlayVerticalPosition,
            isFromCamera: self.isFromCamera,
            userId: self.userId
        )
    }
}

// MARK: - Shared Photo Navigation Bar
struct PhotoNavigationBar: View {
    let onBack: () -> Void
    let userName: String
    let userProfilePictureUrl: String?
    let themeName: String?
    let themeId: String?
    let competitionId: String
    let onMessage: () -> Void
    
    var body: some View {
        HStack {
            // Back button
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .shadow(radius: 10)
            }
            .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            // User info
            HStack(spacing: 15) {
                ProfilePictureView(url: userProfilePictureUrl, size: 35)
                
                Text(userName)
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .bold))
                    .shadow(radius: 10)
                    .lineLimit(1)
                
                if let themeName = themeName,
                   let themeId = themeId {
                    ThemeBadgeClickable(
                        themeName: themeName,
                        themeId: themeId,
                        competitionId: competitionId
                    )
                    .layoutPriority(-1)
                }
            }
            .frame(maxWidth: 250)
            
            Spacer()
            
            Button(action: onMessage) {
                Image("message-circle-plus")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.white)
                    .shadow(radius: 10)
                    .frame(width: 33, height: 33)
            }
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}

// MARK: - Shared Photo Rating Bottom Sheet
struct PhotoRatingBottomSheet: View {
    let interactions: [PhotoInteraction]
    let isLoading: Bool
    let minHeight: CGFloat
    let midHeight: CGFloat
    let maxHeight: CGFloat
    let bottomPadding: CGFloat
    
    var body: some View {
        UltraSmoothBottomSheet(
            minHeight: minHeight,
            midHeight: midHeight,
            maxHeight: maxHeight,
            bottomPadding: bottomPadding
        ) {
            VStack(spacing: 0) {
                // Centered handle
                VStack {
                    RoundedRectangle(cornerRadius: 200)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 40, height: 5)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical)
                
                HStack {
                    Text("Ratings (\(interactions.count))")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 16, weight: .bold))
                        .padding(.bottom, 10)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                
                // Content
                if isLoading {
                    EmptyView()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(interactions) { interaction in
                                VStack(spacing: 0) {
                                    HStack {
                                        ProfilePictureView(url: interaction.profilePictureUrl, size: 40)
                                        
                                        Text(interaction.userName)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .padding(.leading, 10)
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 6) {
                                            Text("\(interaction.rating)")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
                                            
                                            Image(systemName: "star.fill")
                                                .resizable()
                                                .frame(width: 16, height: 16)
                                                .foregroundColor(.white)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color(hex: "#DAA520"))
                                        .cornerRadius(20)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 15)
                                    
                                    if interaction.id != interactions.last?.id {
                                        Divider()
                                            .background(Color.white.opacity(0.2))
                                    }
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Shared Photo Star Rating Footer
struct PhotoStarRatingFooter: View {
    @Binding var rating: Int
    let hasAlreadyVoted: Bool
    let isRatingEnabled: Bool
    let animateRating: Bool
    let onRatingSubmit: (Int) -> Void
    let height: CGFloat
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 0) {
                // Star rating section
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Button(action: {
                            guard star <= 5 && isRatingEnabled && !hasAlreadyVoted else { return }
                            onRatingSubmit(star)
                        }) {
                            Image(systemName: "star.fill")
                                .foregroundColor(hasAlreadyVoted ? Color(hex: "#c2c2c2") : star <= rating ? Color(hex: "#FFD700") : Color.white)
                                .font(.system(size: 34))
                                .scaleEffect(animateRating && star <= rating ? 1.3 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animateRating && star <= rating)
                        }
                        .disabled(hasAlreadyVoted || !isRatingEnabled)
                        .padding(5)
                    }
                }
                .padding(.vertical, 25)
                .frame(maxWidth: .infinity)
                .background(hasAlreadyVoted ? Color(hex: "#A9A9A9") : Color(hex: "#10183C"))
            }
            .frame(height: height)
        }
    }
}

// MARK: - Shared Photo Main Image View
struct PhotoMainImageView: View {
    let photoUrl: String
    let overlayText: String?
    let overlayVerticalPosition: CGFloat
    let isTransitioning: Bool
    let slideDirection: SlideDirection
    let screenWidth: CGFloat
    
    var body: some View {
        if let imageURL = URL(string: photoUrl) {
            KFImage(imageURL)
                .placeholder {
                    ZStack {
                        Color(hex: "#10183C")
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                }
                .fade(duration: 0.25)
                .cacheMemoryOnly()
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.all, edges: .all)
                .overlay {
                    if let overlayText = overlayText {
                        Text(overlayText)
                            .foregroundColor(.white)
                            .font(.system(size: 24, weight: .bold))
                            .multilineTextAlignment(.center)
                            .frame(width: screenWidth * 0.8)
                            .position(x: screenWidth / 2, y: overlayVerticalPosition)
                    }
                }
                .offset(x: isTransitioning ? (slideDirection == .left ? -screenWidth : screenWidth) : 0)
                .animation(.easeInOut(duration: 0.3), value: isTransitioning)
        }
    }
}

// MARK: - Ultra-Smooth Bottom Sheet Implementation
struct UltraSmoothBottomSheet<Content: View>: View {
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    
    let minHeight: CGFloat
    let midHeight: CGFloat
    let maxHeight: CGFloat
    let bottomPadding: CGFloat
    let content: Content
    
    @State private var currentDetent: SheetDetent = .mid
    
    enum SheetDetent {
        case min, mid, max
        
        func height(min: CGFloat, mid: CGFloat, max: CGFloat) -> CGFloat {
            switch self {
            case .min: return min
            case .mid: return mid
            case .max: return max
            }
        }
    }
    
    init(minHeight: CGFloat, midHeight: CGFloat, maxHeight: CGFloat, bottomPadding: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.minHeight = minHeight
        self.midHeight = midHeight
        self.maxHeight = maxHeight
        self.bottomPadding = bottomPadding
        self.content = content()
    }
    
    private var currentHeight: CGFloat {
        currentDetent.height(min: minHeight, mid: midHeight, max: maxHeight)
    }
    
    private var displayOffset: CGFloat {
        isDragging ? dragOffset : 0
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            
            VStack(spacing: 0) {
                content
            }
            .frame(width: geometry.size.width, height: maxHeight)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "#1A2245"))
            )
            .offset(y: screenHeight - currentHeight - bottomPadding + displayOffset)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        
                        let translation = value.translation.height
                        
                        // Immediate bounds checking - no offset if it would violate constraints
                        if currentDetent == .max && translation < 0 {
                            // At max height, completely block upward movement
                            dragOffset = 0
                            return
                        }
                        
                        if currentDetent == .min && translation > 0 {
                            // At min height, completely block downward movement
                            dragOffset = 0
                            return
                        }
                        
                        // For mid position, limit the offset to prevent overshooting
                        if currentDetent == .mid {
                            if translation < 0 {
                                // Dragging up towards max
                                let maxAllowedOffset = -(maxHeight - midHeight)
                                dragOffset = max(translation, maxAllowedOffset)
                            } else {
                                // Dragging down towards min
                                let maxAllowedOffset = midHeight - minHeight
                                dragOffset = min(translation, maxAllowedOffset)
                            }
                        } else {
                            dragOffset = translation
                        }
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndLocation.y - value.location.y
                        let dragThreshold: CGFloat = 50
                        let velocityThreshold: CGFloat = 200
                        
                        // Calculate the new detent
                        let newDetent: SheetDetent
                        switch currentDetent {
                        case .min:
                            if value.translation.height < -dragThreshold || velocity < -velocityThreshold {
                                newDetent = .mid
                            } else {
                                newDetent = .min
                            }
                        case .mid:
                            if value.translation.height < -dragThreshold || velocity < -velocityThreshold {
                                newDetent = .max
                            } else if value.translation.height > dragThreshold || velocity > velocityThreshold {
                                newDetent = .min
                            } else {
                                newDetent = .mid
                            }
                        case .max:
                            if value.translation.height > dragThreshold || velocity > velocityThreshold {
                                newDetent = .mid
                            } else {
                                newDetent = .max
                            }
                        }
                        
                        // Animate to new position
                        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85, blendDuration: 0)) {
                            currentDetent = newDetent
                            isDragging = false
                            dragOffset = 0
                        }
                    }
            )
        }
        .ignoresSafeArea()
    }
}
