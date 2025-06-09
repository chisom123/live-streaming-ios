import SwiftUI
import PhotosUI

struct CameraView: View {
    // Use StateObject for view-owned objects, ObservedObject for parent-injected
    @StateObject private var cameraModel = CameraViewModel()
    var competition: Competition
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var imageSource: ImageSource = .camera
    @State private var isViewAppeared = false
    @State private var selectedTheme: Theme?
    @StateObject private var themesViewModel = ThemesViewModel()
    @State private var showingThemeSelection = false
    
    enum ImageSource {
        case camera
        case gallery
    }
    
    var body: some View {
        ZStack {
            // MARK: Camera View
            if isViewAppeared {
                CameraInitView()
                    .environmentObject(cameraModel)
                    .ignoresSafeArea()
            } else {
                // Show a loading placeholder until view appears
                Color.black
                    .ignoresSafeArea()
            }
            
            // Controls overlay
            VStack {
                HStack {
                    Button {
                        cameraModel.stopSession()
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
                            
                            if let theme = selectedTheme {
                                // Show the selected theme name directly in the button
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
                        .padding(.vertical, 8)
                        .background(Color(hex: "#FF8C00"))
                        .cornerRadius(200)
                    }
                    
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
                
                HStack {
                    Spacer()
                    FlashButton(cameraModel: cameraModel)
                }
                .padding(.trailing, 20)
                
                Spacer()

                // Bottom Controls
                HStack(spacing: 0) {
                    // Camera Button
                    Button(action: {
                        imageSource = .camera
                        cameraModel.capturePhotoWithFlash()
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
                    selectedTheme: $selectedTheme,
                    isFromCamera: imageSource == .camera
                )
            }
        })
        .sheet(isPresented: $showingThemeSelection) {
            ThemeSelectionSheet(
                viewModel: themesViewModel,
                competitionId: competition.id,
                selectedTheme: $selectedTheme
            )
        }
        .onAppear {
            // Optimization: Mark the view as appeared first, then request camera setup
            // This allows UI to render immediately while camera initializes in background
            DispatchQueue.main.async {
                self.isViewAppeared = true
                // Camera permission check will be triggered by CameraInitView
                
                // Load themes when view appears
                themesViewModel.loadThemes(for: competition.id)
            }
        }
        .onDisappear {
            // Clean up resources when view disappears
            cameraModel.resetFlash()
            cameraModel.stopSession()
        }
    }
    
    private func resetCamera() {
        cameraModel.capturedImage = nil
        cameraModel.resetFlash()
        cameraModel.checkPermission()
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
        // Always enabled for front camera, and conditionally for back camera
        .opacity(cameraModel.isFlashAvailable ? 1.0 : 0.5)
    }
}
