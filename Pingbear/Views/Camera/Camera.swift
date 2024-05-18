import SwiftUI
import AVKit
import Combine

struct CameraView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject var cameraModel = CameraViewModel()
    
    var body: some View {
        ZStack {
            // MARK: Camera View
            CameraInitView()
                .environmentObject(cameraModel)
                .ignoresSafeArea()
                .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { isPressing in
                    if isPressing {
                        if cameraModel.recordedDuration < cameraModel.maxDuration {
                            cameraModel.startRecording()
                        }
                    } else {
                        cameraModel.stopRecording()
                    }
                }, perform: {})
            
            // Other controls (Preview and Reset) remain the same
            ZStack {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(.black.opacity(0.25))
                        
                        Rectangle()
                            .fill(Color(hex: "#FF4500"))
                            .frame(width: geometry.size.width * (cameraModel.recordedDuration / cameraModel.maxDuration))
                    }
                    .frame(height: 10)
                    .cornerRadius(200)
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding()
                
                HStack {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                        cameraModel.recordedDuration = 0
                        cameraModel.previewURL = nil
                        cameraModel.recordedURLs.removeAll()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 30)) // Increase the font size as needed
                            .foregroundColor(.white)
                            .padding(5) // Adjust the padding to balance the increased size
                            .shadow(radius: 10)
                            .opacity(cameraModel.isRecording ? 0 : 1)
                    }
                    Spacer()
                    Button(action: {
                        cameraModel.toggleCamera()
                    }) {
                        Image(systemName: "arrow.2.circlepath")
                            .font(.system(size: 30)) // Increase the font size as needed
                            .foregroundColor(.white)
                            .padding(5) // Adjust the padding to balance the increased size
                            .shadow(radius: 10)
                            .opacity(cameraModel.isRecording ? 0 : 1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
                .padding(.top, 30)
                
                ZStack(alignment: .center) {
                    Text("Hold to Record")
                        .font(.system(size: 25, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                        .opacity(cameraModel.isRecording || cameraModel.recordedDuration >= cameraModel.maxDuration ? 0 : 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Preview Button
                Button {
                    if let _ = cameraModel.previewURL {
                        cameraModel.showPreview.toggle()
                    }
                } label: {
                    Group {
                        if cameraModel.previewURL == nil && !cameraModel.recordedURLs.isEmpty {
                            // Merging Videos
                            ProgressView()
                                .tint(.white)
                        } else {
                            Label {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 20, weight: .bold, design: .default))
                            } icon: {
                                Text("Preview")
                                    .font(.system(size: 20, weight: .bold, design: .default))
                            }
                            .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal,20)
                    .padding(.vertical, 12)
                    .background {
                        Capsule()
                            .fill(Color(hex: "#1199FF"))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding()
                .padding(.bottom, 20)
                .opacity((cameraModel.previewURL == nil && cameraModel.recordedURLs.isEmpty) || cameraModel.isRecording || cameraModel.recordedDuration < 0.3 ? 0 : 1)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .fullScreenCover(isPresented: $cameraModel.showPreview, content: {
            if let url = cameraModel.previewURL {
                FinalPreview(url: url, showPreview: $cameraModel.showPreview)
            }
        })
    }
}

struct CustomVideoPlayer: UIViewControllerRepresentable {
    var url: URL

    // Create a Coordinator for managing observers and player updates
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // This function creates the custom AVPlayerViewController with necessary settings
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let playerViewController = AVPlayerViewController()
        context.coordinator.setupPlayer(for: playerViewController, with: url)
        return playerViewController
    }

    // This function updates the AVPlayerViewController during its lifecycle
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        context.coordinator.updatePlayer(uiViewController)
    }

    // Use this method to cleanup when the view is being deinitialized
    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.cleanup(uiViewController)
    }

    class Coordinator {
        var parent: CustomVideoPlayer
        var player: AVPlayer?

        init(_ parent: CustomVideoPlayer) {
            self.parent = parent
        }

        func setupPlayer(for playerViewController: AVPlayerViewController, with url: URL) {
            self.player = AVPlayer(url: url)
            playerViewController.player = self.player
            playerViewController.showsPlaybackControls = false

            setupLifecycleNotifications(playerViewController)
        }

        func updatePlayer(_ uiViewController: AVPlayerViewController) {
            if uiViewController.player == nil {
                uiViewController.player = player
            }

            uiViewController.player?.play()
            uiViewController.player?.actionAtItemEnd = .none

            // Debugging: Check for errors
            if let error = uiViewController.player?.currentItem?.error {
                print("AVPlayer Error: \(error.localizedDescription)")
            }
        }

        func cleanup(_ uiViewController: AVPlayerViewController) {
            uiViewController.player?.pause()
            removeLifecycleNotifications()
        }

        private func setupLifecycleNotifications(_ playerViewController: AVPlayerViewController) {
            guard let player = playerViewController.player else { return }

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appDidEnterBackground),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appWillEnterForeground),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerItemDidReachEnd),
                name: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem
            )
        }

        private func removeLifecycleNotifications() {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func appDidEnterBackground() {
            player?.pause()
            print("App did enter background: Video paused.")
        }

        @objc func appWillEnterForeground() {
            player?.play()
            print("App will enter foreground: Resuming video.")
        }

        @objc func playerItemDidReachEnd(notification: Notification) {
            guard let playerItem = notification.object as? AVPlayerItem else { return }
            playerItem.seek(to: CMTime.zero, completionHandler: nil)
            player?.play()
            print("Video looped: Playing from beginning.")
        }
    }
}

struct FinalPreview: View {
    var url: URL
    @Binding var showPreview: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack(alignment: .leading) {
                CustomVideoPlayer(url: url)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .ignoresSafeArea()

                // Back Button
                VStack {
                    HStack {
                        Button(action: {
                            showPreview.toggle()
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 35))
                                .foregroundColor(.white)
                                .shadow(radius: 10)
                        }
                        .padding(.top, 50)  // Adds padding from the top of the screen
                        .padding(20)
                    }
                    Spacer()
                }

                // Send Button at the bottom
                VStack {
                    Spacer()
                    Button(action: {
                     
                    }) {
                        Text("Send")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .background(Color(hex: "#1199FF"))
                            .foregroundColor(Color(hex: "#fff"))
                            .cornerRadius(200)
                    }
                    .padding(.bottom, 65)
                    .padding(.horizontal)
                }
            }
        }
        .ignoresSafeArea(edges: .all) // Now applying ignore to only video player
    }
}

