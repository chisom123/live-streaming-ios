//
//  Entry.swift
//  Pingbear
//
//  Created by Ezi Agu on 22/08/1402 AP.
//

import SwiftUI
import SDWebImageSwiftUI
import NotificationBannerSwift

struct EntryView: View {
    @StateObject private var viewModel: EntryViewModel // Initialize with a competition ID
    @Environment(\.presentationMode) var presentationMode
    @State private var isPresentingInfo = false // State to control the presentation of the New Competition View
    @State private var rating: Int = 0
    @State private var fifthStarScale: CGFloat = 1.0

    init(competitionId: String) {
        _viewModel = StateObject(wrappedValue: EntryViewModel(competitionId: competitionId, mode: .entryView))
    }
    
    private func triggerHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if viewModel.entries.indices.contains(viewModel.currentIndex) {
                    let entry = viewModel.entries[viewModel.currentIndex]
                    VStack {
                        if let imageURL = URL(string: entry.imageUrl) {
                            WebImage(url: imageURL)
                                .resizable()
                                .scaledToFill()
                                .clipped()
                                .onTapGesture {
                                    presentationMode.wrappedValue.dismiss()
                                }
                        } else {
                            ProgressView()
                        }
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            .onChange(of: viewModel.currentIndex) { _ in
                self.rating = 0 // Reset the rating when changing index
            }



            // Bottom - Heart button, horizontally centered
            VStack {
                Spacer() // Pushes the content to the bottom

                // Container view for stars with background
                ZStack {
                    HStack(alignment: .center, spacing: 10) {
                        if viewModel.entries.indices.contains(viewModel.currentIndex) {
                            let maxStars = 5

                            ForEach(1...maxStars, id: \.self) { star in
                                let currentEntry = viewModel.entries[viewModel.currentIndex]
                                Button(action: {
                                    let ratingIncrement = currentEntry.isSuperstar && star == 5 ? 8 : star
                                    self.rating = ratingIncrement
                                    let currentEntryId = currentEntry.id
                                    viewModel.updateStarRating(for: currentEntryId, with: ratingIncrement)

                                    // Trigger scale-up and haptic feedback only if fifth star is a superstar and is selected
                                    if currentEntry.isSuperstar && star == 5 {
                                        triggerHapticFeedback(style: .heavy)
                                        withAnimation(.spring()) {
                                            self.fifthStarScale = 1.5 // Scale up only for the superstar
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                self.fifthStarScale = 1.0 // Then scale back to normal
                                            }
                                        }
                                    }
                                    
                                    // Add check here to see if it's the last entry
                                    if viewModel.currentIndex == viewModel.entries.count - 1 {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Delay to allow for UI update
                                            presentationMode.wrappedValue.dismiss()
                                            let banner = NotificationBanner(title: "Voting complete. Check again later", style: .warning)
                                            banner.show()
                                        }
                                    } else {
                                        // Existing code to handle non-last entries

                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            if viewModel.currentIndex < viewModel.entries.count - 1 {
                                                viewModel.currentIndex += 1
                                            }
                                        }
                                    }
                                }) {
                                    Image(systemName: star <= self.rating ? "star.fill" : "star")
                                        .foregroundColor(
                                            (star == 5 && viewModel.entries.indices.contains(viewModel.currentIndex) && viewModel.entries[viewModel.currentIndex].isSuperstar)
                                            ? (star <= self.rating ? Color(hex: "#FFD700") : Color(hex: "#DAA520")) // Superstar condition
                                            : (star <= self.rating ? Color(hex: "#FFD700") : Color.black) // Regular stars condition
                                        )
                                        .font(.system(size: 33))
                                        .scaleEffect(star == 5 && currentEntry.isSuperstar ? fifthStarScale : 1.0) // Apply scale effect only to the superstar
                                        .padding(5)
                                }
                            }
                            
                        }
                    }
                    .padding(.horizontal) // Adds horizontal padding to the HStack
                    .padding(.vertical, 10) // Increase vertical padding of the HStack
                    .background(RoundedRectangle(cornerRadius: 200)
                        .foregroundColor(AppColors.white.opacity(0.95))) // Background color similar to the button
                    // Removed the shadow from the background
                }
                .padding(.horizontal)
                .padding(.bottom, (UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0) + 20)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .center) // Ensures the ZStack is as wide as possible and centered
        }
    }
}

