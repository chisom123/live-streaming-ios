import SwiftUI
import SwiftttCamera
import Firebase
import FirebaseStorage
import FirebaseFirestore
import NotificationBannerSwift
import Flurry_iOS_SDK

struct CameraViewControllerRepresentable: UIViewControllerRepresentable {
    @Binding var shouldToggleCamera: Bool
    @Binding var shouldTakePicture: Bool
    @Binding var capturedImage: UIImage?
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let cameraViewController = CameraViewController()
        cameraViewController.onImageCaptured = { image in
            DispatchQueue.main.async {
                self.capturedImage = image
            }
        }
        return cameraViewController
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        if shouldToggleCamera {
            uiViewController.toggleCamera()
            DispatchQueue.main.async {
                self.shouldToggleCamera = false
            }
        }
        
        if shouldTakePicture {
            uiViewController.takePicture()
            DispatchQueue.main.async {
                self.shouldTakePicture = false
            }
        }
    }

    typealias UIViewControllerType = CameraViewController
}

class CameraViewController: UIViewController, CameraDelegate {
    var onImageCaptured: ((UIImage) -> Void)?
    
    private lazy var camera: SwiftttCamera = {
        let result = SwiftttCamera()
        result.delegate = self
        result.view.translatesAutoresizingMaskIntoConstraints = false
        return result
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        swiftttAddChild(camera)
        camera.view.frame = view.frame
    }

    func takePicture() {
        camera.takePicture()
    }

    func cameraController(_ cameraController: CameraProtocol, didFinishCapturingImage capturedImage: CapturedImage) {
        let image = capturedImage.fullImage
        onImageCaptured?(image)
    }

    func toggleCamera() {
        let newCameraDevice: CameraDevice = camera.cameraDevice.toggling()
        guard SwiftttCamera.isCameraDeviceAvailable(newCameraDevice) else { return }
        camera.cameraDevice = newCameraDevice
    }
}

struct CameraView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var shouldToggleCamera = false
    @State private var shouldTakePicture = false
    @State private var capturedImage: UIImage?
    @State private var isPresentingInfo = false // State to control the presentation of the New Competition View
    var competitionId: String
    @ObservedObject var viewModel: EntryViewModel // Assuming this is your view model
    var competition: Competition // Change from competitionId to competition
    @State private var shouldNavigateToLocationCheck = false // Added for navigation to LocationCheckView
    @State private var newentryDocId: String? // Add this line to hold the entries document ID
    @State private var isUploading = false

    
    var body: some View {
        if isUploading {
            ProgressView()
                .padding()
        } else {
            ZStack {
                CameraViewControllerRepresentable(shouldToggleCamera: $shouldToggleCamera, shouldTakePicture: $shouldTakePicture, capturedImage: $capturedImage)
                    .edgesIgnoringSafeArea(.all)
                
                if let image = capturedImage {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack {
                            HStack {
                                Button(action: {
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    Image(systemName: "arrow.left")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                        .padding(5)
                                        .shadow(radius: 10)
                                }
                                
                                Spacer()
                                
                            }
                            .padding(.top, (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0) + 20) // Added 20 points more padding to the top
                            .padding(.horizontal)
                            
                            Spacer()
                            
                            // "Continue" Button at the bottom
                            Button(action: {
                                submitEntry()
                            }) {
                                Text("Continue")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .font(.system(size: 18, weight: .bold, design: .default))
                                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                    .background(Color(hex: "#1199FF")) // Assuming Color(hex: "#1199FF") is equivalent to blue
                                    .foregroundColor(.white)
                                    .cornerRadius(200)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, (UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0) + 20) // Added 20 points more padding to the top
                        }
                        .edgesIgnoringSafeArea(.all)
                    }
                } else {
                    VStack {
                        HStack {
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 30)) // Increase the font size as needed
                                    .foregroundColor(.white)
                                    .padding(5) // Adjust the padding to balance the increased size
                                    .shadow(radius: 10)
                            }
                            Spacer()
                            Button(action: {
                                self.shouldToggleCamera.toggle()
                            }) {
                                Image(systemName: "arrow.2.circlepath")
                                    .font(.system(size: 30)) // Increase the font size as needed
                                    .foregroundColor(.white)
                                    .padding(5) // Adjust the padding to balance the increased size
                                    .shadow(radius: 10)
                            }
                        }
                        .padding([.top, .leading, .trailing])
                        
                        Spacer() // This will create space between the top HStack and the bottom button
                        
                        Button(action: {
                            self.shouldTakePicture = true
                        }) {
                            Circle()
                                .stroke(Color.white, lineWidth: 8) // White outline
                                .frame(width: 100, height: 100)
                        }
                        .padding(.bottom)
                    }
                }
            }
            .fullScreenCover(isPresented: $shouldNavigateToLocationCheck) {
                if let entryDocId = newentryDocId {
                    LocationCheckView(competition: competition, competitionId: competitionId, entryDocId: entryDocId)
                } else {
                    
                }
            }
        }
    }
    
    func submitEntry() {
        isUploading = true

        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            return
        }

        guard let capturedImage = self.capturedImage, let imageData = capturedImage.jpegData(compressionQuality: 0.8) else {
            print("No image captured")
            return
        }

        let db = Firestore.firestore()
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let imageRef = storageRef.child("images/\(UUID().uuidString).jpg")

        imageRef.putData(imageData, metadata: nil) { metadata, error in
            guard metadata != nil else {
                print("Error uploading image: \(String(describing: error))")
                return
            }

            imageRef.downloadURL { url, error in
                guard let downloadURL = url else {
                    print("Error getting download URL: \(String(describing: error))")
                    return
                }

                // Now that you have the image URL, include it in the entryData
                let entryData = ["userId": userId, "imageUrl": downloadURL.absoluteString]

                // Save to Firestore and retrieve the document reference
                var newEntryRef: DocumentReference? = nil
                newEntryRef = db.collection("competitions").document(self.competitionId).collection("entries").addDocument(data: entryData) { error in
                    if let error = error {
                        print("Error saving entry: \(error)")
                    } else {
                        print("Entry saved successfully")
            
                        // Add the user to the participants collection
                        let participantRef = db.collection("competitions").document(self.competitionId).collection("participants").document(userId)
                        participantRef.setData(["userId": userId]) { error in
                            if let error = error {
                                print("Error adding participant: \(error)")
                            } else {
                                print("Participant added successfully.")
                            }
                        }
                        
                        self.newentryDocId = newEntryRef?.documentID
                        
                        // Proceed to navigate to LocationCheckView with the competitionId and newEntryDocId
                        DispatchQueue.main.async {
                            self.shouldNavigateToLocationCheck = true
                        }
                        
                        isUploading = false

                    }
                }
            }
        }
    }

}
