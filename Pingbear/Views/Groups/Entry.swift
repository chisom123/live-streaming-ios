//
//  Entry.swift
//  Pingbear
//
//  Created by Ezi Agu on 22/08/1402 AP.
//

import SwiftUI
import SDWebImageSwiftUI
import NotificationBannerSwift
import AVFoundation
import AVKit
import PostHog

struct CustomProgressView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 60) { // Adjust spacing as needed
            HStack {
                // Your logo and text views
                Image("Logo") // Replace "YourLogo" with your logo image asset name
                    .resizable()
                    .scaledToFit()
                    .frame(width: 65, height: 65)
                    .cornerRadius(200)

                Text("Pingbear") // Replace with your app's name or desired text
                    .font(.system(size: 35, weight: .bold, design: .default))
                    .foregroundColor(.black)
                    .padding(.leading, 15)
            }
            .padding() // Adjust padding around content inside the border
            .background(RoundedRectangle(cornerRadius: 200) // Adjust corner radius as needed
                .stroke(lineWidth: 4) // Adjust the line width here
                .foregroundColor(AppColors.orange)) // Change the border color here

            Circle()
                .trim(from: 0, to: 0.7) // Adjust this to change the circle's "filled" portion
                .stroke(style: StrokeStyle(lineWidth: 7, lineCap: .round)) // Make edges round
                .foregroundColor(AppColors.orange) // Set the circle's color
                .frame(width: 50, height: 50) // Set the size of the circle
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                .onAppear() {
                    self.isAnimating = true
                }
        }
    }
}

struct EntryView: View {
    @StateObject private var viewModel: EntryViewModel // Initialize with a competition ID
    @Environment(\.presentationMode) var presentationMode
    @State private var isPresentingInfo = false // State to control the presentation of the New Competition View
    @State private var rating: Int = 0
    @State private var fifthStarScale: CGFloat = 1.0
    @State private var backgroundMusicPlayer: AVAudioPlayer?
    @State private var soundEffectPlayer: AVAudioPlayer?
    @State private var isShowingLoadingOverlay = false


    init(competitionId: String) {
        _viewModel = StateObject(wrappedValue: EntryViewModel(competitionId: competitionId, mode: .entryView))
        self._backgroundMusicPlayer = State(initialValue: self.setupBackgroundMusicPlayer())
    }
    
    private func setupBackgroundMusicPlayer() -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: "bgmusic", withExtension: "mp3") else { return nil }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1 // Loop indefinitely
            player.volume = 0.3 // Adjust this value between 0.0 and 1.0 to decrease or increase the volume
            return player
        } catch {
            print("Cannot load the file")
            return nil
        }
    }
    
    private func playSoundEffect(name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
        do {
            soundEffectPlayer = try AVAudioPlayer(contentsOf: url)
            soundEffectPlayer?.play()
        } catch {
            print("Cannot play the sound file")
        }
    }
    
    private func triggerHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white.edgesIgnoringSafeArea(.all) // Set the background color of the entire view to black
            Group {
                if viewModel.entries.indices.contains(viewModel.currentIndex) {
                    let entry = viewModel.entries[viewModel.currentIndex]
                    VStack {
                        if let imageURL = URL(string: entry.imageUrl) {
                            WebImage(url: imageURL)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ProgressView()
                        }
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            .onChange(of: viewModel.currentIndex) { _ in
                self.rating = 0 // Reset the rating when changing index
                self.isShowingLoadingOverlay = true // Show loading overlay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { // Wait for 2 seconds
                    self.isShowingLoadingOverlay = false // Hide loading overlay
                }
            }
            
            if isShowingLoadingOverlay {
                AppColors.white.opacity(1) // Semi-transparent background
                    .edgesIgnoringSafeArea(.all) // Make it cover the full screen
                    .overlay(
                        CustomProgressView() // Use your custom progress view here
                            .scaleEffect(1) // Adjust the size as needed
                    )
            }


            if !isShowingLoadingOverlay {
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
                                        PostHogSDK.shared.capture("Overall Star Rating Tap")
                                        triggerHapticFeedback(style: .soft)
                                        self.playSoundEffect(name: "pop")
                                        let ratingIncrement = currentEntry.isSuperstar && star == 5 ? 8 : star
                                        self.rating = ratingIncrement
                                        let currentEntryId = currentEntry.id
                                        viewModel.updateStarRating(for: currentEntryId, with: ratingIncrement)
                                        
                                        // Trigger scale-up and haptic feedback only if fifth star is a superstar and is selected
                                        if currentEntry.isSuperstar && star == 5 {
                                            PostHogSDK.shared.capture("Superstar Tap")
                                            triggerHapticFeedback(style: .heavy)
                                            self.playSoundEffect(name: "win")
                                            withAnimation(.spring()) {
                                                self.fifthStarScale = 1.5 // Scale up only for the superstar
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                    self.fifthStarScale = 1.0 // Then scale back to normal
                                                }
                                            }
                                        }
                                        
                                        // Add check here to see if it's the last entry
                                        if viewModel.currentIndex == viewModel.entries.count - 1 {
                                            self.backgroundMusicPlayer?.stop()
                                            let banner = NotificationBanner(title: "Rating complete. Check again later", style: .success)
                                            banner.show()
                                            
                                            DispatchQueue.main.async {
                                                presentationMode.wrappedValue.dismiss()
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
                                        Image(systemName: star <= self.rating ? "star.fill" : "star.fill")
                                            .foregroundColor(
                                                (star == 5 && viewModel.entries.indices.contains(viewModel.currentIndex) && viewModel.entries[viewModel.currentIndex].isSuperstar)
                                                ? (star <= self.rating ? Color(hex: "#FFD700") : Color.white) // Superstar condition
                                                : (star <= self.rating ? Color(hex: "#FFD700") : Color.white) // Regular stars condition
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
                            .foregroundColor(AppColors.primary.opacity(0.95))) // Background color similar to the button
                        // Removed the shadow from the background
                    }
                    .padding(.horizontal)
                    .padding(.bottom, (UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0) + 70)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .center) // Ensures the ZStack is as wide as possible and centered
                
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 25))
                            .foregroundColor(.black)
                    }
                    .padding(10)
                    .background(Circle() // Creates a circular background
                        .fill(Color(hex: "#F5F5F5")) // Sets the fill of the circle to white
                        .shadow(radius: 0)) // Optional: Adds a shadow for a subtle lift effect
                    .clipShape(Circle()) // Ensures the clickable area is also circular

                    Spacer()

                    Button(action: {
                        let banner = NotificationBanner(title: "Image Successfully Reported", style: .success)
                        banner.show()
                    }) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 25))
                            .foregroundColor(.gray)
                    }
                    .padding(10)
                    .background(Circle() // Creates a circular background
                        .fill(Color(hex: "#F5F5F5")) // Sets the fill of the circle to white
                        .shadow(radius: 0)) // Optional: Adds a shadow for a subtle lift effect
                    .clipShape(Circle()) // Ensures the clickable area is also circular
                }
                .padding(.horizontal) // Ensures there's some spacing on the horizontal sides of the HStack
                .padding(.vertical)
            }
        }
        .onAppear {
            self.backgroundMusicPlayer?.play()
        }
        .onDisappear {
            self.backgroundMusicPlayer?.stop()
            self.backgroundMusicPlayer = nil
        }
    }
}

