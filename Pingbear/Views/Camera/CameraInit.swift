import SwiftUI
import AVFoundation

struct CameraInitView: View {
    @EnvironmentObject var cameraModel: CameraViewModel
    
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            
            ZStack {
                // Only show a placeholder color until the camera is ready
                Color.black
                
                // Actual camera preview
                CameraPreview(size: size)
                    .environmentObject(cameraModel)
            }
        }
        .onAppear {
            // Request camera permissions right away
            cameraModel.checkPermission()
        }
        .alert(isPresented: $cameraModel.alert) {
            Alert(title: Text("Please Enable camera access"))
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    @EnvironmentObject var cameraModel: CameraViewModel
    var size: CGSize
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        
        // Configure preview layer
        cameraModel.preview = AVCaptureVideoPreviewLayer(session: cameraModel.session)
        cameraModel.preview.frame.size = size
        cameraModel.preview.videoGravity = .resizeAspectFill
        
        // Add preview layer to view
        view.layer.addSublayer(cameraModel.preview)
        
        // Don't start the session here - it's already started in the ViewModel
        // Let the ViewModel handle session management on a background queue
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame when view size changes
        cameraModel.preview.frame.size = size
    }
}
