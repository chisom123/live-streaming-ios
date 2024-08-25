import SwiftUI
import AVKit
import Combine
import Firebase
import FirebaseStorage
import FirebaseFirestore
import PostHog

struct CameraView: View {
    @StateObject var cameraModel = CameraViewModel()
    var competition: Competition
    @State private var navigateToCompDetails = false
    
    var body: some View {
        ZStack {
            // MARK: Camera View
            CameraInitView()
                .environmentObject(cameraModel)
                .ignoresSafeArea()
            
            // Other controls (Preview and Reset) remain the same
            VStack {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(.black.opacity(0.25))
                        
                        Rectangle()
                            .fill(Color(hex: "#FF4500"))
                            .frame(width: geometry.size.width * (cameraModel.recordedDuration / cameraModel.maxDuration))
                    }
                    .frame(height: 10)
                    .cornerRadius(200)
                }
                .frame(height: 10)
                .padding()
                
                HStack {
                    Button {
                        navigateToCompDetails = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 30)) // Increase the font size as needed
                            .foregroundColor(.white)
                            .padding(5) // Adjust the padding to balance the increased size
                            .shadow(radius: 10)
                            .opacity(cameraModel.isRecording ? 0 : 1)
                    }
                    Spacer()
                    Button(action: {
                        cameraModel.toggleCamera()
                    }) {
                        Image(systemName: "arrow.2.circlepath")
                            .font(.system(size: 30)) // Increase the font size as needed
                            .foregroundColor(.white)
                            .padding(5) // Adjust the padding to balance the increased size
                            .shadow(radius: 10)
                            .opacity(cameraModel.isRecording ? 0 : 1)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                Text("Hold to Record")
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .shadow(radius: 10)
                    .padding(.bottom, 25)
                    .opacity(cameraModel.isRecording || cameraModel.recordedDuration >= cameraModel.maxDuration ? 0 : 1)

                // Record Button with Press and Hold Gesture
                Circle()
                    .fill(cameraModel.isRecording ? Color(hex: "#FF4500") : Color.clear)
                    .frame(width: 100, height: 100)
                    .contentShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 8) // White stroke for both states
                    )
                    .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { isPressing in
                        cameraModel.handlePress(isPressing: isPressing)
                    }, perform: {})
                    .padding(.bottom, 50)
                
            }
        }
        .fullScreenCover(isPresented: $cameraModel.showPreview, content: {
            if let url = cameraModel.previewURL {
                FinalPreview(url: url, showPreview: $cameraModel.showPreview,  competition: competition, competitionId: competition.id, resetCameraAction: { self.resetCamera() })
            }
        })
        .fullScreenCover(isPresented: $navigateToCompDetails) {
            CompDetails(competition: competition) // Adjust according to your needs
        }
    }
    
    private func resetCamera() {
        cameraModel.recordedDuration = 0
        cameraModel.previewURL = nil
        cameraModel.recordedURLs.removeAll()
        cameraModel.session.startRunning()
    }
}
