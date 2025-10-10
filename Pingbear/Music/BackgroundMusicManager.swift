import AVFoundation
import Combine
import UIKit

class BackgroundMusicManager: ObservableObject {
    static let shared = BackgroundMusicManager()
    
    private var audioPlayer: AVAudioPlayer?
    @Published var isMusicEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isMusicEnabled, forKey: "backgroundMusicEnabled")
            if isMusicEnabled {
                play()
            } else {
                pause()
            }
        }
    }
    
    private let targetVolume: Float = 0.7
    private let fadeDuration: TimeInterval = 1.5
    
    private init() {
        // Load saved preference, default to true (music on)
        self.isMusicEnabled = UserDefaults.standard.object(forKey: "backgroundMusicEnabled") as? Bool ?? true
        setupAudioSession()
        setupNotificationObservers()
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    func setupMusic(fileName: String, fileExtension: String = "mp3") {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            print("Background music file not found: \(fileName).\(fileExtension)")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 0 // Start at 0 for fade in
            audioPlayer?.prepareToPlay()
            
            // Auto-play if music is enabled
            if isMusicEnabled {
                play()
            }
        } catch {
            print("Failed to initialize audio player: \(error)")
        }
    }
    
    func play() {
        guard isMusicEnabled, let player = audioPlayer else { return }
        
        if !player.isPlaying {
            player.play()
        }
        
        // Fade in
        fadeVolume(to: targetVolume, duration: fadeDuration)
    }
    
    func pause() {
        guard let player = audioPlayer else { return }
        
        // Fade out then pause
        fadeVolume(to: 0, duration: fadeDuration) { [weak self] in
            player.pause()
        }
    }
    
    func stop() {
        guard let player = audioPlayer else { return }
        
        // Fade out then stop
        fadeVolume(to: 0, duration: fadeDuration) { [weak self] in
            player.stop()
        }
    }
    
    private func fadeVolume(to targetVolume: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        guard let player = audioPlayer else {
            completion?()
            return
        }
        
        let startVolume = player.volume
        let volumeChange = targetVolume - startVolume
        let steps: Float = 50
        let stepDuration = duration / Double(steps)
        let volumeStep = volumeChange / steps
        
        var currentStep: Float = 0
        
        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            currentStep += 1
            player.volume = startVolume + (volumeStep * currentStep)
            
            if currentStep >= steps {
                player.volume = targetVolume
                timer.invalidate()
                completion?()
            }
        }
    }
    
    @objc private func handleAppDidEnterBackground() {
        if isMusicEnabled {
            fadeVolume(to: 0, duration: 0.8) { [weak self] in
                self?.audioPlayer?.pause()
            }
        }
    }
    
    @objc private func handleAppWillEnterForeground() {
        if isMusicEnabled {
            // Reactivate audio session
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Failed to reactivate audio session: \(error)")
            }
            
            // Ensure player is ready and play
            audioPlayer?.prepareToPlay()
            play()
        }
    }
    
    @objc private func handleAppWillTerminate() {
        stop()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
