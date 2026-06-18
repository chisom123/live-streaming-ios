import SwiftUI
import AVFoundation
import AVKit
import PhotosUI

// MARK: - RequestCameraView

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

// MARK: - Simulator fallback

struct RequestSimulatorPickerView: View {
    let onVideoTaken: (URL) -> Void
    let onCancel:     () -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var previewURL: URL?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let url = previewURL {
                VideoPreviewConfirmView(
                    url: url,
                    onConfirm: { onVideoTaken(url) },
                    onRetake:  { previewURL = nil }
                )
            } else {
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
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.4))

                    Text("Simulator — pick a video")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))

                    Spacer()

                    if isLoading {
                        ProgressView().progressViewStyle(.circular).tint(.white)
                    } else {
                        PhotosPicker(selection: $selectedItem, matching: .videos) {
                            Text("Choose Video")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(AppTheme.accent).cornerRadius(200)
                                .padding(.horizontal, 32)
                        }
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            Analytics.shared.trackScreen(name: "camera")
        }
        .onChange(of: selectedItem) { item in
            guard let item else { return }
            isLoading = true
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let url = VideoRecordingViewModel.newTempURL()
                    try? data.write(to: url)
                    await MainActor.run { isLoading = false; previewURL = url }
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

    @StateObject private var vm               = VideoRecordingViewModel()
    @State private var isViewAppeared         = false
    @State private var showingPermissionAlert = false
    @State private var previewURL:            URL? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Camera stays alive in background so retake is instant
            if isViewAppeared {
                VideoInitView()
                    .environmentObject(vm)
                    .ignoresSafeArea()
            }

            if let url = previewURL {
                // Preview / confirm step overlaid on top of live camera
                VideoPreviewConfirmView(
                    url: url,
                    onConfirm: {
                        onVideoTaken(url)
                    },
                    onRetake: {
                        try? FileManager.default.removeItem(at: url)
                        previewURL = nil
                    }
                )
            } else {
                // Camera UI
                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    bottomBar
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            Analytics.shared.trackScreen(name: "camera")
            checkPermissions()
        }
        .onDisappear { vm.stopSession() }
        .onChange(of: vm.showPreview) { showing in
            guard showing, let url = vm.recordedVideoURL else { return }
            vm.showPreview = false
            previewURL = url
        }
        .alert("Camera Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                onCancel()
            }
            Button("Cancel", role: .cancel) { onCancel() }
        } message: {
            Text("Camera and microphone access are required to record videos.")
        }
    }

    // ── Top bar ───────────────────────────────────────────────

    private var topBar: some View {
        HStack(alignment: .top) {
            Button {
                if vm.isRecording { vm.stopRecording() }
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
            }

            Spacer()

            VStack(spacing: 4) {
                // Flip camera (disabled while recording)
                Button { if !vm.isRecording { vm.toggleCamera() } } label: {
                    Image(systemName: "arrow.2.circlepath")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(vm.isRecording ? .white.opacity(0.3) : .white)
                        .frame(width: 60, height: 60)
                }

                // Torch (back camera only)
                if vm.isFlashAvailable {
                    Button { vm.toggleFlashMode() } label: {
                        Image(systemName: vm.flashMode == .on ? "bolt.fill" : "bolt.slash")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(vm.flashMode == .on ? .yellow : .white)
                            .frame(width: 60, height: 60)
                    }
                }
            }
        }
        .padding(.horizontal, 12).padding(.top, 60)
    }

    // ── Bottom bar ────────────────────────────────────────────

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if vm.isRecording { durationLabel }
            recordButton
        }
        .padding(.bottom, 65)
    }

    private var durationLabel: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.red).frame(width: 8, height: 8)
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
            if vm.isRecording {
                vm.stopRecording()
            } else {
                vm.startRecording()
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

    // ── Permissions ───────────────────────────────────────────

    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
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

// MARK: - VideoPreviewConfirmView

struct VideoPreviewConfirmView: View {

    let url:       URL
    let onConfirm: () -> Void
    let onRetake:  () -> Void

    @State private var player:       AVPlayer?
    @State private var loopObserver: NSObjectProtocol?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayerFillView(player: player)
                    .ignoresSafeArea()
            }

            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint:   .bottom
                )
                .frame(height: 200)
            }
            .ignoresSafeArea()

            VStack {
                Spacer()
                HStack(spacing: 20) {
                    Button(action: onRetake) {
                        Text("Retake")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(200)
                    }

                    Button(action: onConfirm) {
                        Text("Use Video")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.accent)
                            .cornerRadius(200)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
            }
        }
        .onAppear { setupPlayer() }
        .onDisappear { teardown() }
    }

    private func setupPlayer() {
        let p = AVPlayer(url: url)
        p.isMuted = false
        player = p
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object:  p.currentItem,
            queue:   .main
        ) { _ in
            p.seek(to: .zero)
            p.play()
        }
        p.play()
    }

    private func teardown() {
        player?.pause()
        player = nil
        if let obs = loopObserver {
            NotificationCenter.default.removeObserver(obs)
            loopObserver = nil
        }
    }
}

// MARK: - VideoPlayerFillView

struct VideoPlayerFillView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player                = player
        vc.showsPlaybackControls = false
        vc.videoGravity          = .resizeAspectFill
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}
}

// MARK: - VideoInitView

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

// MARK: - VideoCameraPreview

struct VideoCameraPreview: UIViewRepresentable {
    @EnvironmentObject var vm: VideoRecordingViewModel
    var size: CGSize

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        vm.preview = AVCaptureVideoPreviewLayer(session: vm.session)
        vm.preview.frame.size   = size
        vm.preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(vm.preview)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        vm.preview.frame.size = size
    }
}
