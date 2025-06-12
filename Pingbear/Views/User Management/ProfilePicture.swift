import SwiftUI
import FirebaseStorage
import FirebaseFirestore
import PhotosUI
import FirebaseAuth
import Kingfisher

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
        
        // Process the image optimization on a background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Update progress to indicate processing started
            DispatchQueue.main.async {
                self.uploadProgress = 0.1
            }
            
            // Convert raw image data to UIImage for optimization
            guard let image = UIImage(data: imageData) else {
                DispatchQueue.main.async {
                    self.isUploading = false
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])))
                }
                return
            }
            
            // Get optimized image data
            guard let optimizedData = image.optimizedForUpload() else {
                DispatchQueue.main.async {
                    self.isUploading = false
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to optimize image"])))
                }
                return
            }
            
            print("Image optimized for upload. Size: \(Double(optimizedData.count) / 1024.0) KB")
            
            DispatchQueue.main.async {
                self.uploadProgress = 0.2
            }
            
            // Continue with the upload process on the main thread
            DispatchQueue.main.async {
                self.performUpload(optimizedData: optimizedData, userId: userId, completion: completion)
            }
        }
    }
    
    private func performUpload(optimizedData: Data, userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        let storageRef = storage.reference().child("profile_pictures/\(userId)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let uploadTask = storageRef.putData(optimizedData, metadata: metadata)
        
        uploadTask.observe(.progress) { [weak self] snapshot in
            guard let percentComplete = snapshot.progress?.fractionCompleted else { return }
            // Scale the progress from 20-90% range during upload
            let scaledProgress = 0.2 + (percentComplete * 0.7) // 20% to 90%
            
            DispatchQueue.main.async {
                self?.uploadProgress = scaledProgress
            }
        }
        
        uploadTask.observe(.success) { [weak self] _ in
            DispatchQueue.main.async {
                self?.uploadProgress = 0.9 // Almost done, waiting for URL
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.isUploading = false
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let downloadURL = url?.absoluteString else {
                    DispatchQueue.main.async {
                        self?.isUploading = false
                        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
                    }
                    return
                }
                
                // Update Firestore with the profile picture URL
                self?.db.collection("users").document(userId).updateData([
                    "profilePictureUrl": downloadURL
                ]) { error in
                    DispatchQueue.main.async {
                        self?.uploadProgress = 1.0 // Complete
                        self?.isUploading = false
                        
                        if let error = error {
                            completion(.failure(error))
                        } else {
                            self?.currentProfileUrl = downloadURL  // Update the published property
                            completion(.success(downloadURL))
                        }
                    }
                }
            }
        }
        
        uploadTask.observe(.failure) { [weak self] snapshot in
            DispatchQueue.main.async {
                self?.isUploading = false
                if let error = snapshot.error {
                    completion(.failure(error))
                }
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
                ProgressView(value: uploadManager.uploadProgress) {
                    Text("\(Int(uploadManager.uploadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#4169E1"))
                }
                .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "#4169E1")))
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
                        .background(Color(hex: "#4169E1"))
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

    var body: some View {
        if let urlString = url, let imageUrl = URL(string: urlString) {
            KFImage(imageUrl)
                .placeholder {
                    Circle()
                        .fill(Color(hex: "#10183C"))
                        .frame(width: size, height: size)
                }
                .onFailure { _ in }
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Image("user")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)  // Make image slightly smaller than circle
        }
    }
}
