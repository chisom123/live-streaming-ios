import SwiftUI
import SwiftttCamera

struct CameraViewControllerRepresentable: UIViewControllerRepresentable {
    @Binding var shouldToggleCamera: Bool
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let cameraViewController = CameraViewController()
        return cameraViewController
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        if shouldToggleCamera {
            uiViewController.toggleCamera()
            DispatchQueue.main.async {
                self.shouldToggleCamera = false
            }
        }
    }

    typealias UIViewControllerType = CameraViewController
}

class CameraViewController: UIViewController, CameraDelegate {
    private lazy var camera: SwiftttCamera = {
        let result = SwiftttCamera()
        result.delegate = self
        result.view.translatesAutoresizingMaskIntoConstraints = false
        return result
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        swiftttAddChild(camera)
        camera.view.frame = view.frame
    }

    func cameraController(_ cameraController: CameraProtocol, didFinishCapturingImage capturedImage: CapturedImage) {
        // Handle the captured image
    }

    func toggleCamera() {
        let newCameraDevice: CameraDevice = camera.cameraDevice.toggling()
        guard SwiftttCamera.isCameraDeviceAvailable(newCameraDevice) else { return }
        camera.cameraDevice = newCameraDevice
    }
}

struct CameraView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var shouldToggleCamera = false
    
    var body: some View {
        ZStack {
            CameraViewControllerRepresentable(shouldToggleCamera: $shouldToggleCamera)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.5))
                            .clipShape(Circle())
                            .shadow(radius: 10)
                    }
                    Spacer()
                    Button(action: {
                        self.shouldToggleCamera.toggle()
                    }) {
                        Image(systemName: "camera.rotate")
                            .foregroundColor(.black)
                            .padding()
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 10)
                    }
                }
                .padding([.top, .leading, .trailing])
                Spacer() // This will push the top HStack to the top and the bottom button to the bottom
                
                Button(action: {
                    
                }) {
                    Image(systemName: "camera.circle")
                        .font(.system(size: 72))
                        .foregroundColor(.black)
                        .padding()
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 10)
                }
                .padding(.bottom)
            }
        }
    }
}
