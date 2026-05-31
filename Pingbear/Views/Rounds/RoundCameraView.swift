import SwiftUI
import AVFoundation
import PhotosUI

// ─────────────────────────────────────────────────────────────
// MARK: - RoundCameraView
// ─────────────────────────────────────────────────────────────

struct RoundCameraView: View {

    let onPhotoSelected: (UIImage, Bool) -> Void
    let onCancel: () -> Void

    @StateObject private var cameraModel         = CameraViewModel()
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isViewAppeared            = false
    @State private var isLoadingFromLibrary      = false
    @State private var showingPermissionAlert    = false

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
                    if let data  = try await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            isLoadingFromLibrary = false
                            cameraModel.stopSession()
                            Analytics.shared.track(event: "photo_picked_from_library")
                            onPhotoSelected(image, false)
                        }
                    } else {
                        await MainActor.run { isLoadingFromLibrary = false }
                    }
                } catch {
                    await MainActor.run {
                        isLoadingFromLibrary = false
                        Analytics.shared.track(event: "photo_library_load_failed", properties: [
                            "error": error.localizedDescription
                        ])
                    }
                }
            }
        }
        .onChange(of: cameraModel.showPreview) { isShowing in
            guard isShowing, let image = cameraModel.capturedImage else { return }
            cameraModel.showPreview = false
            cameraModel.stopSession()
            Analytics.shared.track(event: "photo_taken")
            onPhotoSelected(image, true)
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
                            Analytics.shared.track(event: "camera_permission_denied")
                            showingPermissionAlert = true
                        }
                    }
                }
            default:
                Analytics.shared.track(event: "camera_permission_denied")
                showingPermissionAlert = true
            }
        }
        .onDisappear { cameraModel.stopSession() }
        .alert("Camera Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                Analytics.shared.trackTap(elementId: "camera_permission_open_settings", screenName: "round_camera")
                onCancel()
            }
            Button("Cancel", role: .cancel) {
                Analytics.shared.trackTap(elementId: "camera_permission_cancel", screenName: "round_camera")
                onCancel()
            }
        } message: {
            Text("Camera access is required to take photos. Please enable it in Settings.")
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Top Bar
    // ─────────────────────────────────────────────────────────

    private var topBar: some View {
        HStack(alignment: .top) {
            Button {
                Analytics.shared.trackTap(elementId: "camera_close", screenName: "round_camera")
                cameraModel.stopSession()
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .padding(5)
                    .shadow(radius: 10)
            }

            Spacer()

            VStack(spacing: 4) {
                FlashButton(cameraModel: cameraModel)

                Button {
                    Analytics.shared.trackTap(elementId: "camera_flip", screenName: "round_camera")
                    cameraModel.toggleCamera()
                } label: {
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

    // ─────────────────────────────────────────────────────────
    // MARK: - Bottom Bar
    // ─────────────────────────────────────────────────────────

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
            .simultaneousGesture(TapGesture().onEnded {
                Analytics.shared.trackTap(elementId: "camera_open_library", screenName: "round_camera")
            })
            .frame(maxWidth: .infinity)

            Button {
                guard !cameraModel.isTakingPhoto else { return }
                Analytics.shared.trackTap(elementId: "camera_shutter", screenName: "round_camera")
                cameraModel.capturePhotoWithFlash()
            } label: {
                Circle()
                    .stroke(Color.white, lineWidth: 7)
                    .frame(width: 90, height: 90)
            }
            .frame(maxWidth: .infinity)
            .disabled(cameraModel.isTakingPhoto)

            Color.clear.frame(width: 60, height: 60).frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 65)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - RoundPhotoPreview
// ─────────────────────────────────────────────────────────────

struct RoundPhotoPreview: View {

    let image: UIImage
    let isFromCamera: Bool
    let onConfirm: (UIImage) -> Void
    let onRetake: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .if(isFromCamera)  { $0.scaledToFill() }
                    .if(!isFromCamera) { $0.scaledToFit() }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                VStack {
                    HStack {
                        Button {
                            Analytics.shared.trackTap(
                                elementId: "photo_preview_retake",
                                screenName: "photo_preview",
                                properties: ["is_from_camera": isFromCamera]
                            )
                            onRetake()
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .padding(5)
                                .shadow(radius: 10)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 65)

                    Spacer()

                    Button {
                        Analytics.shared.trackTap(
                            elementId: "photo_preview_confirm",
                            screenName: "photo_preview",
                            properties: ["is_from_camera": isFromCamera]
                        )
                        onConfirm(image)
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .font(.system(size: 18, weight: .bold))
                            .padding(.vertical, 8)
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
        .onAppear {
            Analytics.shared.trackScreen(name: "photo_preview", properties: [
                "is_from_camera": isFromCamera
            ])
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - View+If
// ─────────────────────────────────────────────────────────────

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - FlashButton
// ─────────────────────────────────────────────────────────────

struct FlashButton: View {
    @ObservedObject var cameraModel: CameraViewModel
    var body: some View {
        Button {
            cameraModel.toggleFlashMode()
            Analytics.shared.trackTap(
                elementId: "camera_flash_toggle",
                screenName: "round_camera",
                properties: ["flash_mode": cameraModel.flashMode.iconName]
            )
        } label: {
            Image(systemName: cameraModel.flashMode.iconName)
                .font(.system(size: 30))
                .foregroundColor(.white)
                .padding(5)
                .shadow(radius: 10)
        }
        .opacity(cameraModel.isFlashAvailable ? 1 : 0.5)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - SubmissionFullScreenView
// ─────────────────────────────────────────────────────────────

struct SubmissionFullScreenView: View {
    let submission: Submission
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                AsyncImage(url: URL(string: submission.photoUrl)) { image in
                    image.resizable()
                        .if(submission.isFromCamera)  { $0.scaledToFill() }
                        .if(!submission.isFromCamera) { $0.scaledToFit() }
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } placeholder: {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Analytics.shared.trackTap(elementId: "submission_fullscreen_dismiss", screenName: "submission_fullscreen")
                dismiss()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            Analytics.shared.trackScreen(name: "submission_fullscreen", properties: [
                "is_from_camera": submission.isFromCamera,
                "entry_fee": submission.entryFee
            ])
        }
    }
}
