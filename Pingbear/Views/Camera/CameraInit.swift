import SwiftUI
import AVFoundation


struct CameraInitView: View {
    @EnvironmentObject var cameraModel: CameraViewModel
    
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            
            CameraPreview(size: size)
                .environmentObject(cameraModel)
        }
        .onAppear(perform: cameraModel.checkPermission)
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
        
        cameraModel.preview = AVCaptureVideoPreviewLayer(session: cameraModel.session)
        cameraModel.preview.frame.size = size
        cameraModel.preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(cameraModel.preview)
        
        cameraModel.session.startRunning()
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame when view size changes
        cameraModel.preview.frame.size = size
    }
}
