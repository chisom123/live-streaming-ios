import SwiftUI
import AVKit
import Combine
import Foundation

struct CustomVideoPlayer: UIViewControllerRepresentable {
    var url: URL
    @Binding var isPlaying: Bool
    var overlayText: String
    var overlayVerticalPosition: CGFloat
    @Binding var isViewClosing: Bool

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
        context.coordinator.updateOverlay(uiViewController, text: overlayText, verticalPosition: overlayVerticalPosition, isViewClosing: isViewClosing)
    }

    // Use this method to cleanup when the view is being deinitialized
    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.cleanup(uiViewController)
    }

    class Coordinator {
        var parent: CustomVideoPlayer
        var player: AVPlayer?
        var overlayLabel: UILabel?
        var constraints: [NSLayoutConstraint] = []

        init(_ parent: CustomVideoPlayer) {
            self.parent = parent
        }

        func setupPlayer(for playerViewController: AVPlayerViewController, with url: URL) {
            self.player = AVPlayer(url: url)
            playerViewController.player = self.player
            playerViewController.showsPlaybackControls = false
            
            // Ensure contentOverlayView is properly sized
            playerViewController.contentOverlayView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            playerViewController.contentOverlayView?.frame = playerViewController.view.bounds
            
            // Configure audio session
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Failed to set audio session category. Error: \(error.localizedDescription)")
            }
            
            // Add overlay label
            let label = UILabel()
            label.textColor = .white
            label.font = UIFont.customBoldFont(ofSize: 24)
            label.textAlignment = .center
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping

            label.layer.shadowColor = UIColor.black.cgColor
            label.layer.shadowOffset = CGSize(width: 1, height: 1)
            label.layer.shadowRadius = 2
            label.layer.shadowOpacity = 1

            playerViewController.contentOverlayView?.addSubview(label)
            self.overlayLabel = label
            
            label.translatesAutoresizingMaskIntoConstraints = false

            playerViewController.contentOverlayView?.bringSubviewToFront(label)

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
        
        func updateOverlay(_ uiViewController: AVPlayerViewController, text: String, verticalPosition: CGFloat, isViewClosing: Bool) {
            guard let label = overlayLabel else { return }
            
            // If the view is closing, hide the label
            label.isHidden = isViewClosing
            
            // If the label is hidden, we don't need to update its text or position
            if isViewClosing {
                return
            }
            
            label.text = text

            // Use player view bounds if contentOverlayView frame is zero
            let referenceView: UIView
            if let contentOverlay = uiViewController.contentOverlayView, contentOverlay.frame.size != .zero {
                referenceView = contentOverlay
            } else {
                referenceView = uiViewController.view
            }
            
            NSLayoutConstraint.deactivate(constraints)
            constraints.removeAll()
            
            let desiredWidth = referenceView.bounds.width * 0.8
            
            let centerX = label.centerXAnchor.constraint(equalTo: referenceView.centerXAnchor)
            let width = label.widthAnchor.constraint(equalToConstant: desiredWidth)
            let centerY = label.centerYAnchor.constraint(equalTo: referenceView.topAnchor, constant: verticalPosition)
            
            constraints = [centerX, width, centerY]
            NSLayoutConstraint.activate(constraints)
            
            label.setNeedsLayout()
            label.layoutIfNeeded()
        }

        func cleanup(_ uiViewController: AVPlayerViewController) {
            uiViewController.player?.pause()
            overlayLabel?.removeFromSuperview()
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
