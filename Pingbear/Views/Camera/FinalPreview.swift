import SwiftUI
import AVKit
import Combine
import Firebase
import FirebaseStorage
import FirebaseFirestore
import PostHog

struct FinalPreview: View {
    var url: URL
    @Binding var showPreview: Bool
    var competition: Competition
    var competitionId: String
    var resetCameraAction: () -> Void
    @State private var entrySaved = false
    @State private var navigateToCompDetails = false // State to control navigation
    @State private var isUploading = false
    @State private var newentryDocId: String? // Add this line to hold the entries document ID
    @State private var isPlaying = true

    var body: some View {
        if isUploading {
            ProgressView()
                .padding()
        } else {
            GeometryReader { proxy in
                let size = proxy.size
                
                ZStack(alignment: .leading) {
                    CustomVideoPlayer(url: url, isPlaying: $isPlaying)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .ignoresSafeArea()
                        .onAppear {
                            PostHogSDK.shared.capture("Camera Video Preview Opened")
                        }
                    
                    // Back Button
                    VStack {
                        HStack {
                            Button(action: {
                                self.showPreview = false
                                self.resetCameraAction()
                                isPlaying = false
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 30)) // Increase the font size as needed
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .shadow(radius: 10)
                            }
                            .padding(.top, 50)  // Adds padding from the top of the screen
                            .padding(20)
                        }
                        Spacer()
                    }
                    
                    // Send Button at the bottom
                    VStack {
                        Spacer()
                        Button(action: {
                            submitEntry()
                        }) {
                            Text("Share")
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
                }
            }
            .ignoresSafeArea(edges: .all) // Now applying ignore to only video player
            .fullScreenCover(isPresented: $entrySaved) {
                if let entryDocId = newentryDocId {
                    PayView(viewModel: PayViewModel(), competition: competition, competitionId: competitionId, entryDocId: entryDocId) // Replace this with the actual view you want to present
                }
            }
            .fullScreenCover(isPresented: $navigateToCompDetails) {
                if let entryDocId = newentryDocId {
                    CompDetails(competition: competition) // Adjust according to your needs
                }
            }
        }
    }
    
    func submitEntry() {
        isPlaying = false
        isUploading = true
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            return
        }

        let videoURL = self.url
        
        // 1. Compress video before uploading
        compressVideo(inputURL: videoURL) { compressedURL in
            guard let compressedURL = compressedURL else {
                print("Failed to compress video")
                DispatchQueue.main.async {
                    self.isUploading = false
                }
                return
            }
            
            // 2. Upload the compressed video
            let storageRef = Storage.storage().reference().child("videos/\(UUID().uuidString).mov")
            let metadata = StorageMetadata()
            metadata.contentType = "video/quicktime"
            metadata.customMetadata = [
                "competitionId": self.competitionId,
                "userId": userId
            ]
            
            let uploadTask = storageRef.putFile(from: compressedURL, metadata: metadata)
            
            uploadTask.observe(.success) { _ in
                storageRef.downloadURL { result in
                    switch result {
                    case .success(let downloadURL):
                        self.saveEntryToFirestore(userId: userId, videoURL: downloadURL.absoluteString)
                    case .failure(let error):
                        print("Error getting download URL: \(error)")
                        DispatchQueue.main.async {
                            self.isUploading = false
                        }
                    }
                }
            }
            
            uploadTask.observe(.failure) { snapshot in
                if let error = snapshot.error {
                    print("Upload failed: \(error.localizedDescription)")
                }
                DispatchQueue.main.async {
                    self.isUploading = false
                }
            }
        }
    }
    
    func compressVideo(inputURL: URL, completion: @escaping (URL?) -> Void) {
        let uniqueFilename = "compressed_\(UUID().uuidString).mov"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueFilename)
        
        guard let exportSession = AVAssetExportSession(asset: AVAsset(url: inputURL), presetName: AVAssetExportPresetMediumQuality) else {
            completion(nil)
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = true
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(outputURL)
            default:
                print("Failed to compress video: \(exportSession.error?.localizedDescription ?? "Unknown error")")
                completion(nil)
            }
        }
    }
    
    func saveEntryToFirestore(userId: String, videoURL: String) {
        let db = Firestore.firestore()
        
        let userDocRef = Firestore.firestore().collection("users").document(userId)
        userDocRef.getDocument { (document, error) in
            var superstar = false // Default value if boost doesn't exist
            
            if let document = document, document.exists {
                if let boostDate = document.data()?["boost"] as? Timestamp {
                    let now = Timestamp(date: Date())
                    superstar = boostDate.compare(now) == .orderedDescending // Check if boost is in the future
                }
            } else {
                print("User document not found or boost data unavailable, setting superstar to false")
            }

            let entryData = [
                "userId": userId,
                "videoUrl": videoURL,
                "timestamp": FieldValue.serverTimestamp(),
                "superstar": superstar // Add superstar status based on boost check
            ]
            
            var newEntryRef: DocumentReference? = nil
            newEntryRef = db.collection("competitions").document(self.competitionId).collection("entries").addDocument(data: entryData) { error in
                if let error = error {
                    print("Error saving entry: \(error)")
                } else {
                    self.newentryDocId = newEntryRef?.documentID
                    print("Entry saved successfully")
                    
                    DispatchQueue.main.async {
                        if superstar {
                            self.navigateToCompDetails = true // Navigate to competition details if superstar
                        } else {
                            self.entrySaved = true // Trigger entry saved flow if not superstar
                        }
                    }
                }
                self.isUploading = false
                PostHogSDK.shared.capture("New Video Shared")
                self.fetchMembersAndNotify(userId: userId, competitionId: self.competitionId)
            }
        }
    }
    
    func fetchMembersAndNotify(userId: String, competitionId: String) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        // First fetch the username of the user sharing the video
        userRef.getDocument { (document, error) in
            if let error = error {
                print("Error fetching user document: \(error)")
                return
            }
            
            if let document = document, let username = document.data()?["username"] as? String {
                // Then fetch members and send notifications
                db.collection("competitions").document(competitionId).collection("members")
                    .getDocuments { snapshot, error in
                        if let error = error {
                            print("Error fetching member details: \(error)")
                            return
                        }
                        let memberIds = snapshot?.documents.map { $0.documentID } ?? []
                        self.sendNotificationToMembers(memberIds: memberIds, username: username)
                    }
            } else {
                print("Username not found for user \(userId)")
            }
        }
    }

    func sendNotificationToMembers(memberIds: [String], username: String) {
        let db = Firestore.firestore()
        let usersRef = db.collection("users")
        
        memberIds.forEach { memberId in
            usersRef.document(memberId).getDocument { (document, error) in
                if let error = error {
                    print("Error fetching user document: \(error)")
                    return
                }
                if let document = document, let fcmToken = document.data()?["fcmToken"] as? String {
                    let message = "\(username) shared a video"
                    self.sendPushNotification(to: fcmToken, message: message)
                }
            }
        }
    }

    func sendPushNotification(to token: String, message: String) {
        // Use Firebase Messaging SDK to send a push notification
        let sender = PushNotificationSender()
        sender.sendPushNotification(to: token, title: competition.description, body: message)
    }
}
