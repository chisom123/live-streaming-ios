import SwiftUI
import NotificationBannerSwift
import AVFoundation
import AVKit
import PostHog

struct DemoView: View {
    @ObservedObject private var viewModel = DemoViewModel()
    @State private var rating: Int = 0
    @State private var isRatingEnabled: Bool = true
    @State private var backgroundMusicPlayer: AVAudioPlayer?
    @State private var navigateToUsernameShield = false // Updated for navigation link
    @State private var soundEffectPlayer: AVAudioPlayer?
    @State private var isShowingLoadingOverlay: Bool = false

    init() {
        self._backgroundMusicPlayer = State(initialValue: self.setupBackgroundMusicPlayer())
    }
    
    private func setupBackgroundMusicPlayer() -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: "bgmusic", withExtension: "mp3") else { return nil }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.3
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
            Color.white.edgesIgnoringSafeArea(.all)
            Group {
                VStack {
                    if let imageName = viewModel.currentImageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ProgressView()
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            .onChange(of: viewModel.currentImageName) { _ in
                self.rating = 0
                self.isShowingLoadingOverlay = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                    self.isRatingEnabled = true
                    self.isShowingLoadingOverlay = false
                }
            }
            
            if isShowingLoadingOverlay {
                AppColors.white.opacity(1)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        CustomProgressView()
                            .scaleEffect(1)
                    )
            }
            
            if !isShowingLoadingOverlay {
                
                VStack {
                    Spacer()
                    
                    ZStack {
                        HStack(alignment: .center, spacing: 10) {
                            ForEach(1...5, id: \.self) { star in
                                Button(action: {
                                    isRatingEnabled = false
                                    PostHogSDK.shared.capture("Demo Star Tap")
                                    triggerHapticFeedback(style: .soft)
                                    playSoundEffect(name: "pop")
                                    rating = star
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        if viewModel.isLastImage() {
                                            navigateToUsernameShield = true
                                            self.backgroundMusicPlayer?.stop()
                                        } else {
                                            viewModel.nextImage()
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
                        .padding(.horizontal) // Adds horizontal padding to the HStack
                        .padding(.vertical, 10) // Increase vertical padding of the HStack
                        .background(RoundedRectangle(cornerRadius: 200)
                            .foregroundColor(AppColors.primary.opacity(0.95))) // Background color similar to the button
                    }
                    .padding(.horizontal)
                    .padding(.bottom, (UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0) + 70)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                
            }
        }
        .fullScreenCover(isPresented: $navigateToUsernameShield) {
            UsernameShieldView(addFriendModel: AddFriendsModel())
        }
        .onAppear {
            viewModel.fetchDemoImages()
            self.backgroundMusicPlayer?.play()
        }
        .onDisappear {
            self.backgroundMusicPlayer?.stop()
        }
    }
}


class DemoViewModel: ObservableObject {
    @Published var currentImageName: String?
    private var images = ["demo_image1", "demo_image2", "demo_image3"] // Replace with your actual image names in Assets
    private var index = 0

    init() {
        fetchDemoImages()
    }

    func fetchDemoImages() {
        currentImageName = images.first
    }

    func nextImage() {
        index = (index + 1) % images.count
        currentImageName = images[index]
    }
    
    func isLastImage() -> Bool {
        return index == images.count - 1
    }
}
