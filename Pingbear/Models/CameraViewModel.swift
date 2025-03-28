import SwiftUI
import AVFoundation
import Combine
import PostHog

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
    
    // Front camera screen flash with improved timing
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
        
        // Create flash view
        let flashView = UIView(frame: UIScreen.main.bounds)
        flashView.backgroundColor = .white
        flashView.alpha = 0
        
        // Add to key window
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.addSubview(flashView)
            
            // Pre-flash delay to ensure timing is correct
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                // Animation to simulate flash
                UIView.animate(withDuration: 0.15, animations: {
                    // Increase screen brightness to maximum
                    UIScreen.main.brightness = 1.0
                    flashView.alpha = 1.0
                }, completion: { _ in
                    // Call completion when flash is at peak brightness
                    // This is the critical timing improvement
                    completion()
                    
                    // Then fade out the flash
                    UIView.animate(withDuration: 0.25, animations: {
                        flashView.alpha = 0
                    }, completion: { _ in
                        // Remove flash view
                        flashView.removeFromSuperview()
                        self.flashView = nil
                        
                        // Restore original brightness with slight delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            UIView.animate(withDuration: 0.3) {
                                UIScreen.main.brightness = self.originalBrightness
                            }
                            self.isFlashing = false
                        }
                    })
                })
            }
        }
        
        self.flashView = flashView
    }
    
    // Improved ambient light detection for front camera
    func shouldUseFlashInAutoMode(forceLowLightThreshold: Bool = false) -> Bool {
        guard let device = AVCaptureDevice.default(for: .video) else { return false }
        
        do {
            try device.lockForConfiguration()
            
            // Check if low light boost is enabled (strong indicator)
            if device.isLowLightBoostSupported && device.isLowLightBoostEnabled {
                device.unlockForConfiguration()
                return true
            }
            
            if device.isExposureModeSupported(.continuousAutoExposure) {
                // Lower ISO threshold for front camera to be more sensitive
                // Front cameras usually have higher ISO in the same lighting conditions
                let isoDarkThreshold: Float = forceLowLightThreshold ? 300 : 500
                let isDark = device.iso > isoDarkThreshold
                
                // Also consider exposure duration as a factor
                let exposureDuration = CMTimeGetSeconds(device.exposureDuration)
                let isLongExposure = exposureDuration > 0.05 // 1/20th of a second
                
                device.unlockForConfiguration()
                return isDark || isLongExposure
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error checking light levels: \(error)")
        }
        
        return false
    }
    
    // Reset any ongoing flash operations
    func reset() {
        if let flashView = self.flashView {
            flashView.removeFromSuperview()
            self.flashView = nil
        }
        
        isFlashing = false
        
        // Reset screen brightness if it was changed
        if UIScreen.main.brightness > originalBrightness + 0.3 {
            UIScreen.main.brightness = originalBrightness
        }
    }
}

// MARK: Camera View Model
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
    
    private var photoOutput = AVCapturePhotoOutput()
    private var cancellables = Set<AnyCancellable>()
    
    func toggleCamera() {
        let newCameraPosition: AVCaptureDevice.Position = (currentCameraPosition == .front) ? .back : .front
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: newCameraPosition).devices

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
                currentCameraPosition = newCameraPosition
                
                // Update mirroring for front camera
                if let photoConnection = photoOutput.connection(with: .video) {
                    if photoConnection.isVideoMirroringSupported {
                        photoConnection.isVideoMirrored = (currentCameraPosition == .front)
                    }
                }
            }
            
            // Save the new camera position to UserDefaults
            UserDefaults.standard.set(currentCameraPosition.rawValue, forKey: "CameraPosition")
            
            session.commitConfiguration()
            PostHogSDK.shared.capture("Camera Toggled", properties: ["newPosition": newCameraPosition.rawValue])
        } catch {
            print("Failed to switch cameras: \(error)")
        }
        
        // Update flash availability after camera switch
        updateFlashAvailability()
    }
    
    func checkPermission(){
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUp()
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { (status) in
                if status {
                    DispatchQueue.main.async {
                        self.setUp()
                    }
                }
            }
        case .denied:
            self.alert.toggle()
            return
        default:
            return
        }
    }
    
    func setUp() {
        let cameraPosition = AVCaptureDevice.Position(rawValue: UserDefaults.standard.integer(forKey: "CameraPosition")) ?? .front
        currentCameraPosition = cameraPosition
        
        do {
            self.session.beginConfiguration()
            
            // Configure camera input
            guard let cameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
                return
            }
            let videoInput = try AVCaptureDeviceInput(device: cameraDevice)
            
            // Remove any existing inputs
            session.inputs.forEach { session.removeInput($0) }
            
            // Add new video input
            if self.session.canAddInput(videoInput) {
                self.session.addInput(videoInput)
            }
            
            // Configure photo output
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                
                // Configure output settings - this is the key part for mirroring
                if let photoConnection = photoOutput.connection(with: .video) {
                    if photoConnection.isVideoMirroringSupported {
                        // For preview, front camera should be mirrored
                        photoConnection.isVideoMirrored = (currentCameraPosition == .front)
                    }
                }
            }
            
            self.session.commitConfiguration()
        } catch {
            print(error.localizedDescription)
        }
        
        // Load saved flash mode
        if let savedFlashMode = FlashMode(rawValue: UserDefaults.standard.integer(forKey: "FlashMode")) {
            flashMode = savedFlashMode
        }
        
        // Reset any ongoing flash operations
        FlashService.shared.reset()
        
        updateFlashAvailability()
    }
    
    // Original capture photo method - kept for backward compatibility
    func capturePhoto() {
        guard !isTakingPhoto else { return }
        
        isTakingPhoto = true
        PostHogSDK.shared.capture("Photo Captured")
        
        let settings = AVCapturePhotoSettings()
        
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
               
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // Improved method for capturing photo with flash
    func capturePhotoWithFlash() {
        guard !isTakingPhoto else { return }
        
        isTakingPhoto = true
        
        var settings = AVCapturePhotoSettings()
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        
        // Preserve the mirroring behavior (this is crucial for front camera)
        if currentCameraPosition == .front {
            // Make sure to set the correct mirroring properties
            settings.isAutoStillImageStabilizationEnabled = true
            
            // Important: Don't modify the mirroring behavior from the original code
            if let photoConnection = photoOutput.connection(with: .video) {
                photoConnection.isVideoMirrored = true
            }
        }
        
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
                
                // Log analytics
                PostHogSDK.shared.capture("Photo Captured", properties: [
                    "flashMode": self.flashMode.title,
                    "camera": "front",
                    "flash": "screen"
                ])
                
                return // Early return because capture is done in completion handler
            }
        } else if currentCameraPosition == .back {
            // Configure flash for back camera (same as before)
            configureFlashForCapture(settings: &settings)
        }
        
        // For back camera or front without flash
        photoOutput.capturePhoto(with: settings, delegate: self)
        
        // Log analytics
        PostHogSDK.shared.capture("Photo Captured", properties: [
            "flashMode": flashMode.title,
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
            PostHogSDK.shared.capture("Flash Mode Changed", properties: ["mode": flashMode.title])
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
            }
        }
    }
}
