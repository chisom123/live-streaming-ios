import SwiftUI
import AVFoundation

// A UIViewControllerRepresentable to manage the camera session
struct CameraViewController: UIViewControllerRepresentable {
    class Coordinator: NSObject, AVCapturePhotoCaptureDelegate {
        var parent: CameraViewController
        var photoOutput = AVCapturePhotoOutput()
        
        init(parent: CameraViewController) {
            self.parent = parent
        }
        
        func capturePhoto() {
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
        
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            guard let imageData = photo.fileDataRepresentation() else { return }
            
            // Here we can use the image data, for example, save it or pass it to the SwiftUI view
            parent.photoCapturedHandler?(UIImage(data: imageData))
        }
    }
    
    var photoCapturedHandler: ((UIImage?) -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let captureSession = AVCaptureSession()
        
        guard let camera = AVCaptureDevice.default(for: .video) else {
            fatalError("No video camera available")
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            if captureSession.canAddOutput(context.coordinator.photoOutput) {
                captureSession.addOutput(context.coordinator.photoOutput)
            }
        } catch {
            fatalError(error.localizedDescription)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = viewController.view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        viewController.view.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Here you can update your UI if needed
    }
}

struct CameraView: View {
    @State private var capturedImage: UIImage?
    @StateObject private var cameraController = CameraController() // CameraController manages AVCaptureSession
    
    var body: some View {
        ZStack {
            CameraViewController(photoCapturedHandler: { image in
                self.capturedImage = image
                // Here you can handle the captured image, for example, show it on the UI or save it
            })
            VStack {
                HStack {
                    Button(action: {
                        // Your close action here
                    }) {
                        Image(systemName: "xmark.circle.fill") // Using system image for simplicity
                            .resizable()
                            .frame(width: 40, height: 40)
                            .padding(.leading, 20)
                            .padding(.top, 20)
                    }
                    
                    Spacer()
                }
                Spacer()
                
                Button(action: {
                    // This will trigger photo capture
                    cameraController.capturePhoto()
                }) {
                    Image(systemName: "camera.circle") // Using system image for simplicity
                        .resizable()
                        .frame(width: 70, height: 70)
                        .padding(.bottom, 40)
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            cameraController.setupSession()
        }
    }
}

class CameraController: NSObject, ObservableObject {
    private var captureSession: AVCaptureSession?
    private let photoOutput = AVCapturePhotoOutput()
    private var photoCaptureCompletionHandler: ((UIImage?) -> Void)?

    func setupSession() {
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else { return }
        
        guard let camera = AVCaptureDevice.default(for: .video) else {
            fatalError("No video camera available")
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        photoCaptureCompletionHandler?(UIImage(data: imageData))
    }
}
