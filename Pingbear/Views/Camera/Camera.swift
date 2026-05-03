import SwiftUI
import PhotosUI
struct CameraView: View {
    @StateObject private var cameraModel = CameraViewModel()
    var competition: Competition
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var imageSource: ImageSource = .camera
    @State private var isViewAppeared = false
    @Binding var preselectedTheme: Theme?
    @StateObject private var themesViewModel = ThemesViewModel()
    @State private var showingThemeSelection = false
    
    // Simulator detection
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    enum ImageSource {
        case camera
        case gallery
    }
    
    var body: some View {
        ZStack {
            // MARK: Camera View - Show placeholder in simulator
            if isViewAppeared {
                if isSimulator {
                    // Placeholder view for simulator
                    ZStack {
                        Color.gray.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("Simulator Mode")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            Text("Camera preview unavailable\nTap button to capture test image")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                    }
                } else {
                    CameraInitView()
                        .environmentObject(cameraModel)
                        .ignoresSafeArea()
                }
            } else {
                Color.black
                    .ignoresSafeArea()
            }
            
            // Controls overlay
            VStack {
                HStack {
                    Button {
                        if !isSimulator {
                            cameraModel.stopSession()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding(5)
                            .shadow(radius: 10)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showingThemeSelection = true
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                            
                            if let theme = preselectedTheme {
                                Text(theme.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .truncationMode(.tail)
                                    .lineLimit(1)
                            } else {
                                Text("Add Theme")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#4169E1"))
                        .cornerRadius(200)
                    }
                    
                    Spacer()
                    
                    if !isSimulator {
                        Button(action: {
                            cameraModel.toggleCamera()
                        }) {
                            Image(systemName: "arrow.2.circlepath")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .padding(5)
                                .shadow(radius: 10)
                        }
                    }
                }
                .padding(.top, 5)
                .padding(20)
                
                if !isSimulator {
                    HStack {
                        Spacer()
                        FlashButton(cameraModel: cameraModel)
                    }
                    .padding(.trailing, 20)
                }
                
                Spacer()
                // Bottom Controls
                HStack(spacing: 0) {
                    Button(action: {
                        imageSource = .camera
                        if isSimulator {
                            captureSimulatorImage()
                        } else {
                            cameraModel.capturePhotoWithFlash()
                        }
                    }) {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 100, height: 100)
                            .contentShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 8)
                            )
                    }
                    .disabled(!isSimulator && cameraModel.isTakingPhoto)
                }
                .padding(.bottom, 50)
            }
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    imageSource = .gallery
                    cameraModel.showPreview = true
                    cameraModel.capturedImage = image
                    selectedImage = image
                }
            }
        }
        .fullScreenCover(isPresented: $cameraModel.showPreview, content: {
            if let image = cameraModel.capturedImage {
                FinalPreview(
                    image: image,
                    showPreview: $cameraModel.showPreview,
                    competition: competition,
                    competitionId: competition.id,
                    resetCameraAction: { self.resetCamera() },
                    selectedTheme: $preselectedTheme,
                    isFromCamera: imageSource == .camera
                )
            }
        })
        .sheet(isPresented: $showingThemeSelection) {
            ThemeSelectionSheet(
                viewModel: themesViewModel,
                competitionId: competition.id,
                selectedTheme: $preselectedTheme
            )
        }
        .onAppear {
            DispatchQueue.main.async {
                self.isViewAppeared = true
                
                if !isSimulator {
                    // Only initialize camera on real device
                }
                
                themesViewModel.loadThemes(for: competition.id)
            }
        }
        .onDisappear {
            if !isSimulator {
                cameraModel.resetFlash()
                cameraModel.stopSession()
            }
        }
    }
    
    // Generate a test image for simulator
    private func captureSimulatorImage() {
        let size = CGSize(width: 1080, height: 1920)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let testImage = renderer.image { context in
            // Create a gradient background
            let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors as CFArray,
                                     locations: [0.0, 1.0])!
            
            context.cgContext.drawLinearGradient(gradient,
                                                 start: CGPoint(x: 0, y: 0),
                                                 end: CGPoint(x: size.width, y: size.height),
                                                 options: [])
            
            // Add some text
            let text = "Test Photo"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 60),
                .foregroundColor: UIColor.white
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(x: (size.width - textSize.width) / 2,
                                 y: (size.height - textSize.height) / 2,
                                 width: textSize.width,
                                 height: textSize.height)
            
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        cameraModel.capturedImage = testImage
        cameraModel.showPreview = true
    }
    
    private func resetCamera() {
        cameraModel.capturedImage = nil
        if !isSimulator {
            cameraModel.resetFlash()
            cameraModel.checkPermission()
        }
        imageSource = .camera
        selectedItem = nil
        selectedImage = nil
    }
}
// MARK: - Flash Button Component
struct FlashButton: View {
    @ObservedObject var cameraModel: CameraViewModel
    
    var body: some View {
        Button(action: {
            cameraModel.toggleFlashMode()
        }) {
            Image(systemName: cameraModel.flashMode.iconName)
                .font(.system(size: 30))
                .foregroundColor(.white)
                .padding(5)
                .shadow(radius: 10)
        }
        .opacity(cameraModel.isFlashAvailable ? 1.0 : 0.5)
    }
}

