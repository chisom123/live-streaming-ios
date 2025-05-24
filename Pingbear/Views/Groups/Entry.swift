//
//  Entry.swift
//  Pingbear
//
//  Created by Ezi Agu on 22/08/1402 AP.
//

import SwiftUI
import NotificationBannerSwift
import Kingfisher

struct EntryView: View {
    @StateObject private var viewModel: EntryViewModel // Initialize with a competition ID
    @Environment(\.presentationMode) var presentationMode
    @State private var rating: Int = 0
    @State private var isRatingEnabled: Bool = true
    @State private var navigateToCompDetails = false
    @State private var animateRating: Bool = false
    @State private var isTransitioning: Bool = false
    @State private var slideDirection: SlideDirection = .left
    
    // Interaction service
    @StateObject private var interactionService = PhotoInteractionService()
    @State private var showInteractions = false
    
    enum SlideDirection {
        case left, right
    }
    
    var competition: Competition

    init(competitionId: String, competition: Competition) {
        _viewModel = StateObject(wrappedValue: EntryViewModel(competitionId: competitionId, mode: .entryView))
        self.competition = competition // Initialize the competition property
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
    
    /// Prefetches the next image to ensure smooth transitions
    private func prefetchNextImage() {
        guard viewModel.entries.indices.contains(viewModel.currentIndex + 1) else { return }
        
        // Capture these values outside the closure to avoid actor-isolation issues
        let nextIndex = viewModel.currentIndex + 1
        let nextEntry = viewModel.entries[nextIndex]
        
        if let imageURL = URL(string: nextEntry.photoUrl) {
            KingfisherManager.shared.retrieveImage(with: imageURL) { result in
                // Result already handled by Kingfisher's cache
            }
        }
    }
    
    /// Transitions to the next entry with smooth animation
    private func transitionToNextEntry() {
        guard viewModel.currentIndex < viewModel.entries.count - 1 else {
            // Clean up before navigating away
            cleanupResources()
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
            
            // Prepare interaction service for new entry
            interactionService.prepareForNewEntry()
            
            // Track view for the new entry after transition completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if viewModel.entries.indices.contains(viewModel.currentIndex) {
                    let newEntryId = viewModel.entries[viewModel.currentIndex].id
                    interactionService.trackViewAndFetchCount(
                        competitionId: competition.id,
                        entryId: newEntryId,
                        source: "entry_view"
                    )
                }
            }
            
            prefetchNextImage()
            
            // Reset the view position and reveal the new image
            withAnimation(.easeInOut(duration: 0.2)) {
                isTransitioning = false
                rating = 0
                isRatingEnabled = true
            }
        }
    }
    
    /// Cleans up resources to prevent memory leaks and data glitches
    private func cleanupResources() {
        // Cancel any pending image downloads
        KingfisherManager.shared.downloader.cancelAll()
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
                                .cacheMemoryOnly()
                                .resizable()
                                .aspectRatio(contentMode: entry.isFromCamera ? .fill : .fit)
                                .frame(width: size.width, height: size.height)
                                .clipped()
                                .overlay {
                                    if let overlayText = entry.overlayText {
                                        Text(overlayText)
                                            .foregroundColor(.white)
                                            .font(.system(size: 24, weight: .bold))
                                            .multilineTextAlignment(.center)
                                            .frame(width: size.width * 0.8)
                                            .position(x: size.width / 2, y: entry.overlayVerticalPosition)
                                    }
                                }
                                .offset(x: isTransitioning ? (slideDirection == .left ? -size.width : size.width) : 0)
                                .onAppear {
                                    prefetchNextImage()
                                    // Track view when image actually appears
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        interactionService.trackViewAndFetchCount(
                                            competitionId: competition.id,
                                            entryId: entry.id,
                                            source: "entry_view"
                                        )
                                    }
                                }
                        } else {
                            ZStack {
                                Color(hex: "#10183C")
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.white)
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: isTransitioning)
                }
            }
            .onChange(of: viewModel.currentIndex) { _ in
                self.rating = 0 // Reset the rating when changing index
                self.isRatingEnabled = true
                
                // Prepare interaction service for new entry
                interactionService.prepareForNewEntry()
                
                // Fetch view count for new entry
                if viewModel.entries.indices.contains(viewModel.currentIndex) {
                    interactionService.fetchViewCount(
                        competitionId: competition.id,
                        entryId: viewModel.entries[viewModel.currentIndex].id
                    )
                }
            }
            
            // Top navigation bar with username and theme
            HStack {
                // Left side - Back button
                Button(action: {
                    cleanupResources()
                    navigateToCompDetails = true
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                }
                .frame(width: 80, alignment: .leading) // Fixed width
                
                Spacer()
                
                // Center content
                if viewModel.entries.indices.contains(viewModel.currentIndex) {
                    let entry = viewModel.entries[viewModel.currentIndex]
                    
                    HStack(spacing: 15) {
                        ProfilePictureView(url: entry.userProfilePictureUrl, size: 35)
                        
                        Text(entry.userName)
                            .foregroundColor(.white)
                            .font(.system(size: 20, weight: .bold, design: .default))
                            .shadow(radius: 10)
                            .truncationMode(.tail)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: 250)
                }
                
                Spacer()
                
                // Right side - Eye button with count
                HStack(spacing: 6) {
                    Button(action: {
                        if viewModel.entries.indices.contains(viewModel.currentIndex) {
                            showInteractions = true
                            interactionService.fetchInteractions(
                                competitionId: competition.id,
                                entryId: viewModel.entries[viewModel.currentIndex].id
                            )
                        }
                    }) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .shadow(radius: 10)
                    }
                    
                    Text("\(interactionService.viewCount)")
                        .foregroundColor(.white)
                        .font(.system(size: 22, weight: .bold))
                        .truncationMode(.tail)
                        .lineLimit(1)
                        .shadow(radius: 10)
                }
                .frame(width: 80, alignment: .trailing) // Fixed width matching left side
            }
            .padding(.top, (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0) + 5)
            .padding()
            
            // Bottom - Theme and Star rating
            VStack(spacing: 0) { // Zero spacing is crucial for the seamless blend
                Spacer() // Pushes the content to the bottom

                // Theme container if theme exists
                if viewModel.entries.indices.contains(viewModel.currentIndex) {
                    let entry = viewModel.entries[viewModel.currentIndex]
                    if let themeName = entry.themeName {
                        // Theme container with only top corners rounded
                        RoundedCorner(radius: 200, corners: [.topLeft, .topRight])
                            .fill(Color(hex: "#253063").opacity(0.9)) // Slightly lighter than rating bar
                            .frame(height: 50)
                            .overlay(
                                Text(themeName)
                                    .foregroundColor(.white)
                                    .font(.system(size: 18, weight: .bold))
                                    .truncationMode(.tail)
                                    .lineLimit(1)
                                    .padding(.horizontal)
                            )
                    }
                }
                
                // Container view for stars with only bottom corners rounded
                ZStack {
                    if viewModel.entries.indices.contains(viewModel.currentIndex) {
                        let entry = viewModel.entries[viewModel.currentIndex]
                        
                        if entry.themeName != nil {
                            RoundedCorner(radius: 200, corners: [.bottomLeft, .bottomRight])
                                .fill(Color(hex: "#1A2245"))
                        } else {
                            RoundedRectangle(cornerRadius: 200)
                                .fill(Color(hex: "#1A2245"))
                        }
                    }
                    
                    HStack(alignment: .center, spacing: 12) { // Reduced spacing between stars
                        if viewModel.entries.indices.contains(viewModel.currentIndex) {
                            let currentEntry = viewModel.entries[viewModel.currentIndex]
                            let maxSelectableStars = currentEntry.isSuperstar ? 5 : 4

                            ForEach(1...5, id: \.self) { star in
                                Button(action: {
                                    // Check if this is the disabled 5th star
                                    if star == 5 && !currentEntry.isSuperstar {
                                        // Trigger warning haptic feedback for disabled 5th star
                                        let generator = UINotificationFeedbackGenerator()
                                        generator.notificationOccurred(.warning)
                                        return
                                    }
                                    
                                    // Only allow rating if within selectable range and rating is enabled
                                    guard star <= maxSelectableStars && isRatingEnabled else { return }
                                    
                                    isRatingEnabled = false
                                    Analytics.shared.trackEntry(
                                        action: "rate",
                                        entryId: currentEntry.id,
                                        competitionId: competition.id,
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
                                            cleanupResources()
                                            navigateToCompDetails = true
                                        }
                                    } else {
                                        // Use the new transition function
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                                            transitionToNextEntry()
                                        }
                                    }
                                }) {
                                    if star == 5 && !currentEntry.isSuperstar {
                                        ZStack {
                                            Image(systemName: "star.fill")
                                                .foregroundColor(Color.white)
                                                .font(.system(size: 34))
                                            
                                            Image(systemName: "nosign")
                                                .foregroundColor(Color(hex: "#B22222"))
                                                .font(.system(size: 41, weight: .bold))
                                        }
                                    } else {
                                        // Regular star for positions 1-4 and position 5 for superstars
                                        Image(systemName: "star.fill")
                                            .foregroundColor(star <= rating ? Color(hex: "#FFD700") : Color.white)
                                            .font(.system(size: 34))
                                            .scaleEffect(animateRating && star <= rating ? 1.3 : 1.0)
                                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animateRating && star <= rating)
                                    }
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
            }
            .padding(.bottom, (UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0) + 60)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .center) // Ensures the ZStack is as wide as possible and centered
            .padding(.horizontal)
        }
        .fullScreenCover(isPresented: $navigateToCompDetails) {
            CompDetails(competition: competition) // Adjust according to your needs
        }
        .sheet(isPresented: $showInteractions) {
            InteractionsListView(
                interactions: interactionService.interactions,
                isLoading: interactionService.isLoadingInteractions
            )
        }
        .ignoresSafeArea(edges: .all)
        .onAppear {
            // Track view for the first entry when view appears
            if viewModel.entries.indices.contains(viewModel.currentIndex) {
                let entryId = viewModel.entries[viewModel.currentIndex].id
                // Use a small delay to ensure the view is fully rendered
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    interactionService.trackViewAndFetchCount(
                        competitionId: competition.id,
                        entryId: entryId,
                        source: "entry_view"
                    )
                }
            }
            
            // Preload images
            let entriesToLoad = min(3, viewModel.entries.count)
            let currentIdx = viewModel.currentIndex
            
            // Preload each image
            for i in 0..<entriesToLoad {
                if i != currentIdx, i < viewModel.entries.count,
                   let url = URL(string: viewModel.entries[i].photoUrl) {
                    KingfisherManager.shared.retrieveImage(with: url) { _ in }
                }
            }
            
            Analytics.shared.trackScreen(name: "entry_rating")
        }
        .onDisappear {
            // Clean up when the view disappears
            cleanupResources()
        }
    }
}

