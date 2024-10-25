//
//  Entry.swift
//  Pingbear
//
//  Created by Ezi Agu on 22/08/1402 AP.
//

import SwiftUI
import NotificationBannerSwift
import PostHog

struct EntryView: View {
    @StateObject private var viewModel: EntryViewModel // Initialize with a competition ID
    @Environment(\.presentationMode) var presentationMode
    @State private var rating: Int = 0
    @State private var isRatingEnabled: Bool = true
    @State private var navigateToCompDetails = false
    
    var competition: Competition


    init(competitionId: String, competition: Competition) {
        _viewModel = StateObject(wrappedValue: EntryViewModel(competitionId: competitionId, mode: .entryView))
        self.competition = competition // Initialize the competition property
    }
    
    private func triggerHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            
            ZStack {
                
                Color.black
                    .edgesIgnoringSafeArea(.all)
                
                Group {
                    if viewModel.entries.indices.contains(viewModel.currentIndex) {
                        let entry = viewModel.entries[viewModel.currentIndex]
                        VStack {
                            if let imageURL = URL(string: entry.photoUrl) {
                                AsyncImage(url: imageURL) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: entry.isFromCamera ? .fill : .fit)
                                            .frame(width: size.width, height: size.height)
                                            .clipped()
                                            .overlay {
                                                if let overlayText = entry.overlayText {
                                                    Text(overlayText)
                                                        .foregroundColor(.white)
                                                        .font(.system(size: 24, weight: .bold))
                                                        .shadow(color: .black, radius: 2, x: 1, y: 1)
                                                        .multilineTextAlignment(.center)
                                                        .frame(width: size.width * 0.8)
                                                        .position(x: size.width / 2, y: entry.overlayVerticalPosition)
                                                }
                                            }
                                    case .failure(_):
                                        Image(systemName: "photo.fill")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .foregroundColor(.gray)
                                            .frame(width: 80, height: 80)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .background(Color.black.opacity(0.1))
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .id(viewModel.currentIndex)
                                .ignoresSafeArea()
                            } else {
                                ProgressView()
                            }
                        }
                    }
                }
            }
            .onChange(of: viewModel.currentIndex) { _ in
                self.rating = 0 // Reset the rating when changing index
                self.isRatingEnabled = true
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
                                    isRatingEnabled = false
                                    PostHogSDK.shared.capture("Star Rating", properties: ["rating": star])
                                    triggerHapticFeedback(style: .soft)
                                    let ratingIncrement = star
                                    self.rating = ratingIncrement
                                    let currentEntryId = currentEntry.id
                                    viewModel.updateStarRating(for: currentEntryId, with: ratingIncrement)

                                    // Add check here to see if it's the last entry
                                    if viewModel.currentIndex == viewModel.entries.count - 1 {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                                            navigateToCompDetails = true
                                        }
                                    } else {
                                        // Existing code to handle non-last entries

                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                                            if viewModel.currentIndex < viewModel.entries.count - 1 {
                                                viewModel.currentIndex += 1
                                            }
                                        }
                                    }
                                }) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(star <= rating ? Color(hex: "#FFD700") : Color.white)
                                        .font(.system(size: 33))
                                        .padding(5)
                                }
                                .disabled(!isRatingEnabled)
                            }
                        }
                    }
                    .padding(.horizontal) // Adds horizontal padding to the HStack
                    .padding(.vertical, 10) // Increase vertical padding of the HStack
                    .background(RoundedRectangle(cornerRadius: 200)
                        .foregroundColor(AppColors.primary.opacity(0.95))) // Background color similar to the button
                    // Removed the shadow from the background
                }
                .padding(.horizontal)
                .padding(.bottom, (UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0) + 60)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .center) // Ensures the ZStack is as wide as possible and centered

            HStack {
                Button(action: {
                    navigateToCompDetails = true
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                }

                Spacer()
                
                // Display the username here
                if viewModel.entries.indices.contains(viewModel.currentIndex) {
                    Text(viewModel.entries[viewModel.currentIndex].userName)
                        .foregroundColor(.white) // Set the text color to white
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .shadow(radius: 10)
                        .truncationMode(.tail) // Adds an ellipsis at the end of the text if it's too long
                        .lineLimit(1) // Ensures the text is on a single line
                        .frame(maxWidth: 175)
                }

                Spacer()

                Button(action: {
                    let banner = NotificationBanner(title: "Photo Successfully Reported", style: .success)
                    banner.show()
                    PostHogSDK.shared.capture("Photo Reported")
                }) {
                    Image(systemName: "flag")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                }
            }
            .padding(.top, (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0) + 5)
            .padding()

        }
        .fullScreenCover(isPresented: $navigateToCompDetails) {
            CompDetails(competition: competition) // Adjust according to your needs
        }
        .ignoresSafeArea(edges: .all)
    }
}

