import AVFoundation
import Combine
import SwiftUI

class CameraManager: NSObject, ObservableObject {
    private var captureSession: AVCaptureSession?
    private var backCamera: AVCaptureDevice?
    private var frontCamera: AVCaptureDevice?
    private var currentCamera: AVCaptureDevice?
    private var photoOutput: AVCapturePhotoOutput?
    
    var cameraPreviewLayer: AVCaptureVideoPreviewLayer?

    @Published var image: UIImage?
    @Published var isCameraReady = false

    override init() {
        super.init()
        setupCaptureSession()
    }
    
    func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        setupDevice()
        setupInputOutput()
        setupPreviewLayer()
        startRunningCaptureSession()
    }
    
    func setupDevice() {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)
        
        let devices = deviceDiscoverySession.devices
        
        for device in devices {
            if device.position == AVCaptureDevice.Position.back {
                backCamera = device
            } else if device.position == AVCaptureDevice.Position.front {
                frontCamera = device
            }
        }
        
        currentCamera = frontCamera
    }
    
    func setupInputOutput() {
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: currentCamera!)
            captureSession!.addInput(captureDeviceInput)
            photoOutput = AVCapturePhotoOutput()
            photoOutput?.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])], completionHandler: nil)
            captureSession!.addOutput(photoOutput!)
        } catch {
            print(error)
        }
    }
    
    func setupPreviewLayer() {
        guard let captureSession = captureSession else { return }
        cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        cameraPreviewLayer?.videoGravity = .resizeAspectFill
        cameraPreviewLayer?.connection?.videoOrientation = .portrait
        DispatchQueue.main.async {
            self.isCameraReady = true
        }
    }

    func startRunningCaptureSession() {
        captureSession!.startRunning()
    }
    
    // Add the rest of the functions here...
    
    // Call this function to toggle the camera
    func toggleCamera() {
        // Implement camera toggle functionality
    }
    
    // Call this function to capture a photo
    func capturePhoto() {
        // Implement photo capture functionality
    }
    
    // Use this function to add pinch to zoom functionality
    func pinchToZoom(_ pinch: UIPinchGestureRecognizer) {
        // Implement pinch to zoom functionality
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        cameraManager.cameraPreviewLayer?.frame = view.frame
        if let previewLayer = cameraManager.cameraPreviewLayer {
            view.layer.addSublayer(previewLayer)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()

    var body: some View {
        ZStack {
            CameraPreview(cameraManager: cameraManager)

            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        cameraManager.capturePhoto()
                    }) {
                        Image(systemName: "camera.circle")
                            .font(.largeTitle)
                            .padding()
                    }
                    Button(action: {
                        cameraManager.toggleCamera()
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.largeTitle)
                            .padding()
                    }
                }
            }
        }
        .onAppear {
            cameraManager.setupCaptureSession()
        }
    }
}
