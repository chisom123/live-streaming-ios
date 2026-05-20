import SwiftUI
import AVFoundation
import PhotosUI

struct RoundCameraView: View {

    let competition: Competition
    let themeName: String
    let onPhotoSelected: (UIImage, Bool) -> Void
    let onCancel: () -> Void

    @StateObject private var cameraModel = CameraViewModel()

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var capturedImage: UIImage? = nil
    @State private var imageSource: ImageSource = .camera
    @State private var isViewAppeared = false
    @State private var showingPreview = false
    @State private var isLoadingFromLibrary = false
    @State private var showingPermissionAlert = false

    enum ImageSource {
        case camera, library
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isViewAppeared {
                CameraInitView()
                    .environmentObject(cameraModel)
                    .ignoresSafeArea()
            }

            VStack {
                topBar
                Spacer()
                bottomBar
            }

            if isLoadingFromLibrary {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.4)
                        Text("Loading photo...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onChange(of: selectedItem) { newItem in
            guard let newItem else { return }
            isLoadingFromLibrary = true
            Task {
                do {
                    if let data = try await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            imageSource = .library
                            capturedImage = image
                            isLoadingFromLibrary = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                cameraModel.stopSession()
                                showingPreview = true
                            }
                        }
                    } else {
                        await MainActor.run { isLoadingFromLibrary = false }
                    }
                } catch {
                    await MainActor.run {
                        isLoadingFromLibrary = false
                        Analytics.shared.trackError(
                            message: "Failed to load photo from library: \(error.localizedDescription)",
                            properties: [AnalyticsProperty.competitionId: competition.id]
                        )
                        print("RoundCameraView: Failed to load from library: \(error)")
                    }
                }
            }
        }
        .onChange(of: cameraModel.showPreview) { isShowing in
            guard isShowing, let image = cameraModel.capturedImage else { return }
            imageSource = .camera
            capturedImage = image
            cameraModel.showPreview = false
            showingPreview = true
        }
        .fullScreenCover(isPresented: $showingPreview) {
            if let image = capturedImage {
                RoundPhotoPreview(
                    image: image,
                    themeName: themeName,
                    isFromCamera: imageSource == .camera,
                    onConfirm: { image in
                        Analytics.shared.trackTap(
                            elementId: imageSource == .camera ? "photo_preview_confirm_camera" : "photo_preview_confirm_library",
                            screenName: "round_camera"
                        )
                        showingPreview = false
                        cameraModel.stopSession()
                        onPhotoSelected(image, imageSource == .camera)
                    },
                    onRetake: {
                        Analytics.shared.trackTap(
                            elementId: "photo_preview_retake",
                            screenName: "round_camera"
                        )
                        showingPreview = false
                        capturedImage = nil
                        cameraModel.capturedImage = nil
                        selectedItem = nil
                        switch AVCaptureDevice.authorizationStatus(for: .video) {
                        case .authorized:
                            cameraModel.checkPermission()
                        default:
                            showingPermissionAlert = true
                        }
                    }
                )
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "round_camera")
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                DispatchQueue.main.async { isViewAppeared = true }
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        if granted {
                            isViewAppeared = true
                        } else {
                            Analytics.shared.trackError(
                                message: "Camera permission denied",
                                properties: [AnalyticsProperty.competitionId: competition.id]
                            )
                            showingPermissionAlert = true
                        }
                    }
                }
            default:
                Analytics.shared.trackError(
                    message: "Camera permission not available",
                    properties: [AnalyticsProperty.competitionId: competition.id]
                )
                showingPermissionAlert = true
            }
        }
        .onDisappear {
            cameraModel.stopSession()
        }
        .alert("Camera Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                onCancel()
            }
            Button("Cancel", role: .cancel) {
                Analytics.shared.trackTap(
                    elementId: "camera_permission_cancel",
                    screenName: "round_camera"
                )
                onCancel()
            }
        } message: {
            Text("Camera access is required to take photos. Please enable it in Settings.")
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Top Bar
    // ─────────────────────────────────────────────────────────────

    private var topBar: some View {
        HStack(alignment: .top) {
            Button(action: {
                Analytics.shared.trackTap(
                    elementId: "camera_dismiss",
                    screenName: "round_camera"
                )
                cameraModel.stopSession()
                onCancel()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .padding(5)
                    .shadow(radius: 10)
            }

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                Text(themeName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.accent)
            .cornerRadius(200)

            Spacer()

            // Flash + flip camera stacked on the right
            VStack(spacing: 4) {
                FlashButton(cameraModel: cameraModel)

                Button(action: {
                    Analytics.shared.trackTap(
                        elementId: "camera_flip",
                        screenName: "round_camera"
                    )
                    cameraModel.toggleCamera()
                }) {
                    Image(systemName: "arrow.2.circlepath")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .padding(5)
                        .shadow(radius: 10)
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 65)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Bottom Bar
    // ─────────────────────────────────────────────────────────────

    private var bottomBar: some View {
        HStack(spacing: 0) {
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ZStack {
                    RoundedRectangle(cornerRadius: 200)
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .simultaneousGesture(TapGesture().onEnded {
                Analytics.shared.trackTap(
                    elementId: "camera_open_library",
                    screenName: "round_camera"
                )
            })

            // Shutter — outer circle only, centred
            Button(action: {
                guard !cameraModel.isTakingPhoto else { return }
                Analytics.shared.trackTap(
                    elementId: "camera_shutter",
                    screenName: "round_camera"
                )
                cameraModel.capturePhotoWithFlash()
            }) {
                Circle()
                    .stroke(Color.white, lineWidth: 7)
                    .frame(width: 90, height: 90)
            }
            .frame(maxWidth: .infinity)
            .disabled(cameraModel.isTakingPhoto)

            // Balancing spacer so shutter stays centred
            Color.clear
                .frame(width: 52, height: 52)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 65)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - View+If
// ─────────────────────────────────────────────────────────────

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
//
// No longer uploads. Confirms the image looks good then passes
// the UIImage back up. Upload happens atomically with joinRound.
// ─────────────────────────────────────────────────────────────

struct RoundPhotoPreview: View {

    let image: UIImage
    let themeName: String
    let isFromCamera: Bool
    let onConfirm: (UIImage) -> Void
    let onRetake: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .if(isFromCamera) { $0.scaledToFill() }
                    .if(!isFromCamera) { $0.scaledToFit() }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                VStack {
                    HStack {
                        Button(action: onRetake) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .padding(5)
                                .shadow(radius: 10)
                        }

                        Spacer()

                        HStack(spacing: 5) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                            Text(themeName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppTheme.accent)
                        .cornerRadius(200)

                        Spacer()

                        Image(systemName: "arrow.left")
                            .font(.system(size: 30))
                            .foregroundColor(.clear)
                            .padding(5)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 65)

                    Spacer()

                    Button(action: { onConfirm(image) }) {
                        Text("Continue")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .background(AppTheme.accent)
                            .foregroundColor(.white)
                            .cornerRadius(200)
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 65)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
    }
}

struct FlashButton: View {
    @ObservedObject var cameraModel: CameraViewModel

    var body: some View {
        Button(action: {
            Analytics.shared.trackTap(
                elementId: "camera_toggle_flash",
                screenName: "round_camera"
            )
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
