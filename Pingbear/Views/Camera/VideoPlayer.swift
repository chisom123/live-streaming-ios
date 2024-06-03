import SwiftUI
import AVKit
import Combine
import Foundation

struct CustomVideoPlayer: UIViewControllerRepresentable {
    var url: URL
    @Binding var isPlaying: Bool

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
        context.coordinator.updatePlayer(uiViewController, isPlaying: isPlaying)
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
            
            // Configure audio session
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Failed to set audio session category. Error: \(error.localizedDescription)")
            }

            setupLifecycleNotifications(playerViewController)
        }

        func updatePlayer(_ uiViewController: AVPlayerViewController, isPlaying: Bool) {
            if uiViewController.player == nil {
                uiViewController.player = player
                uiViewController.player?.actionAtItemEnd = .none
            }
            
            if isPlaying {
                player?.play()
            } else {
                player?.pause()
            }

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
            if parent.isPlaying {
                player?.play()
            }
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
