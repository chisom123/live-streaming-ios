import SwiftUI
import AVFoundation
import PhotosUI

// MARK: - RequestCameraView
/// Drop-in replacement for CompetitionCameraView.
/// Records a short video instead of a still photo.
/// Calls `onVideoTaken(URL)` instead of `onPhotoTaken(UIImage)`.

struct RequestCameraView: View {

    let onVideoTaken: (URL) -> Void
    let onCancel:     () -> Void

    var body: some View {
        #if targetEnvironment(simulator)
        RequestSimulatorPickerView(onVideoTaken: onVideoTaken, onCancel: onCancel)
        #else
        RequestRealCameraView(onVideoTaken: onVideoTaken, onCancel: onCancel)
        #endif
    }
}

// MARK: - Simulator fallback (pick from library)

struct RequestSimulatorPickerView: View {
    let onVideoTaken: (URL) -> Void
    let onCancel:     () -> Void

    @State private var selectedItem: PhotosPickerItem?
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
                .padding(.horizontal, 16).padding(.top, 65)
                Spacer()
                Image(systemName: "video.fill")
                    .font(.system(size: 48)).foregroundColor(.white.opacity(0.4))
                Text("Simulator — pick a video")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                if isLoading {
                    ProgressView().progressViewStyle(.circular).tint(.white)
                } else {
                    PhotosPicker(selection: $selectedItem, matching: .videos) {
                        Text("Choose Video")
                            .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(AppTheme.accent).cornerRadius(200)
                            .padding(.horizontal, 32)
                    }
                }
            }
            .padding(.bottom, 60)
        }
        .ignoresSafeArea()
        .onChange(of: selectedItem) { item in
            guard let item else { return }
            isLoading = true
            Task {
                // Copy to a temp file so we have a stable URL
                if let movie = try? await item.loadTransferable(type: Data.self) {
                    let url = VideoRecordingViewModel.newTempURL()
                    try? movie.write(to: url)
                    await MainActor.run { isLoading = false; onVideoTaken(url) }
                } else {
                    await MainActor.run { isLoading = false }
                }
            }
        }
    }
}

// MARK: - Real camera

struct RequestRealCameraView: View {

    let onVideoTaken: (URL) -> Void
    let onCancel:     () -> Void

    @StateObject private var vm = VideoRecordingViewModel()
    @State private var isViewAppeared         = false
    @State private var showingPermissionAlert = false

