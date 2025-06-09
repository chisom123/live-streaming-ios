import SwiftUI
import AVFoundation
import Combine

// MARK: - Flash Mode Enum
enum FlashMode: Int, CaseIterable {
    case auto
    case on
    case off
    
    var iconName: String {
        switch self {
        case .auto: return "bolt.badge.a"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash"
        }
    }
    
    var title: String {
        switch self {
        case .auto: return "Auto"
        case .on: return "On"
        case .off: return "Off"
        }
    }
}

// MARK: - FlashService
class FlashService {
    static let shared = FlashService()
    
    private var originalBrightness: CGFloat = UIScreen.main.brightness
    private var flashView: UIView?
    private var isFlashing = false
    
    // Cached ambient light data to avoid repeated expensive computations
    private var lastLightReadingTime: Date = Date.distantPast
    private var cachedShouldUseFlash: Bool = false
    private let lightReadingCacheTime: TimeInterval = 2.0 // 2 seconds cache
    
    // Front camera screen flash with improved timing and performance
    func enableScreenFlash(completion: @escaping () -> Void) {
        // Prevent multiple flashes from happening simultaneously
        guard !isFlashing, flashView == nil else {
            // If a flash is already in progress, just call completion
            completion()
            return
        }
        
        isFlashing = true
        
        // Store original brightness
        originalBrightness = UIScreen.main.brightness
        
        // Create flash view (lazily)
        let flashView = UIView(frame: UIScreen.main.bounds)
        flashView.backgroundColor = .white
        flashView.alpha = 0
        
        // Add to key window (dispatcher to UI thread)
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.addSubview(flashView)
                
                // Animation to simulate flash - use shorter duration for better performance
                UIView.animate(withDuration: 0.1, animations: {
                    // Increase screen brightness to maximum
                    UIScreen.main.brightness = 1.0
                    flashView.alpha = 1.0
                }, completion: { _ in
                    // Call completion when flash is at peak brightness
                    completion()
                    
                    // Then fade out the flash
                    UIView.animate(withDuration: 0.2, animations: {
                        flashView.alpha = 0
                    }, completion: { _ in
                        // Remove flash view
                        flashView.removeFromSuperview()
                        self.flashView = nil
                        
                        // Restore original brightness
                        UIScreen.main.brightness = self.originalBrightness
                        self.isFlashing = false
                    })
                })
            }
        }
        
        self.flashView = flashView
    }
    
    // Improved ambient light detection with caching for front camera
    func shouldUseFlashInAutoMode(forceLowLightThreshold: Bool = false) -> Bool {
        // Use cached value if recent enough
        let now = Date()
        if now.timeIntervalSince(lastLightReadingTime) < lightReadingCacheTime {
            return cachedShouldUseFlash
        }
        
        guard let device = AVCaptureDevice.default(for: .video) else {
            return false
        }
        
        var result = false
        
        do {
            try device.lockForConfiguration()
            
            // Check if low light boost is enabled (strong indicator)
            if device.isLowLightBoostSupported && device.isLowLightBoostEnabled {
                result = true
            } else if device.isExposureModeSupported(.continuousAutoExposure) {
                // Simplified threshold check for better performance
                let isoDarkThreshold: Float = forceLowLightThreshold ? 300 : 500
                result = device.iso > isoDarkThreshold
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error checking light levels: \(error)")
        }
        
        // Cache the result
        lastLightReadingTime = now
        cachedShouldUseFlash = result
        
        return result
    }
    
    // Reset any ongoing flash operations
    func reset() {
        if let flashView = self.flashView {
            DispatchQueue.main.async {
                flashView.removeFromSuperview()
            }
            self.flashView = nil
        }
        
        isFlashing = false
        
        // Reset screen brightness if it was changed
        if UIScreen.main.brightness > originalBrightness + 0.3 {
            DispatchQueue.main.async {
                UIScreen.main.brightness = self.originalBrightness
            }
        }
    }
}

