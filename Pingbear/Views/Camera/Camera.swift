import SwiftUI
import PhotosUI

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
        // Always enabled for front camera, and conditionally for back camera
        .opacity(cameraModel.isFlashAvailable ? 1.0 : 0.5)
    }
}

struct CameraView: View {
    @StateObject var cameraModel = CameraViewModel()
    var competition: Competition
    @State private var navigateToCompDetails = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var imageSource: ImageSource = .camera
    
    enum ImageSource {
        case camera
        case gallery
    }
    
    var body: some View {
        ZStack {
            // MARK: Camera View
            CameraInitView()
                .environmentObject(cameraModel)
                .ignoresSafeArea()
            
            // Controls
            VStack {
                HStack {
                    Button {
                        navigateToCompDetails = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding(5)
                            .shadow(radius: 10)
                    }
                    
                    Spacer()
                    
                    // Flash button
                    FlashButton(cameraModel: cameraModel)
                    
                    Spacer()
                    
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
                .padding(.top, 5)
                .padding(20)
                
                Spacer()

                // Bottom Controls
                HStack(spacing: 60) {
                    
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    // Camera Button
                    Button(action: {
                        imageSource = .camera
                        cameraModel.capturePhotoWithFlash() // Using improved method with flash
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
                    .disabled(cameraModel.isTakingPhoto)
                    
                    // Spacer to maintain symmetry
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 60, height: 60)
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
                    isFromCamera: imageSource == .camera
                )
            }
        })
        .fullScreenCover(isPresented: $navigateToCompDetails) {
            CompDetails(competition: competition)
        }
        .onAppear {
            cameraModel.checkPermission() // This will call setUp() which now includes flash setup
        }
        .onDisappear {
            // Make sure to reset flash when view disappears
            cameraModel.resetFlash()
        }
    }
    
    private func resetCamera() {
        cameraModel.capturedImage = nil
        cameraModel.session.startRunning()
        cameraModel.resetFlash() // Make sure to reset flash state
        imageSource = .camera
        selectedItem = nil
        selectedImage = nil
    }
}
