import AVFoundation
import UIKit
import Combine

// MARK: - VideoRecordingViewModel
/// Drop-in replacement for CameraViewModel.
/// Records video (not stills). Mirrors the same @Published surface
/// so VideoInitView keeps working.
final class VideoRecordingViewModel: NSObject, ObservableObject {

    // ── Published state (mirrors CameraViewModel surface) ─────
    @Published var session              = AVCaptureSession()
    @Published var currentCameraPosition: AVCaptureDevice.Position = .front
    @Published var alert                = false
    @Published var preview:             AVCaptureVideoPreviewLayer!
    @Published var isTakingPhoto        = false   // repurposed: "is recording"
    @Published var showPreview          = false
    @Published var isFlashAvailable     = false
    @Published var flashMode:           FlashMode = .off  // torch for video

    // ── Video-specific ─────────────────────────────────────────
    @Published var isRecording          = false
    @Published var recordingDuration:   TimeInterval = 0
    @Published var recordedVideoURL:    URL?

    // ── Private ────────────────────────────────────────────────
    private let sessionQueue      = DispatchQueue(label: "video.session.queue", qos: .userInitiated)
    private let videoOutputQueue  = DispatchQueue(label: "video.output.queue",  qos: .userInitiated)
    private let audioOutputQueue  = DispatchQueue(label: "audio.output.queue",  qos: .userInitiated)

    private let videoDataOutput   = AVCaptureVideoDataOutput()
    private let audioDataOutput   = AVCaptureAudioDataOutput()

    private var assetWriter:       AVAssetWriter?
    private var videoWriterInput:  AVAssetWriterInput?
    private var audioWriterInput:  AVAssetWriterInput?
    private var sessionSourceTime: CMTime?
    private var outputURL:         URL?

    private var durationTimer:     Timer?
    private var isConfigured       = false

    let maxDuration: TimeInterval = 60

