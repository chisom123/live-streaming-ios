import SwiftUI
import AVFoundation
import PhotosUI

// ─────────────────────────────────────────────────────────────
// MARK: - CompetitionCameraView
// Simple camera — no theme pill, no reference photo PiP
// Timer (off / 3s / 10s) for hands-free shots
// ─────────────────────────────────────────────────────────────

struct CompetitionCameraView: View {

    let onPhotoTaken: (UIImage) -> Void
    let onCancel:     () -> Void

    var body: some View {
        #if targetEnvironment(simulator)
        CompetitionSimulatorPickerView(onPhotoTaken: onPhotoTaken, onCancel: onCancel)
        #else
        CompetitionRealCameraView(onPhotoTaken: onPhotoTaken, onCancel: onCancel)
        #endif
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - CompetitionSimulatorPickerView
// ─────────────────────────────────────────────────────────────

struct CompetitionSimulatorPickerView: View {

    let onPhotoTaken: (UIImage) -> Void
    let onCancel:     () -> Void

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .padding(5)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 65)

                Spacer()

                Image(systemName: "camera.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.4))

                Text("Simulator")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))

                Spacer()

                if isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Text("Choose Photo")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.accent)
                            .cornerRadius(200)
                            .padding(.horizontal, 32)
                    }
                }
            }
            .padding(.bottom, 60)
        }
        .ignoresSafeArea()
        .onChange(of: selectedItem) { newItem in
            guard let newItem else { return }
            isLoading = true
            Task {
                if let data  = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run { isLoading = false; onPhotoTaken(image) }
                } else {
                    await MainActor.run { isLoading = false }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - CompetitionRealCameraView
// ─────────────────────────────────────────────────────────────

struct CompetitionRealCameraView: View {

    let onPhotoTaken: (UIImage) -> Void
    let onCancel:     () -> Void

    @StateObject private var cameraModel      = CameraViewModel()
    @State private var isViewAppeared         = false
    @State private var showingPermissionAlert = false

    // Timer
    @State private var timerMode:   Int   = 0
    @State private var countdown:   Int   = 0
    @State private var timerFiring: Bool  = false
    @State private var countdownTimer: Timer? = nil

    private let timerModes = [0, 3, 10]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isViewAppeared {
                CameraInitView()
                    .environmentObject(cameraModel)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // Top bar
                HStack(alignment: .top) {
                    Button {
                        cancelTimer()
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                    }

                    Spacer()

                    VStack(spacing: 4) {
                        Button { cameraModel.toggleCamera() } label: {
                            Image(systemName: "arrow.2.circlepath")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                        }

                        if cameraModel.isFlashAvailable {
                            Button { cameraModel.toggleFlashMode() } label: {
                                Image(systemName: cameraModel.flashMode.iconName)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                            }
                        }

                        Button { cycleTimer() } label: {
                            ZStack {
                                Image(systemName: "timer")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(timerMode > 0 ? AppTheme.accent : .white)
                                    .frame(width: 60, height: 60)
                                if timerMode > 0 {
                                    Text("\(timerMode)")
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundColor(AppTheme.accent)
                                        .offset(x: 10, y: 10)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 60)

                Spacer()

                if timerFiring && countdown > 0 {
                    Text("\(countdown)")
                        .font(.system(size: 120, weight: .black))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: countdown)
                }

                Spacer()

                Button {
                    guard !cameraModel.isTakingPhoto && !timerFiring else { return }
                    if timerMode == 0 {
                        cameraModel.capturePhotoWithFlash()
                    } else {
                        startTimer()
                    }
                } label: {
                    ZStack {
                        Circle().stroke(Color.white, lineWidth: 7).frame(width: 90, height: 90)
                        Circle().fill(timerFiring ? Color.red : Color.white).frame(width: 72, height: 72)
                            .opacity(cameraModel.isTakingPhoto ? 0.5 : 1)
                    }
                }
                .disabled(cameraModel.isTakingPhoto)
                .padding(.bottom, 65)
            }
        }
        .ignoresSafeArea()
        .onChange(of: cameraModel.showPreview) { isShowing in
            guard isShowing, let image = cameraModel.capturedImage else { return }
            cameraModel.showPreview = false
            onPhotoTaken(image)
        }
        .onAppear {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                DispatchQueue.main.async { isViewAppeared = true }
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        if granted { isViewAppeared = true }
                        else       { showingPermissionAlert = true }
                    }
                }
            default:
                showingPermissionAlert = true
            }
        }
        .onDisappear { cancelTimer(); cameraModel.stopSession() }
        .alert("Camera Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                onCancel()
            }
            Button("Cancel", role: .cancel) { onCancel() }
        } message: {
            Text("Camera access is required to share photos.")
        }
    }

    private func cycleTimer() {
        let idx   = timerModes.firstIndex(of: timerMode) ?? 0
        timerMode = timerModes[(idx + 1) % timerModes.count]
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func startTimer() {
        countdown   = timerMode
        timerFiring = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            if countdown > 1 {
                countdown -= 1
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                t.invalidate()
                countdownTimer = nil
                timerFiring    = false
                countdown      = 0
                cameraModel.capturePhotoWithFlash()
            }
        }
    }

    private func cancelTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        timerFiring    = false
        countdown      = 0
    }
}
