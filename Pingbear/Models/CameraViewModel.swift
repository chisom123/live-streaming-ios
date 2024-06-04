import SwiftUI
import AVFoundation
import Combine
import PostHog

// MARK: Camera View Model
class CameraViewModel: NSObject,ObservableObject,AVCaptureFileOutputRecordingDelegate{
    @Published var session = AVCaptureSession()
    @Published var currentCameraPosition: AVCaptureDevice.Position = .front
    @Published var alert = false
    @Published var output = AVCaptureMovieFileOutput()
    @Published var preview : AVCaptureVideoPreviewLayer!
    
    // MARK: Video Recorder Properties
    @Published var isRecording: Bool = false
    @Published var recordedURLs: [URL] = []
    @Published var previewURL: URL?
    @Published var showPreview: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var pressTimer: AnyCancellable?
    
    // Top Progress Bar
    @Published var recordedDuration: CGFloat = 0
    // YOUR OWN TIMING
    @Published var maxDuration: CGFloat = 7.5
    
    func handlePress(isPressing: Bool) {
        if isPressing {
            // Start a timer when the press begins
            pressTimer = Just(true)
                .delay(for: .seconds(0.15), scheduler: RunLoop.main)
                .sink(receiveValue: { [weak self] _ in
                    self?.startRecording()
                })
        } else {
            // Cancel the timer if the press ends before the delay
            pressTimer?.cancel()
            stopRecording()
        }
    }
    
    func toggleCamera() {
        let newCameraPosition: AVCaptureDevice.Position = (currentCameraPosition == .front) ? .back : .front
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: newCameraPosition).devices

        guard let newCameraDevice = devices.first else { return }
        do {
            session.beginConfiguration()
            let newVideoInput = try AVCaptureDeviceInput(device: newCameraDevice)
            let audioDevice = AVCaptureDevice.default(for: .audio)
            let audioInput = try AVCaptureDeviceInput(device: audioDevice!)

            // Remove all current inputs
            for input in session.inputs {
                session.removeInput(input)
            }

            // Add new video input
            if session.canAddInput(newVideoInput) {
                session.addInput(newVideoInput)
                currentCameraPosition = newCameraPosition
            }

            // Re-add audio input
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
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
                
                if status{
                    self.setUp()
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
            guard let cameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
                return
            }
            let videoInput = try AVCaptureDeviceInput(device: cameraDevice)
            let audioDevice = AVCaptureDevice.default(for: .audio)
            let audioInput = try AVCaptureDeviceInput(device: audioDevice!)

            if self.session.canAddInput(videoInput) && self.session.canAddInput(audioInput) {
                self.session.addInput(videoInput)
                self.session.addInput(audioInput)
            }

            if session.canAddOutput(output) {
                session.addOutput(output)
                if let connection = output.connection(with: .video) {
                    if connection.isVideoMirroringSupported {
                        connection.isVideoMirrored = (currentCameraPosition == .front) ? false : true
                    }
                }
            }
            
            self.session.commitConfiguration()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func startRecording(){
        guard !isRecording else { return }
        PostHogSDK.shared.capture("Start Recording")
        
        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            connection.isVideoMirrored = (currentCameraPosition == .front)
        }
        let tempURL = NSTemporaryDirectory() + "\(Date()).mov"
        output.startRecording(to: URL(fileURLWithPath: tempURL), recordingDelegate: self)
        isRecording = true
    }
    
    func stopRecording(){
        output.stopRecording()
        isRecording = false
        PostHogSDK.shared.capture("Stop Recording", properties: ["duration": recordedDuration])
        DispatchQueue.main.async {
            if self.recordedDuration > 0.01 {
                self.showPreview = true
            }
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print(error.localizedDescription)
            return
        }
        
        print(outputFileURL)
        self.recordedURLs.append(outputFileURL)
        if self.recordedURLs.count == 1{
            self.previewURL = outputFileURL
            return
        }
    }
}
