import SwiftUI
import AVKit
import Combine
import Firebase
import FirebaseStorage
import FirebaseFirestore

struct CameraView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject var cameraModel = CameraViewModel()
    var competition: Competition
    
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
                        presentationMode.wrappedValue.dismiss()
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
    }
    
    private func resetCamera() {
        cameraModel.recordedDuration = 0
        cameraModel.previewURL = nil
        cameraModel.recordedURLs.removeAll()
        cameraModel.session.startRunning()
    }
}

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

    var body: some View {
        if isUploading {
            ProgressView()
                .padding()
        } else {
            GeometryReader { proxy in
                let size = proxy.size
                
                ZStack(alignment: .leading) {
                    CustomVideoPlayer(url: url)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .ignoresSafeArea()
                    
                    // Back Button
                    VStack {
                        HStack {
                            Button(action: {
                                self.showPreview = false
                                self.resetCameraAction()
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
                        Button {
                            submitEntry()
                        } label: {
                            Group {
                                Label {
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 20, weight: .bold, design: .default))
                                } icon: {
                                    Text("Share")
                                        .font(.system(size: 20, weight: .bold, design: .default))
                                }
                                .foregroundColor(.white)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background {
                                Capsule()
                                    .fill(Color(hex: "#1199FF"))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding()
                        .padding(.bottom, 65)
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
        isUploading = true
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            return
        }

        let videoURL = self.url // Direct use without unwrapping

        let db = Firestore.firestore()
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let videoRef = storageRef.child("videos/\(UUID().uuidString).mov")

        // Upload video from the file URL
        videoRef.putFile(from: videoURL, metadata: nil) { metadata, error in
            guard let _ = metadata, error == nil else {
                print("Error uploading video: \(error?.localizedDescription ?? "unknown error")")
                return
            }

            videoRef.downloadURL { result in
                switch result {
                case .success(let downloadURL):
                    // Check for boost expiration in user document
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
                            "videoUrl": downloadURL.absoluteString,
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
                            self.fetchMembersAndNotify(userId: userId, competitionId: self.competitionId)
                        }
                    }
                case .failure(let error):
                    print("Error getting download URL: \(error)")
                    self.isUploading = false
                }
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