    // MARK: - Permission / Setup

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            requestAudioAndConfigure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else { DispatchQueue.main.async { self?.alert = true }; return }
                self?.requestAudioAndConfigure()
            }
        default:
            DispatchQueue.main.async { self.alert = true }
        }
    }

    private func requestAudioAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            configureIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                self?.configureIfNeeded()
            }
        default:
            configureIfNeeded()
        }
    }

    private func configureIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self, !self.isConfigured else { return }
            self.configureSession()
            DispatchQueue.main.async {
                self.isConfigured = true
                self.updateFlashAvailability()
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()

        if session.canSetSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
        }

        addVideoInput(position: currentCameraPosition)
        addAudioInput()
        addVideoOutput()
        addAudioOutput()

        session.commitConfiguration()

        // Must be after commitConfiguration — connections don't exist until then
        applyVideoOrientation(for: currentCameraPosition)

        if !session.isRunning { session.startRunning() }
    }

    // MARK: - Inputs

    private func addVideoInput(position: AVCaptureDevice.Position) {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera
        ]
        guard let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: types, mediaType: .video, position: position).devices.first,
              let input  = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }

        session.addInput(input)

        try? device.lockForConfiguration()
        if device.activeFormat.videoSupportedFrameRateRanges
            .first(where: { $0.maxFrameRate >= 60 }) != nil {
            device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 60)
            device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 60)
        }
        if device.isSmoothAutoFocusSupported { device.isSmoothAutoFocusEnabled = true }
        device.unlockForConfiguration()
    }

    private func addAudioInput() {
        guard let device = AVCaptureDevice.default(for: .audio),
              let input  = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }
        session.addInput(input)
    }

    private func addVideoOutput() {
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        guard session.canAddOutput(videoDataOutput) else { return }
        session.addOutput(videoDataOutput)
    }

    private func addAudioOutput() {
        audioDataOutput.setSampleBufferDelegate(self, queue: audioOutputQueue)
        guard session.canAddOutput(audioDataOutput) else { return }
        session.addOutput(audioDataOutput)
    }

    /// Must be called AFTER session.commitConfiguration() — connections don't exist until then.
    /// Sets portrait orientation only. No mirroring — the writer transform handles the
    /// front camera horizontal flip independently.
    private func applyVideoOrientation(for position: AVCaptureDevice.Position) {
        guard let conn = videoDataOutput.connection(with: .video) else { return }
        if conn.isVideoOrientationSupported {
            conn.videoOrientation = .portrait
        }
        // No mirroring on the connection — rotation is already correct from .portrait,
        // and the front camera flip is handled by the writer transform below.
        if conn.isVideoMirroringSupported {
            conn.isVideoMirrored = false
        }
    }

    // MARK: - Camera Switch

    func toggleCamera() {
        let next: AVCaptureDevice.Position = currentCameraPosition == .front ? .back : .front
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.addVideoInput(position: next)
            self.addAudioInput()
            self.session.commitConfiguration()

            // Apply after commit
            self.applyVideoOrientation(for: next)

            DispatchQueue.main.async {
                self.currentCameraPosition = next
                self.updateFlashAvailability()
                UserDefaults.standard.set(next.rawValue, forKey: "CameraPosition")
            }
        }
    }

    // MARK: - Flash / Torch

    func updateFlashAvailability() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition)
        else { isFlashAvailable = false; return }
        isFlashAvailable = device.hasTorch
    }

    func toggleFlashMode() {
        flashMode = flashMode == .off ? .on : .off
        setTorch(mode: flashMode == .on ? .on : .off)
    }

    private func setTorch(mode: AVCaptureDevice.TorchMode) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
              device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = mode
        device.unlockForConfiguration()
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }
        let url = Self.newTempURL()
        outputURL         = url
        sessionSourceTime = nil
        isRecording       = true
        isTakingPhoto     = true
        recordingDuration = 0

        setupAssetWriter(url: url, position: currentCameraPosition)

        DispatchQueue.main.async {
            self.durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.recordingDuration += 0.1
                if self.recordingDuration >= self.maxDuration { self.stopRecording() }
            }
            RunLoop.main.add(self.durationTimer!, forMode: .common)
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording   = false
        isTakingPhoto = false

        durationTimer?.invalidate()
        durationTimer = nil

        videoWriterInput?.markAsFinished()
        audioWriterInput?.markAsFinished()

        let url = outputURL
        assetWriter?.finishWriting { [weak self] in
            DispatchQueue.main.async {
                self?.assetWriter      = nil
                self?.videoWriterInput = nil
                self?.audioWriterInput = nil
                self?.recordedVideoURL = url
                self?.showPreview      = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    private func setupAssetWriter(url: URL, position: AVCaptureDevice.Position) {
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return }
        assetWriter = writer

        // The connection orientation (.portrait, no mirror) already corrects rotation.
        // Front camera only needs a horizontal flip to match the mirrored preview.
        // Back camera needs no transform at all.
        let transform: CGAffineTransform = position == .front
            ? CGAffineTransform(scaleX: -1, y: 1)
            : .identity

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey:  1080,
            AVVideoHeightKey: 1920,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey:      6_000_000,
                AVVideoProfileLevelKey:        AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: 30
            ]
        ]
        let vi = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vi.expectsMediaDataInRealTime = true
        vi.transform = transform
        videoWriterInput = vi
        if writer.canAdd(vi) { writer.add(vi) }

        let audioSettings: [String: Any] = [
            AVFormatIDKey:         kAudioFormatMPEG4AAC,
            AVSampleRateKey:       44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey:   128_000
        ]
        let ai = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        ai.expectsMediaDataInRealTime = true
        audioWriterInput = ai
        if writer.canAdd(ai) { writer.add(ai) }

        writer.startWriting()
    }

    // MARK: - Session Control

    private var hasStoppedSession = false

    func stopSession(completion: (() -> Void)? = nil) {
        sessionQueue.async { [weak self] in
            guard let self, !self.hasStoppedSession else {
                DispatchQueue.main.async { completion?() }
                return
            }
            self.hasStoppedSession = true

            if self.session.isRunning {
                self.session.stopRunning()
            }
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("🟡 stopSession: deactivate FAILED: \(error)")
            }

            DispatchQueue.main.async {
                self.isConfigured = false
                completion?()
            }
        }
        setTorch(mode: .off)
    }

    // MARK: - Helpers

    static func newTempURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("VideoCapture", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(UUID().uuidString).mp4")
    }

    func capturePhotoWithFlash() { startRecording() }
}

// MARK: - Sample Buffer Delegate

extension VideoRecordingViewModel: AVCaptureVideoDataOutputSampleBufferDelegate,
                                    AVCaptureAudioDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput buffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        guard isRecording, let writer = assetWriter, writer.status == .writing else { return }

        let ts = CMSampleBufferGetPresentationTimeStamp(buffer)

        if sessionSourceTime == nil, output is AVCaptureVideoDataOutput {
            sessionSourceTime = ts
            writer.startSession(atSourceTime: ts)
        }
        guard sessionSourceTime != nil else { return }

        if output is AVCaptureVideoDataOutput,
           let vi = videoWriterInput, vi.isReadyForMoreMediaData {
            vi.append(buffer)
        } else if output is AVCaptureAudioDataOutput,
                  let ai = audioWriterInput, ai.isReadyForMoreMediaData {
            ai.append(buffer)
        }
    }
}
