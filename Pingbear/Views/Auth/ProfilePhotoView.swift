import SwiftUI
import PhotosUI
import FirebaseAuth

struct ProfilePhotoView: View {
    var competition: Competition
    var onComplete: () -> Void
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var profileImageUrl: String?
    @ObservedObject private var uploadManager = ProfilePictureManager.shared
    
    var body: some View {
        ZStack {
            Color(hex: "#10183C")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 24) {
                    Text("Add a profile photo")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
                    Text("So your friends know who they're playing with")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 10)
                    
                    if profileImageUrl != nil && !uploadManager.isUploading {
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            ProfilePictureView(url: profileImageUrl, size: 100)
                        }
                        .onChange(of: selectedItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    uploadProfilePicture(imageData: data)
                                }
                            }
                        }
                        .padding(.vertical, 10)
                    } else {
                        ProfilePictureView(url: profileImageUrl, size: 100)
                            .padding(.vertical, 10)
                    }
                    
                    if uploadManager.isUploading {
                        ProgressView(value: uploadManager.uploadProgress) {
                            Text("\(Int(uploadManager.uploadProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "#4169E1")))
                        .padding()
                    } else if profileImageUrl == nil {
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Text("Choose Photo")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                                .background(Color(hex: "#4169E1"))
                                .cornerRadius(200)
                        }
                        .onChange(of: selectedItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    uploadProfilePicture(imageData: data)
                                }
                            }
                        }
                    } else {
                        Button(action: {
                            Analytics.shared.trackTap(
                                elementId: "profile_photo_continue",
                                screenName: "profile_photo"
                            )
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("OpenCompetition"),
                                    object: competition
                                )
                            }
                            onComplete()
                        }) {
                            Text("Continue")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                                .background(Color(hex: "#4169E1"))
                                .cornerRadius(200)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color(hex: "#1A2245"))
                .cornerRadius(10)
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Analytics.shared.trackScreen(name: "profile_photo")
        }
    }
    
    private func uploadProfilePicture(imageData: Data) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        ProfilePictureManager.shared.uploadProfilePicture(imageData: imageData, userId: userId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    profileImageUrl = url
                    Analytics.shared.track(
                        event: "onboarding_profile_photo_uploaded",
                        properties: ["user_id": userId]
                    )
                case .failure(let error):
                    print("Failed to upload profile picture: \(error.localizedDescription)")
                }
            }
        }
    }
}