    // Timer mode
    @State private var timerMode:        Int   = 0
    @State private var countdown:        Int   = 0
    @State private var timerFiring:      Bool  = false
    @State private var countdownTimer:   Timer? = nil
    private let timerModes = [0, 3, 10]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isViewAppeared {
                // Reuse CameraInitView — it reads the session from the EnvironmentObject
                VideoInitView()
                    .environmentObject(vm)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                topBar
                Spacer()
                if timerFiring && countdown > 0 { countdownDisplay }
                Spacer()
                bottomBar
            }
        }
        .ignoresSafeArea()
        // When recording finishes, vm.showPreview flips → hand URL to caller
        .onChange(of: vm.showPreview) { showing in
            guard showing, let url = vm.recordedVideoURL else { return }
            vm.showPreview = false
            onVideoTaken(url)
        }
        .onAppear { checkPermissions() }
        .onDisappear { cancelTimer(); vm.stopSession() }
        .alert("Camera Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                onCancel()
            }
            Button("Cancel", role: .cancel) { onCancel() }
        } message: { Text("Camera and microphone access are required to record videos.") }
    }

    // ── Top bar ───────────────────────────────────────────────

    private var topBar: some View {
        HStack(alignment: .top) {
            Button {
                if vm.isRecording { vm.stopRecording() }
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
                // Flip camera (only when not recording)
                Button { if !vm.isRecording { vm.toggleCamera() } } label: {
                    Image(systemName: "arrow.2.circlepath")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(vm.isRecording ? .white.opacity(0.3) : .white)
                        .frame(width: 60, height: 60)
                }
                // Torch
                if vm.isFlashAvailable {
                    Button { vm.toggleFlashMode() } label: {
                        Image(systemName: vm.flashMode == .on ? "bolt.fill" : "bolt.slash")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(vm.flashMode == .on ? .yellow : .white)
                            .frame(width: 60, height: 60)
                    }
                }
                // Timer (only when not recording)
                if !vm.isRecording {
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
        }
        .padding(.horizontal, 12).padding(.top, 60)
    }

    // ── Countdown overlay ─────────────────────────────────────

    private var countdownDisplay: some View {
        Text("\(countdown)")
            .font(.system(size: 120, weight: .black))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.5), radius: 8)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: countdown)
    }

    // ── Bottom bar ────────────────────────────────────────────

    private var bottomBar: some View {
        VStack(spacing: 12) {
            // Duration label while recording
            if vm.isRecording {
                durationLabel
            }
            // Record button
            recordButton
        }
        .padding(.bottom, 65)
    }

    private var durationLabel: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.red).frame(width: 8, height: 8)
                .opacity(vm.isRecording ? 1 : 0)
            Text(formattedDuration)
                .font(.system(size: 16, weight: .semibold).monospacedDigit())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(Color.black.opacity(0.4)).cornerRadius(20)
    }

    private var formattedDuration: String {
        let t = Int(vm.recordingDuration)
        return String(format: "%02d:%02d", t / 60, t % 60)
    }

    private var recordButton: some View {
        Button {
            guard !timerFiring else { cancelTimer(); return }
            if vm.isRecording {
                vm.stopRecording()
            } else if timerMode == 0 {
                vm.startRecording()
            } else {
                startTimer()
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 7)
                    .frame(width: 90, height: 90)
                RoundedRectangle(cornerRadius: vm.isRecording ? 8 : 45)
                    .fill(Color.red)
                    .frame(
                        width:  vm.isRecording ? 36 : 72,
                        height: vm.isRecording ? 36 : 72
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.isRecording)
            }
        }
    }

    // ── Timer helpers ─────────────────────────────────────────

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
                vm.startRecording()
            }
        }
    }

    private func cancelTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        timerFiring    = false
        countdown      = 0
    }

    // ── Permissions ───────────────────────────────────────────

    private func checkPermissions() {
        let camStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch camStatus {
        case .authorized:
            isViewAppeared = true
            vm.checkPermission()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { isViewAppeared = true; vm.checkPermission() }
                    else       { showingPermissionAlert = true }
                }
            }
        default:
            showingPermissionAlert = true
        }
    }
}

// ① NOTE: CameraInitView uses `@EnvironmentObject var cameraModel: CameraViewModel`.
// VideoRecordingViewModel extends the same NSObject/ObservableObject base and
// publishes the same `session`, `alert`, `preview` properties.
// The cast works because CameraInitView only reads those three properties.
// If you'd rather not cast, copy CameraInitView and change the type annotation
// to `VideoRecordingViewModel` — that's the cleanest long-term approach.

struct VideoInitView: View {
    @EnvironmentObject var vm: VideoRecordingViewModel

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                VideoCameraPreview(size: proxy.size)
                    .environmentObject(vm)
            }
        }
        .onAppear { vm.checkPermission() }
        .onDisappear { vm.stopSession() }
        .alert(isPresented: $vm.alert) {
            Alert(title: Text("Please enable camera access"))
        }
    }
}

struct VideoCameraPreview: UIViewRepresentable {
    @EnvironmentObject var vm: VideoRecordingViewModel
    var size: CGSize

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        vm.preview = AVCaptureVideoPreviewLayer(session: vm.session)
        vm.preview.frame.size    = size
        vm.preview.videoGravity  = .resizeAspectFill
        view.layer.addSublayer(vm.preview)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        vm.preview.frame.size = size
    }
}
