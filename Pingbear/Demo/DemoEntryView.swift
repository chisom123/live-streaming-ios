import SwiftUI
import Kingfisher

struct DemoEntryView: View {
    @ObservedObject var viewModel: DemoEntryViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var rating: Int = 0
    @State private var isRatingEnabled: Bool = true
    @State private var navigateToCompDetails = false
    @State private var animateRating: Bool = false
    @State private var isTransitioning: Bool = false
    @State private var slideDirection: SlideDirection = .left
    @State private var imageLoaded: Bool = false
    
    enum SlideDirection {
        case left, right
    }
    
    private func triggerHapticFeedback(for star: Int) {
        // Enhanced haptic feedback based on star value
        let intensity = Float(star) / 5.0
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred(intensity: CGFloat(intensity))
        
        // Add a short vibration pattern for casino-like feel
        let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            heavyGenerator.impactOccurred()
        }
    }
    
    private func transitionToNextEntry() {
        guard viewModel.currentIndex < viewModel.entries.count - 1 else {
            navigateToCompDetails = true
            return
        }
        
        // Start transition animation
        withAnimation(.easeInOut(duration: 0.2)) {
            isTransitioning = true
            slideDirection = .left
        }
        
        // After a short delay, update the index and prepare for next view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            viewModel.currentIndex += 1
            
            // Reset the view position and reveal the new image
            withAnimation(.easeInOut(duration: 0.2)) {
                isTransitioning = false
                rating = 0
                isRatingEnabled = true
                imageLoaded = false
                
                // Simulate image loading in demo
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    imageLoaded = true
                }
            }
        }
    }
    
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            
            ZStack {
                // Solid navy blue background matching the star rating bar
                Color(hex: "#10183C")
                    .edgesIgnoringSafeArea(.all)
                
                // Entry image view with transition
                if viewModel.entries.indices.contains(viewModel.currentIndex) {
                    let entry = viewModel.entries[viewModel.currentIndex]
                    
                    // Main image container with animations
                    ZStack {
                        if let imageURL = URL(string: entry.photoUrl) {
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
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: size.width, height: size.height)
                                .clipped()
                                .offset(x: isTransitioning ? (slideDirection == .left ? -size.width : size.width) : 0)
                                .onAppear {
                                    // Preload next image if available
                                    if viewModel.entries.indices.contains(viewModel.currentIndex + 1),
                                       let nextURL = URL(string: viewModel.entries[viewModel.currentIndex + 1].photoUrl) {
                                        KingfisherManager.shared.retrieveImage(with: nextURL) { _ in }
                                    }
                                }
                        } else {
                            // Fallback if URL is invalid
                            ZStack {
                                Color(hex: "#2A3255")
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.white)
                            }
                            .frame(width: size.width, height: size.height)
                            .offset(x: isTransitioning ? (slideDirection == .left ? -size.width : size.width) : 0)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: isTransitioning)
                }
            }
            .onChange(of: viewModel.currentIndex) { _ in
                self.rating = 0 // Reset the rating when changing index
                self.isRatingEnabled = true
            }
            
            // Top navigation bar with username and theme
            VStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .shadow(radius: 10)
                    }

                    Spacer()
                    
                    // Show username and theme inline
                    if viewModel.entries.indices.contains(viewModel.currentIndex) {
                        let entry = viewModel.entries[viewModel.currentIndex]
                        
                        HStack(spacing: 10) {
                            Text(entry.userName)
                                .foregroundColor(.white)
                                .font(.system(size: 20, weight: .bold, design: .default))
                                .shadow(radius: 10)
                                .truncationMode(.tail)
                                .lineLimit(1)
                            
                            // Only show the theme badge if there is a theme
                            if let themeName = entry.themeName {
                                ThemeBadge(themeName: themeName)
                            }
                        }
                        .frame(maxWidth: 250)
                    }

                    Spacer()

                    Button(action: {
                        // Provide haptic feedback for disabled button
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.warning)
                        
                    }) {
                        Image(systemName: "flag")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .shadow(radius: 10)
                            .opacity(0)
                    }
                }
                .padding(.top, 50)
                .padding()
                
                // Bottom - Star rating, horizontally centered
                VStack {
                    Spacer() // Pushes the content to the bottom

                    // Container view for stars with background
                    ZStack {
                        // Beautiful glass-like background for stars
                        RoundedRectangle(cornerRadius: 200)
                            .fill(Color(hex: "#1A2245"))
                        
                        HStack(alignment: .center, spacing: 12) { // Reduced spacing between stars
                            if viewModel.entries.indices.contains(viewModel.currentIndex) {
                                let maxStars = 5
                                let currentEntry = viewModel.entries[viewModel.currentIndex]

                                ForEach(1...maxStars, id: \.self) { star in
                                    Button(action: {
                                        isRatingEnabled = false
                                        Analytics.shared.trackEntry(
                                            action: "rate_demo",
                                            entryId: currentEntry.id,
                                            competitionId: "demo-competition",
                                            properties: ["rating": star]
                                        )
                                        triggerHapticFeedback(for: star)
                                        let ratingIncrement = star
                                        self.rating = ratingIncrement
                                        
                                        // Animate star rating
                                        animateRating = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            animateRating = false
                                        }
                                        
                                        let currentEntryId = currentEntry.id
                                        viewModel.updateStarRating(for: currentEntryId, with: ratingIncrement)

                                        // Add check here to see if it's the last entry
                                        if viewModel.currentIndex == viewModel.entries.count - 1 {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                                                navigateToCompDetails = true
                                            }
                                        } else {
                                            // Use the new transition function
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                                                transitionToNextEntry()
                                            }
                                        }
                                    }) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(star <= rating ? Color(hex: "#FFD700") : Color.white)
                                            .font(.system(size: 34))
                                            .scaleEffect(animateRating && star <= rating ? 1.3 : 1.0)
                                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animateRating && star <= rating)
                                    }
                                    .disabled(!isRatingEnabled)
                                    .padding(5)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 15)
                    }
                    .frame(height: 80)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 60)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
            }
        }
        .ignoresSafeArea(edges: .all)
        .onAppear {
            // Simulate image loading for first image
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                imageLoaded = true
            }
            
            // Preload images for smoother experience
            preloadImages()
            
            Analytics.shared.trackScreen(name: "demo_entry_rating")
        }
        .fullScreenCover(isPresented: $navigateToCompDetails) {
            DemoCompDetailsView()
        }
    }
    
    // Preload the first few images for smoother experience
    private func preloadImages() {
        let entriesToPreload = min(5, viewModel.entries.count)
        
        for i in 0..<entriesToPreload {
            if let url = URL(string: viewModel.entries[i].photoUrl) {
                KingfisherManager.shared.retrieveImage(with: url) { _ in }
            }
        }
    }
}
