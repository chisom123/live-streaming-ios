import SwiftUI
import AVFoundation
import Combine
import PostHog

// MARK: Camera View Model
class CameraViewModel: NSObject,ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var currentCameraPosition: AVCaptureDevice.Position = .front
    @Published var alert = false
    @Published var preview : AVCaptureVideoPreviewLayer!
    
    // MARK: Video Recorder Properties
    @Published var isTakingPhoto = false
    @Published var capturedImage: UIImage?
    @Published var showPreview: Bool = false
    
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
                
                // Configure output settings
                if let photoConnection = photoOutput.connection(with: .video) {
                    if photoConnection.isVideoMirroringSupported {
                        photoConnection.isVideoMirrored = (currentCameraPosition == .front)
                    }
                }
            }
            
            self.session.commitConfiguration()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func capturePhoto() {
        guard !isTakingPhoto else { return }
        
        isTakingPhoto = true
        PostHogSDK.shared.capture("Photo Captured")
        
        let settings = AVCapturePhotoSettings()
        
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
               
        photoOutput.capturePhoto(with: settings, delegate: self)
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
