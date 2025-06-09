import SwiftUI
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

// Add this extension to UIImage for image optimization
extension UIImage {
    func optimizedForUpload(maxDimension: CGFloat = 1200.0, compressionQuality: CGFloat = 0.4) -> Data? {
        // Step 1: Resize the image if needed
        let resizedImage = self.resizeIfNeeded(maxDimension: maxDimension)
        
        // Step 2: Apply progressive compression until we get a reasonable file size
        return resizedImage.compressedData(compressionQuality: compressionQuality)
    }
    
    private func resizeIfNeeded(maxDimension: CGFloat) -> UIImage {
        let originalWidth = self.size.width
        let originalHeight = self.size.height
        
        // If the image is already smaller than our target, return the original
        if originalWidth <= maxDimension && originalHeight <= maxDimension {
            return self
        }
        
        // Figure out which dimension to scale based on
        let scaleFactor: CGFloat
        if originalWidth > originalHeight {
            scaleFactor = maxDimension / originalWidth
        } else {
            scaleFactor = maxDimension / originalHeight
        }
        
        let newWidth = originalWidth * scaleFactor
        let newHeight = originalHeight * scaleFactor
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        // Render the resized image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    private func compressedData(compressionQuality: CGFloat) -> Data? {
        // Start with the specified compression quality
        var quality = compressionQuality
        var data = self.jpegData(compressionQuality: quality)
        
        // Target size: 500KB for average mobile uploads
        let targetSize: Int = 500 * 1024
        
        // Try progressively lower quality if needed, with a minimum threshold
        while let imageData = data, imageData.count > targetSize && quality > 0.1 {
            quality -= 0.1
            data = self.jpegData(compressionQuality: quality)
        }
        
        return data
    }
}

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
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0.0 // Added to track upload progress
    @State private var newentryDocId: String? // Add this line to hold the entries document ID
    @State private var overlayText: String = ""
    @State private var overlayVerticalPosition: CGFloat = UIScreen.main.bounds.height / 2
    @State private var isDragging: Bool = false
    @State private var isEditingText: Bool = false
    @StateObject private var themesViewModel = ThemesViewModel()
    @StateObject private var payViewModel = PayViewModel()
    @State private var shouldDismissCameraFlow = false
    @Binding var selectedTheme: Theme?
    @State private var showingThemeSelection = false
    let characterLimit = 150
    var isFromCamera: Bool
    
    // Get access to the shared upload manager
    @ObservedObject private var uploadManager = EntryUploadManager.shared
    
    var body: some View {
         GeometryReader { proxy in
             ZStack {
                 if isUploading {
                     Color(hex: "#10183C").edgesIgnoringSafeArea(.all)
                     VStack {
                         // Show progress view with percentage
                         ProgressView(value: uploadProgress, total: 100)
                             .scaleEffect(1.5)
                             .tint(.white)
                             .padding(.horizontal, 40)
                         
                         // Add percentage text below progress bar
                         Text("\(Int(uploadProgress))%")
                             .foregroundColor(.white)
                             .font(.system(size: 17, weight: .medium))
                             .padding(.top)
                     }
                     .padding(50)
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
                             
                             // Theme Button with integrated theme display
                             if !isEditingText {
                                 Button(action: {
                                     showingThemeSelection = true
                                 }) {
                                     HStack(spacing: 5) {
                                         Image(systemName: "tag.fill")
                                             .font(.system(size: 18))
                                             .foregroundColor(.white)
                                         
                                         if let theme = selectedTheme {
                                             // Show the selected theme name directly in the button
                                             Text(theme.name)
                                                 .font(.system(size: 16, weight: .bold))
                                                 .foregroundColor(.white)
                                                 .truncationMode(.tail)
                                                 .lineLimit(1)
                                         } else {
                                             Text("Add Theme")
                                                 .font(.system(size: 16, weight: .bold))
                                                 .foregroundColor(.white)
                                         }
                                     }
                                     .padding(.horizontal, 12)
                                     .padding(.vertical, 8)
                                     .background(Color(hex: "#FF8C00"))
                                     .cornerRadius(200)
                                 }
                             }
                             
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
                             uploadEntryUsingManager()
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
                     .padding(.horizontal, 30)
                 }
             }
         }
         .ignoresSafeArea(edges: .all)
         .fullScreenCover(isPresented: $entrySaved) {
             if let entryDocId = newentryDocId {
                 PayView(viewModel: payViewModel, competition: competition, competitionId: competitionId, entryDocId: entryDocId)
             }
         }
         .sheet(isPresented: $showingThemeSelection) {
             ThemeSelectionSheet(
                 viewModel: themesViewModel,
                 competitionId: competitionId,
                 selectedTheme: $selectedTheme
             )
         }
         .onAppear {
             // Initialize the upload manager when view appears
             EntryUploadManager.shared.initialize()
             
             // Load themes on appearance
             themesViewModel.loadThemes(for: competitionId)
         }
         .onChange(of: shouldDismissCameraFlow) { shouldDismiss in
             if shouldDismiss {
                 // Post notification to dismiss entire camera flow
                 NotificationCenter.default.post(name: .dismissCameraFlow, object: nil)
             }
         }
     }
    
    // Upload entry using EntryUploadManager
    private func uploadEntryUsingManager() {
        guard !isUploading else { return }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            return
        }
        
        // Set local state
        isUploading = true
        uploadProgress = 0.0
                
        EntryUploadManager.shared.uploadEntry(
            image: image,
            competitionId: competitionId,
            userId: userId,
            overlayText: overlayText,
            overlayVerticalPosition: overlayVerticalPosition,
            isFromCamera: isFromCamera,
            themeId: selectedTheme?.id,
            themeName: selectedTheme?.name,
            competition: competition,
            onProgress: { progress in
                // Update local progress
                self.uploadProgress = progress * 100 // Convert to percentage
            },
            onSuccess: { entryId in
                // Handle success
                self.newentryDocId = entryId
                
                // Check if user is superstar at the competition level
                let memberRef = Firestore.firestore()
                    .collection("competitions")
                    .document(competitionId)
                    .collection("members")
                    .document(userId)
                
                memberRef.getDocument { (document, error) in
                    var superstar = false
                    if let document = document, document.exists {
                        if let boostExpiration = document.data()?["boostExpiration"] as? Timestamp {
                            let now = Timestamp(date: Date())
                            superstar = boostExpiration.compare(now) == .orderedDescending
                        }
                    }
                    
                    // Navigate based on superstar status
                    DispatchQueue.main.async {
                        if superstar {
                            shouldDismissCameraFlow = true
                        } else {
                            self.entrySaved = true
                        }
                    }
                }
            },
            onFailure: { error in
                // Handle failure
                print("Failed to upload entry: \(error.localizedDescription)")
                self.isUploading = false
            }
        )
    }
}
