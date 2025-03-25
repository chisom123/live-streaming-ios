import SwiftUI
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import PostHog
import FirebaseMessaging

struct CustomTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isEditingText: Bool
    let characterLimit: Int
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.boldSystemFont(ofSize: 24)
        textView.textColor = .white
        textView.backgroundColor = .clear
        textView.textAlignment = .center
        textView.isScrollEnabled = true
        textView.returnKeyType = .done
        textView.tintColor = .white
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        if isEditingText && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isEditingText && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
        
        // Adjust the height of the text view based on its content
        let fixedWidth = uiView.frame.size.width
        let newSize = uiView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
        uiView.frame.size = CGSize(width: max(newSize.width, fixedWidth), height: newSize.height)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextView
        
        init(_ parent: CustomTextView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            if textView.text.count > parent.characterLimit {
                textView.text = String(textView.text.prefix(parent.characterLimit))
            }
            parent.text = textView.text
            
            // Adjust the height of the text view based on its content
            let fixedWidth = textView.frame.size.width
            let newSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
            textView.frame.size = CGSize(width: max(newSize.width, fixedWidth), height: newSize.height)
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" {
                textView.resignFirstResponder()
                parent.isEditingText = false
                return false
            }
            
            let newText = (textView.text as NSString).replacingCharacters(in: range, with: text)
            return newText.count <= parent.characterLimit
        }
    }
}

struct FinalPreview: View {
    var image: UIImage
    @Binding var showPreview: Bool
    var competition: Competition
    var competitionId: String
    var resetCameraAction: () -> Void
    @State private var entrySaved = false
    @State private var navigateToCompDetails = false // State to control navigation
    @State private var isUploading = false
    @State private var newentryDocId: String? // Add this line to hold the entries document ID
    @State private var overlayText: String = ""
    @State private var overlayVerticalPosition: CGFloat = UIScreen.main.bounds.height / 2
    @State private var isDragging: Bool = false
    @State private var isEditingText: Bool = false
    @StateObject private var notificationSender = PushNotificationSender()
    let characterLimit = 150
    var isFromCamera: Bool

    var body: some View {
         GeometryReader { proxy in
             ZStack {
                 if isUploading {
                     Color(hex: "#10183C").edgesIgnoringSafeArea(.all)
                     VStack {
                         ProgressView()
                             .scaleEffect(1.5)
                             .tint(.white)
                     }
                 } else {
                     Color(hex: "#10183C")
                         .edgesIgnoringSafeArea(.all)
                     
                     Image(uiImage: image)
                         .resizable()
                         .aspectRatio(contentMode: isFromCamera ? .fill : .fit)
                         .frame(width: proxy.size.width, height: proxy.size.height)
                         .clipped()
                     
                     // Text Overlay (visible when not editing)
                     if !isEditingText {
                         Text(overlayText)
                             .foregroundColor(.white)
                             .font(Font(UIFont.customBoldFont(ofSize: 24)))
                             .multilineTextAlignment(.center)
                             .frame(width: proxy.size.width * 0.8)
                             .position(x: proxy.size.width / 2, y: overlayVerticalPosition)
                             .gesture(
                                 DragGesture()
                                     .onChanged { value in
                                         self.overlayVerticalPosition = value.location.y
                                         self.isDragging = true
                                     }
                                     .onEnded { _ in
                                         self.isDragging = false
                                     }
                             )
                             .animation(.interactiveSpring(), value: isDragging)
                             .onTapGesture {
                                 self.isEditingText = true
                             }
                     }
                     
                     // Text Editor (appears when editing)
                     if isEditingText {
                         Color.black.opacity(0.3)
                             .edgesIgnoringSafeArea(.all)
                             .onTapGesture {
                                 self.isEditingText = false
                             }
                         
                         CustomTextView(text: $overlayText, isEditingText: $isEditingText, characterLimit: characterLimit)
                             .frame(width: proxy.size.width * 0.8, height: proxy.size.height * 0.5)
                             .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                     }
                     
                     // Top buttons
                     VStack {
                         HStack {
                             // Back Button
                             Button(action: {
                                 self.showPreview = false
                                 self.resetCameraAction()
                             }) {
                                 Image(systemName: "xmark")
                                     .font(.system(size: 30))
                                     .foregroundColor(.white)
                                     .padding(5)
                                     .shadow(radius: 10)
                             }
                             .opacity(isEditingText ? 0 : 1)
                             
                             Spacer()
                             
                             // Text Button (doubles as Done button)
                             Button(action: {
                                 self.isEditingText.toggle()
                             }) {
                                 if isEditingText {
                                     Image(systemName: "xmark")
                                         .font(.system(size: 30))
                                         .foregroundColor(.white)
                                         .padding(5)
                                         .shadow(radius: 10)
                                 } else {
                                     Text("Aa")
                                         .font(.system(size: 30, weight: .bold))
                                         .foregroundColor(.white)
                                         .padding(5)
                                         .shadow(radius: 10)
                                 }
                             }
                         }
                         .padding(.top, 50)
                         .padding(20)
                         
                         Spacer()
                     }
                     
                     // Share Button
                     VStack {
                         Spacer()
                         Button(action: {
                             isUploading = true
                             // Send dummy notification to warm up the function before submitting the entry
                             sendDummyNotification {
                                 submitEntry()
                             }
                         }) {
                             Text("Share")
                                 .frame(maxWidth: .infinity, minHeight: 44)
                                 .font(.system(size: 18, weight: .bold, design: .default))
                                 .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                 .background(Color(hex: "#FF4081"))
                                 .foregroundColor(.white)
                                 .cornerRadius(200)
                         }
                         .padding(.horizontal, 20)
                         .padding(.bottom, (UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0) + 20)
                         .opacity(isEditingText ? 0 : 1)
                     }
                 }
             }
         }
         .ignoresSafeArea(edges: .all)
         .fullScreenCover(isPresented: $entrySaved) {
             if let entryDocId = newentryDocId {
                 PayView(viewModel: PayViewModel(), competition: competition, competitionId: competitionId, entryDocId: entryDocId)
             }
         }
         .fullScreenCover(isPresented: $navigateToCompDetails) {
             if let entryDocId = newentryDocId {
                 CompDetails(competition: competition)
             }
         }
     }
    