// MARK: - Camera View Model with Performance Optimization
class CameraViewModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var currentCameraPosition: AVCaptureDevice.Position = .front
    @Published var alert = false
    @Published var preview : AVCaptureVideoPreviewLayer!
    
    // MARK: Video Recorder Properties
    @Published var isTakingPhoto = false
    @Published var capturedImage: UIImage?
    @Published var showPreview: Bool = false
    
    // MARK: Flash Properties
    @Published var flashMode: FlashMode = .auto
    @Published var isFlashAvailable: Bool = false
    
    // Session configuration queue for background processing
    private let sessionQueue = DispatchQueue(label: "session.queue", qos: .userInitiated)
    private var photoOutput = AVCapturePhotoOutput()
    private var cancellables = Set<AnyCancellable>()
    private var isConfigured = false
    
    override init() {
        super.init()
        
        // Load saved flash mode immediately
        if let savedFlashMode = FlashMode(rawValue: UserDefaults.standard.integer(forKey: "FlashMode")) {
            flashMode = savedFlashMode
        }
        
        // Load camera position from UserDefaults
        currentCameraPosition = AVCaptureDevice.Position(rawValue:
                               UserDefaults.standard.integer(forKey: "CameraPosition")) ?? .front
    }
    
    func toggleCamera() {
        let newCameraPosition: AVCaptureDevice.Position = (currentCameraPosition == .front) ? .back : .front
        
        // Save the new camera position to UserDefaults immediately
        UserDefaults.standard.set(newCameraPosition.rawValue, forKey: "CameraPosition")
        
        // Update UI state immediately
        currentCameraPosition = newCameraPosition
        
        // Perform actual device switching on background queue
        sessionQueue.async {
            self.reconfigureSession(with: newCameraPosition)
            
            // Update flash availability after camera switch
            DispatchQueue.main.async {
                self.updateFlashAvailability()
                Analytics.shared.track(event: "camera_toggled", properties: ["new_position": newCameraPosition == .front ? "front" : "back"])
            }
        }
    }
    
    private func reconfigureSession(with position: AVCaptureDevice.Position) {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: position
        ).devices
        
        guard let newCameraDevice = devices.first else { return }
        
        do {
            session.beginConfiguration()
            
            // Create new video input
            let newVideoInput = try AVCaptureDeviceInput(device: newCameraDevice)
            
            // Remove all current inputs
            session.inputs.forEach { session.removeInput($0) }
            
            // Add new video input
            if session.canAddInput(newVideoInput) {
                session.addInput(newVideoInput)
                
                // Update mirroring for front camera
                if let photoConnection = photoOutput.connection(with: .video) {
                    if photoConnection.isVideoMirroringSupported {
                        photoConnection.isVideoMirrored = (position == .front)
                    }
                }
            }
            
            session.commitConfiguration()
        } catch {
            print("Failed to switch cameras: \(error)")
        }
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Only configure session if not already configured
            if !isConfigured {
                sessionQueue.async {
                    self.configureSession()
                    
                    DispatchQueue.main.async {
                        self.isConfigured = true
                        self.updateFlashAvailability()
                    }
                }
            }
            return
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] status in
                guard let self = self, status else { return }
                
                DispatchQueue.main.async {
                    if !self.isConfigured {
                        self.sessionQueue.async {
                            self.configureSession()
                            
                            DispatchQueue.main.async {
                                self.isConfigured = true
                                self.updateFlashAvailability()
                            }
                        }
                    }
                }
            }
            
        case .denied:
            DispatchQueue.main.async {
                self.alert.toggle()
            }
            return
            
        default:
            return
        }
    }
    
    private func configureSession() {
        do {
            session.beginConfiguration()
            
            // Configure camera input
            guard let cameraDevice = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: currentCameraPosition
            ) else {
                return
            }
            
            let videoInput = try AVCaptureDeviceInput(device: cameraDevice)
            
            // Remove any existing inputs
            session.inputs.forEach { session.removeInput($0) }
            
            // Add new video input
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }
            
            // Configure photo output if not already added
            if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                
                // Configure output settings for mirroring
                if let photoConnection = photoOutput.connection(with: .video) {
                    if photoConnection.isVideoMirroringSupported {
                        photoConnection.isVideoMirrored = (currentCameraPosition == .front)
                    }
                }
            }
            
            session.commitConfiguration()
            
            // Start session running on background thread
            if !session.isRunning {
                session.startRunning()
            }
        } catch {
            print("Session configuration error: \(error.localizedDescription)")
        }
    }
    
    func stopSession() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
                print("Camera session stopped")
            }
            
            DispatchQueue.main.async {
                // Reset flash when stopping session
                self.resetFlash()
                
                // Reset configuration flag so it can be reconfigured when needed again
                self.isConfigured = false
            }
        }
    }
    
    // Improved method for capturing photo with flash
    func capturePhotoWithFlash() {
        guard !isTakingPhoto else { return }
        
        isTakingPhoto = true
        
        var settings = AVCapturePhotoSettings()
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        
        // Handle front camera flash with improved timing
        if currentCameraPosition == .front && flashMode != .off {
            let shouldUseFlash = (flashMode == .on) ||
                                (flashMode == .auto && FlashService.shared.shouldUseFlashInAutoMode(forceLowLightThreshold: true))
            
            if shouldUseFlash {
                // Use screen flash with improved synchronization
                FlashService.shared.enableScreenFlash {
                    // This closure is called at peak flash brightness
                    self.photoOutput.capturePhoto(with: settings, delegate: self)
                }
                
                // Track analytics
                Analytics.shared.track(event: "photo_captured", properties: [
                    "flash_mode": self.flashMode.title,
                    "camera": "front",
                    "flash": "screen"
                ])
                
                return // Early return because capture is done in completion handler
            }
        } else if currentCameraPosition == .back {
            // Configure flash for back camera
            configureFlashForCapture(settings: &settings)
        }
        
        // For back camera or front without flash
        photoOutput.capturePhoto(with: settings, delegate: self)
        
        // Track analytics
        Analytics.shared.track(event: "photo_captured", properties: [
            "flash_mode": flashMode.title,
            "camera": currentCameraPosition == .front ? "front" : "back",
            "flash": currentCameraPosition == .back && flashMode != .off ? "physical" : "none"
        ])
    }
    
    // Reset flash when the camera view is closed or reset
    func resetFlash() {
        FlashService.shared.reset()
    }
    
    // MARK: Flash Methods
    // Improved flash availability check
    func updateFlashAvailability() {
        if currentCameraPosition == .front {
            // Front camera always has "flash" via screen flash
            isFlashAvailable = true
            return
        }
        
        // For back camera, check physical flash
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
            isFlashAvailable = false
            return
        }
        
        do {
            try device.lockForConfiguration()
            isFlashAvailable = device.hasTorch && device.isTorchAvailable
            device.unlockForConfiguration()
        } catch {
            print("Error checking flash availability: \(error)")
            isFlashAvailable = false
        }
    }
    
    func toggleFlashMode() {
        let modes = FlashMode.allCases
        if let currentIndex = modes.firstIndex(of: flashMode) {
            let nextIndex = (currentIndex + 1) % modes.count
            flashMode = modes[nextIndex]
            Analytics.shared.track(event: "flash_mode_changed", properties: ["mode": flashMode.title])
        }
        
        // Save the flash mode to UserDefaults
        UserDefaults.standard.set(flashMode.rawValue, forKey: "FlashMode")
    }
    
    func configureFlashForCapture(settings: inout AVCapturePhotoSettings) {
        // For back camera with physical flash
        if currentCameraPosition == .back && isFlashAvailable {
            switch flashMode {
            case .on:
                settings.flashMode = .on
            case .off:
                settings.flashMode = .off
            case .auto:
                // Use auto mode or decide based on ambient light
                if FlashService.shared.shouldUseFlashInAutoMode() {
                    settings.flashMode = .on
                } else {
                    settings.flashMode = .auto
                }
            }
        }
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            isTakingPhoto = false
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("Error: no image data captured")
            isTakingPhoto = false
            return
        }
        
        if let image = UIImage(data: imageData) {
            DispatchQueue.main.async {
                self.capturedImage = image
                self.isTakingPhoto = false
                self.showPreview = true
                
                self.stopSession()
            }
        }
    }
}
