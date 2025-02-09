import SwiftUI
import FirebaseStorage
import FirebaseFirestore
import PhotosUI
import FirebaseAuth

// Profile Image Model
struct ProfileImage: Identifiable {
    let id: String
    let url: String
}

// Profile Picture Upload Manager
class ProfilePictureManager: ObservableObject {
    static let shared = ProfilePictureManager()
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var currentProfileUrl: String?
    
    func uploadProfilePicture(imageData: Data, userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        isUploading = true
        uploadProgress = 0
        
        let storageRef = storage.reference().child("profile_pictures/\(userId)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let uploadTask = storageRef.putData(imageData, metadata: metadata)
        
        uploadTask.observe(.progress) { [weak self] snapshot in
            guard let percentComplete = snapshot.progress?.fractionCompleted else { return }
            DispatchQueue.main.async {
                self?.uploadProgress = percentComplete
            }
        }
        
        uploadTask.observe(.success) { [weak self] _ in
            storageRef.downloadURL { url, error in
                self?.isUploading = false
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let downloadURL = url?.absoluteString else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
                    return
                }
                
                // Update Firestore with the profile picture URL
                self?.db.collection("users").document(userId).updateData([
                    "profilePictureUrl": downloadURL
                ]) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        DispatchQueue.main.async {
                            self?.currentProfileUrl = downloadURL  // Update the published property
                        }
                        completion(.success(downloadURL))
                    }
                }
            }
        }
        
        uploadTask.observe(.failure) { [weak self] snapshot in
            self?.isUploading = false
            if let error = snapshot.error {
                completion(.failure(error))
            }
        }
    }
}

// Profile Picture Selection View
struct ProfilePictureSelector: View {
    var onUpdateSuccess: ((String) -> Void)? = nil
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @ObservedObject private var uploadManager = ProfilePictureManager.shared
    
    var body: some View {
        VStack {
            if uploadManager.isUploading {
                ProgressView(value: uploadManager.uploadProgress) {}
                .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "#FF4081")))
                .padding()
            } else {
                
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Text("Edit Picture")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 15, bottom: 8, trailing: 15))
                        .background(Color(hex: "#FF4081"))
                        .foregroundColor(Color(hex: "#fff"))
                        .cornerRadius(200)
                }
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            selectedImageData = data
                            uploadProfilePicture(imageData: data)
                        }
                    }
                }
                
            }
        }
    }
    
    private func uploadProfilePicture(imageData: Data) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        ProfilePictureManager.shared.uploadProfilePicture(imageData: imageData, userId: userId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):  // Extract the URL from the success case
                    onUpdateSuccess?(url)  // Pass the URL to the callback
                case .failure(let error):
                    print("Failed to update profile picture: \(error.localizedDescription)")
                }
            }
        }
    }
}

// Profile Picture View Component
struct ProfilePictureView: View {
    let url: String?
    let size: CGFloat
    @State private var imageLoadError = false
    
    var body: some View {
        if let urlString = url, let url = URL(string: urlString), !imageLoadError {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Circle()
                        .fill(Color(hex: "#10183C"))
                        .frame(width: size, height: size)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure(_):
                    whiteCircle
                @unknown default:
                    whiteCircle
                }
            }
        } else {
            whiteCircle
        }
    }
    
    private var whiteCircle: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#10183C"))
                .frame(width: size, height: size)
            
            Image("circle-user-round")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(.white)
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.6, height: size * 0.6)  // Make image slightly smaller than circle
        }
    }
}