    // Add a function to send a dummy notification
    func sendDummyNotification(completion: (() -> Void)? = nil) {
        // Get the current FCM token
        if let token = Messaging.messaging().fcmToken {
            // Send a silent dummy notification that won't be shown to the user
            notificationSender.sendPushNotification(
                to: token,
                title: "warmup",
                body: "warmup",
                completion: { result in
                    switch result {
                    case .success:
                        print("Warmup notification sent successfully")
                    case .failure(let error):
                        print("Failed to send warmup notification: \(error.localizedDescription)")
                    }
                    // Execute the completion handler regardless of success/failure
                    DispatchQueue.main.async {
                        completion?()
                    }
                }
            )
        } else {
            print("FCM token not available for warmup notification")
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
    
    func submitEntry() {
        isUploading = true
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            return
        }

        // Convert image to data
        guard let imageData = image.jpegData(compressionQuality: 0.6) else {
            print("Failed to convert image to data")
            DispatchQueue.main.async {
                self.isUploading = false
            }
            return
        }
        
        // Upload the image
        let storageRef = Storage.storage().reference().child("images/\(UUID().uuidString).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "competitionId": self.competitionId,
            "userId": userId
        ]
        
        let uploadTask = storageRef.putData(imageData, metadata: metadata)
        
        uploadTask.observe(.success) { _ in
            storageRef.downloadURL { result in
                switch result {
                case .success(let downloadURL):
                    self.saveEntryToFirestore(userId: userId, imageURL: downloadURL.absoluteString)
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
    
    func saveEntryToFirestore(userId: String, imageURL: String) {
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
                "imageUrl": imageURL,
                "timestamp": FieldValue.serverTimestamp(),
                "superstar": superstar,
                "overlayText": self.overlayText,
                "overlayVerticalPosition": self.overlayVerticalPosition,
                "isFromCamera": self.isFromCamera  // Add this field
            ]
            
            var newEntryRef: DocumentReference? = nil
            newEntryRef = db.collection("competitions").document(self.competitionId).collection("entries").addDocument(data: entryData) { error in
                if let error = error {
                    print("Error saving entry: \(error)")
                } else {
                    self.newentryDocId = newEntryRef?.documentID
                    print("Entry saved successfully")
                    
                    DispatchQueue.main.async {
                        // Queue the notification to be sent later - after UI transitions are complete
                        NotificationQueueManager.shared.queueNotification(
                            competitionId: self.competitionId,
                            competitionDescription: self.competition.description,
                            userId: userId
                        )
                        
                        PostHogSDK.shared.capture("New Photo Shared")
                        
                        if superstar {
                            self.navigateToCompDetails = true
                        } else {
                            self.entrySaved = true
                        }
                    }
                }
            }
        }
    }
}
