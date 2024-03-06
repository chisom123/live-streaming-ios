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
import ReplayKit
import Photos
import AVKit

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
    @State private var showingVideoPreview = false
    @State private var videoPlayer: AVPlayer?
    @State var isRecording: Bool = false
    @State var url: URL?
    @State private var showingShareSheet = false // Add this line to your EntryView's state variables
    @State private var playerItemEndObserver: Any?


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
    
    private func configureVideoPlayerLoop() {
        playerItemEndObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.videoPlayer?.currentItem, queue: .main) { _ in
            self.videoPlayer?.seek(to: CMTime.zero)
            self.videoPlayer?.play()
        }
    }

    
    func startRecording(enableMicrophone: Bool = false,completion: @escaping (Error?)->()){
        let recorder = RPScreenRecorder.shared()
        
        recorder.isMicrophoneEnabled = false
        
        recorder.startRecording(handler: completion)
    }
    
    func stopRecording()async throws->URL{
        let name = UUID().uuidString + ".mov"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        
        let recorder = RPScreenRecorder.shared()
        
        try await recorder.stopRecording(withOutput: url)
        
        return url
    }
    
    func cancelRecording(){
        let recorder = RPScreenRecorder.shared()
        recorder.discardRecording {}
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
                                    self.backgroundMusicPlayer?.stop()
                                    // This block is triggered when the user taps on the image
                                    Task {
                                        do {
                                            if isRecording {
                                                // If still recording, stop the recording first
                                                let videoURL = try await stopRecording()
                                                print("Recording stopped: \(videoURL)")
                                                isRecording = false
                                                self.url = videoURL // Ensure this URL is the one from the recording
                                            }
                                            // Now that we are sure recording is stopped, check if a video URL is available
                                            if let previewURL = self.url {
                                                DispatchQueue.main.async {
                                                    self.videoPlayer = AVPlayer(url: previewURL)
                                                    self.configureVideoPlayerLoop()
                                                    self.showingVideoPreview = true // This triggers the video preview display
                                                }
                                            } else {
                                                // If no video URL is available, dismiss the view
                                                DispatchQueue.main.async {
                                                    presentationMode.wrappedValue.dismiss()
                                                }
                                            }
                                        } catch {
                                            print("Error stopping recording: \(error.localizedDescription)")
                                            // If there was an error stopping the recording, consider dismissing the view or handle error
                                            DispatchQueue.main.async {
                                                presentationMode.wrappedValue.dismiss()
                                            }
                                        }
                                    }
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
                self.isShowingLoadingOverlay = true // Show loading overlay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { // Wait for 2 seconds
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
                                        triggerHapticFeedback(style: .soft)
                                        self.playSoundEffect(name: "pop")
                                        let ratingIncrement = currentEntry.isSuperstar && star == 5 ? 8 : star
                                        self.rating = ratingIncrement
                                        let currentEntryId = currentEntry.id
                                        viewModel.updateStarRating(for: currentEntryId, with: ratingIncrement)
                                        
                                        // Trigger scale-up and haptic feedback only if fifth star is a superstar and is selected
                                        if currentEntry.isSuperstar && star == 5 {
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
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                self.backgroundMusicPlayer?.stop()
                                                let banner = NotificationBanner(title: "Voting complete. Check again later", style: .success)
                                                banner.show()
                                                
                                                Task {
                                                    do {
                                                        if isRecording {
                                                            // If still recording, stop the recording first
                                                            let videoURL = try await stopRecording()
                                                            print("Recording stopped: \(videoURL)")
                                                            isRecording = false
                                                            self.url = videoURL // Ensure this URL is the one from the recording
                                                        }
                                                        // Now that we are sure recording is stopped, check if a video URL is available
                                                        if let previewURL = self.url {
                                                            DispatchQueue.main.async {
                                                                self.videoPlayer = AVPlayer(url: previewURL)
                                                                self.showingVideoPreview = true // This triggers the video preview display
                                                            }
                                                        } else {
                                                            // If no video URL is available, dismiss the view
                                                            DispatchQueue.main.async {
                                                                presentationMode.wrappedValue.dismiss()
                                                            }
                                                        }
                                                    } catch {
                                                        print("Error stopping recording: \(error.localizedDescription)")
                                                        // If there was an error stopping the recording, consider dismissing the view or handle error
                                                        DispatchQueue.main.async {
                                                            presentationMode.wrappedValue.dismiss()
                                                        }
                                                    }
                                                }
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
            }
            
            if showingVideoPreview {
                Color.white.edgesIgnoringSafeArea(.all) // Set the background to white and make it cover the whole screen
                    .overlay(
                        VStack { // Use VStack for vertical layout
                            Spacer()
                            
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Text("Skip")
                                    .foregroundColor(.gray) // Set the text color to red
                                    .font(.system(size: 15, weight: .bold, design: .default))
                                    .padding(.vertical, 5) // Add padding inside the border
                                    .padding(.horizontal, 30)
                                    .background(Color.white) // Set the background color of the button; change this as needed
                                    .cornerRadius(200)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 200) // Change this value for desired corner radius
                                            .stroke(Color.gray, lineWidth: 2) // Set the border color to red and adjust the line width as needed
                                    )
                            }
                            .padding(.bottom, 20)

                            
                            Text("Voting Replay Video") // Replace with your app's name or desired text
                                .font(.system(size: 20, weight: .bold, design: .default))
                                .foregroundColor(.black)
                            
                            VideoPlayer(player: videoPlayer)
                                .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.6)
                                .aspectRatio(contentMode: .fit) // Adjust aspect ratio to 'fit' to prevent stretching
                                .cornerRadius(20)
                                .padding(.top) // Add some space at the top
                                .onAppear {
                                    videoPlayer?.playImmediately(atRate: 1.0)
                                }
                            
                            Spacer() // Pushes content to the top, you can adjust spacing as needed
                            
                            HStack(spacing: 20) { // Use HStack for horizontal layout of buttons
                                Button("Save to Camera Roll") {
                                    PHPhotoLibrary.shared().performChanges {
                                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.url!)
                                    } completionHandler: { success, error in
                                        presentationMode.wrappedValue.dismiss()
                                        if success {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Delay to allow for UI update
                                                presentationMode.wrappedValue.dismiss()
                                                let banner = NotificationBanner(title: "Successfully saved to camera roll", style: .success)
                                                banner.show()
                                            }
                                        } else {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Delay to allow for UI update
                                                presentationMode.wrappedValue.dismiss()
                                                let banner = NotificationBanner(title: "Unsuccessfully saved to camera roll", style: .danger)
                                                banner.show()
                                            }
                                        }
                                    }
                                }
                                .font(.system(size: 18, weight: .bold, design: .default))
                                .padding(.vertical) // Keep the default vertical padding
                                .padding(.horizontal, 20) // Increase horizontal padding
                                .background(Color(hex: "#1199FF")) // Gray out if user has joined
                                .foregroundColor(Color.white)
                                .cornerRadius(200)
                                
                                Button("Share") {
                                    self.showingShareSheet = true
                                }
                                .font(.system(size: 18, weight: .bold, design: .default))
                                .padding(.vertical) // Keep the default vertical padding
                                .padding(.horizontal, 20) // Increase horizontal padding
                                .background(Color(hex: "#7B68EE")) // Gray out if user has joined
                                .foregroundColor(Color.white)
                                .cornerRadius(200)
                            } // End of HStack
                            
                            Spacer() // Push buttons up towards video
                        }
                    )
            }
        }
        .onAppear {
            self.backgroundMusicPlayer?.play()
            startRecording { error in
                if let error = error {
                    print(error.localizedDescription)
                    return
                }
                
                isRecording = true
            }
        }
        .onDisappear {
            self.backgroundMusicPlayer?.stop()
            self.backgroundMusicPlayer = nil  // Release the player
            
            self.videoPlayer?.pause()
            self.videoPlayer = nil  // Release the player
            
            if let observer = playerItemEndObserver {
                NotificationCenter.default.removeObserver(observer)
                playerItemEndObserver = nil
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            // Modify this if you need to share something specific
            ShareSheet(items: [self.url as Any]) // Casting URL to Any to prevent nil values from causing issues
        }
    }
}

