import SwiftUI
import AVKit
import AVFoundation

// ─────────────────────────────────────────────────────────────
// MARK: - VideoPosterFrame
// Grabs the first frame of a remote video and shows it as a
// static image — used for the locked/blurred offer tease so we
// never decode+blur an actual playing video.
// ─────────────────────────────────────────────────────────────

struct VideoPosterFrame: View {
    let url: URL

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.black
            }
        }
        .task { await loadFrame() }
    }

    private func loadFrame() async {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 800, height: 1422)

        do {
            let cgImage = try await generator.image(at: .zero).image
            await MainActor.run { image = UIImage(cgImage: cgImage) }
        } catch {
            // leave as black background on failure — still works, just no thumbnail
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - RevealedOfferVideoPlayer
// Full-screen, looping, autoplaying video for the unlocked offer
// moment. Plays immediately when this view appears — the
// countdown + haptic punch already built the anticipation, so
// the video itself is the payoff with no further delay.
// ─────────────────────────────────────────────────────────────

struct RevealedOfferVideoPlayer: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        let player = AVPlayer(url: url)
        player.isMuted = false

        let vc = AVPlayerViewController()
        vc.player                = player
        vc.showsPlaybackControls = false
        vc.videoGravity          = .resizeAspectFill

        context.coordinator.loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object:  player.currentItem,
            queue:   .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        player.play()
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleUIViewController(_ vc: AVPlayerViewController, coordinator: Coordinator) {
        vc.player?.pause()
        if let obs = coordinator.loopObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    class Coordinator {
        var loopObserver: NSObjectProtocol?
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - CreatorOfferVideoPreview
// Small muted looping preview so the creator can watch back what
// they sent, on the completed offer screen.
// ─────────────────────────────────────────────────────────────

struct CreatorOfferVideoPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(url: url)
        player.isMuted = true

        let vc = AVPlayerViewController()
        vc.player                = player
        vc.showsPlaybackControls = false
        vc.videoGravity          = .resizeAspectFill

        context.coordinator.loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object:  player.currentItem,
            queue:   .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        player.play()
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleUIViewController(_ vc: AVPlayerViewController, coordinator: Coordinator) {
        vc.player?.pause()
        if let obs = coordinator.loopObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    class Coordinator {
        var loopObserver: NSObjectProtocol?
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - InlineVideoPlayer
// Inline 9:16 player used across multiple flows. The caller
// controls play/pause via the isActive binding — no guessing.
// ─────────────────────────────────────────────────────────────

struct InlineVideoPlayer: UIViewControllerRepresentable {
    let url:        URL
    @Binding var isActive:  Bool
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.showsPlaybackControls = false
        vc.videoGravity          = .resizeAspectFill
        context.coordinator.load(into: vc, url: url, isActive: isActive, isLoading: $isLoading)
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        if context.coordinator.loadedURL != url {
            // The URL changed (e.g. Retake produced a new recording) —
            // rebuild the player instead of silently keeping the old one.
            context.coordinator.load(into: vc, url: url, isActive: isActive, isLoading: $isLoading)
        } else {
            context.coordinator.update(isActive: isActive, vc: vc)
        }
    }

    static func dismantleUIViewController(_ vc: AVPlayerViewController, coordinator: Coordinator) {
        vc.player?.pause()
        coordinator.teardown()
    }

    final class Coordinator {
        private(set) var loadedURL: URL?
        private var loopObserver:         NSObjectProtocol?
        private var interruptionObserver: NSObjectProtocol?
        private var statusObserver:       NSKeyValueObservation?
        private var currentIsActive = true

        func load(into vc: AVPlayerViewController, url: URL, isActive: Bool, isLoading: Binding<Bool>) {
            teardown()
            loadedURL       = url
            currentIsActive = isActive

            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("🟣 InlineVideoPlayer: audio session setup FAILED: \(error)")
            }

            let player = AVPlayer(url: url)
            player.isMuted = false
            vc.player = player

            loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main
            ) { [weak self] _ in
                player.seek(to: .zero)
                if self?.currentIsActive == true { player.play() }
            }

            interruptionObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(), queue: .main
            ) { [weak self] note in
                guard let self,
                      let info = note.userInfo,
                      let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue)
                else { return }
                guard type == .ended else { return }
                try? AVAudioSession.sharedInstance().setActive(true)
                if self.currentIsActive { player.play() }
            }

            statusObserver = player.currentItem?.observe(\.status, options: [.new, .initial]) { item, _ in
                DispatchQueue.main.async { isLoading.wrappedValue = (item.status != .readyToPlay) }
            }

            if isActive { player.play() }
        }

        func update(isActive: Bool, vc: AVPlayerViewController) {
            currentIsActive = isActive
            if isActive {
                if vc.player?.timeControlStatus == .paused { vc.player?.play() }
            } else {
                vc.player?.pause()
            }
        }

        func teardown() {
            if let obs = loopObserver         { NotificationCenter.default.removeObserver(obs) }
            if let obs = interruptionObserver { NotificationCenter.default.removeObserver(obs) }
            statusObserver?.invalidate()
            loopObserver         = nil
            interruptionObserver = nil
            statusObserver       = nil
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - FullScreenVideoView
// ─────────────────────────────────────────────────────────────

struct FullScreenVideoView: View {
    let url:       URL
    let onDismiss: () -> Void

    @State private var player:       AVPlayer?
    @State private var loopObserver: NSObjectProtocol?
    @State private var isLoading     = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                FullScreenFillPlayer(player: player, isLoading: $isLoading)
                    .ignoresSafeArea()
            }

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.3)
            }
        }
        .onAppear { setupPlayer() }
        .onDisappear { teardown() }
        .onTapGesture { onDismiss() }
    }

    private func setupPlayer() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        let p = AVPlayer(url: url)
        p.isMuted = false
        player = p

        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object:  p.currentItem,
            queue:   .main
        ) { _ in p.seek(to: .zero); p.play() }

        p.play()
    }

    private func teardown() {
        player?.pause()
        player = nil
        if let obs = loopObserver {
            NotificationCenter.default.removeObserver(obs)
            loopObserver = nil
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - FullScreenFillPlayer
// ─────────────────────────────────────────────────────────────

struct FullScreenFillPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(isLoading: $isLoading) }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player                = player
        vc.showsPlaybackControls = false
        vc.videoGravity          = .resizeAspectFill

        context.coordinator.statusObserver = player.currentItem?.observe(\.status, options: [.new, .initial]) { item, _ in
            DispatchQueue.main.async {
                context.coordinator.isLoading.wrappedValue = (item.status != .readyToPlay)
            }
        }
        context.coordinator.rateObserver = player.observe(\.timeControlStatus, options: [.new]) { p, _ in
            DispatchQueue.main.async {
                if p.timeControlStatus == .playing {
                    context.coordinator.isLoading.wrappedValue = false
                }
            }
        }

        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(_ vc: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.statusObserver?.invalidate()
        coordinator.rateObserver?.invalidate()
    }

    class Coordinator {
        var statusObserver: NSKeyValueObservation?
        var rateObserver:   NSKeyValueObservation?
        let isLoading: Binding<Bool>
        init(isLoading: Binding<Bool>) { self.isLoading = isLoading }
    }
}
