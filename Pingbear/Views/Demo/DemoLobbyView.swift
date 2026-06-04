import SwiftUI
import PhotosUI
import AVFoundation

struct DemoLobbyView: View {

    @ObservedObject var coordinator: DemoFlowCoordinator

    @State private var showingCamera          = false
    @State private var showingPermissionAlert = false

    private let botPhotoUrl  = "https://firebasestorage.googleapis.com/v0/b/pingbear-96b4c-us/o/static%2F205d3e3140b88c203608bbb641b19afd.jpg?alt=media&token=9e8f10a7-7b51-4eaa-8a56-a4974df4baac"

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("You vs Sarah")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
                    .padding(.bottom, 8)

                Text("Take or pick a photo to enter the round")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.secondaryText)
                    .padding(.bottom, 32)

                // ── Two panels ────────────────────────────────
                GeometryReader { geo in
                    let outerPad:   CGFloat = 40
                    let vsBadge:    CGFloat = 52
                    let panelWidth  = (geo.size.width - outerPad * 2 - vsBadge) / 2
                    let panelHeight = panelWidth * 1.45

                    HStack(spacing: 0) {
                        userPanel(width: panelWidth, height: panelHeight)

                        Text("vs")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(AppTheme.accent)
                            .frame(width: vsBadge)

                        botPanel(width: panelWidth, height: panelHeight)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, outerPad)
                }
                .frame(height: {
                    let outerPad: CGFloat = 40
                    let vsBadge:  CGFloat = 52
                    let w = UIScreen.main.bounds.width
                    let panelWidth = (w - outerPad * 2 - vsBadge) / 2
                    return panelWidth * 1.45
                }())

                Spacer()

                if coordinator.selectedImage != nil {
                    Button(action: {
                        Analytics.shared.trackTap(
                            elementId: "demo_lobby_continue",
                            screenName: "demo_lobby"
                        )
                        coordinator.proceedFromLobby()
                    }) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(AppTheme.accent)
                            .cornerRadius(200)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 48)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Color.clear.frame(height: 55 + 48)
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: coordinator.selectedImage != nil)
        .fullScreenCover(isPresented: $showingCamera) {
            RoundCameraView(
                onPhotoSelected: { image, _ in
                    showingCamera = false
                    coordinator.onPhotoSelected(image)
                    Analytics.shared.track(event: "demo_photo_selected")
                },
                onCancel: {
                    showingCamera = false
                    Analytics.shared.trackTap(
                        elementId: "demo_camera_cancelled",
                        screenName: "demo_lobby"
                    )
                }
            )
        }
        .alert("Camera Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Camera access is required. Please enable it in Settings.")
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "demo_lobby")
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - User Panel
    // ─────────────────────────────────────────────────────────

    @ViewBuilder
    private func userPanel(width: CGFloat, height: CGFloat) -> some View {
        if let image = coordinator.selectedImage {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                    .cornerRadius(16)

                Button(action: { openCamera() }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .padding(10)
            }
            .frame(width: width, height: height)
        } else {
            Button(action: { openCamera() }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.cardBackground)
                        .frame(width: width, height: height)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 1.5, dash: [6])
                                )
                                .foregroundColor(AppTheme.accent.opacity(0.5))
                        )

                    VStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(AppTheme.accent)
                        Text("Your photo")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.accent)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Bot Panel
    // ─────────────────────────────────────────────────────────

    private func botPanel(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            AsyncImage(url: URL(string: botPhotoUrl)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .clipped()
                case .empty, .failure:
                    Rectangle()
                        .fill(AppTheme.cardBackground)
                        .frame(width: width, height: height)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 32))
                                .foregroundColor(AppTheme.secondaryText)
                        )
                @unknown default:
                    Rectangle().fill(AppTheme.cardBackground)
                        .frame(width: width, height: height)
                }
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.4)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(width: width, height: height)

            HStack {
                Spacer()
                Text("$1.00")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppTheme.green)
                    .cornerRadius(200)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 9)
        }
        .frame(width: width, height: height)
        .cornerRadius(16)
        .clipped()
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Open Camera
    // ─────────────────────────────────────────────────────────

    private func openCamera() {
        Analytics.shared.trackTap(
            elementId: "demo_user_panel_tapped",
            screenName: "demo_lobby"
        )
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.showingCamera = true
                    } else {
                        self.showingPermissionAlert = true
                        Analytics.shared.track(event: "demo_camera_permission_denied")
                    }
                }
            }
        default:
            showingPermissionAlert = true
            Analytics.shared.track(event: "demo_camera_permission_denied")
        }
    }
}
