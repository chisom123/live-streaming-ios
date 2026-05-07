import SwiftUI
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

extension UIImage {
    func optimizedForUpload(maxDimension: CGFloat = 1200.0, compressionQuality: CGFloat = 0.4) -> Data? {
        let resizedImage = self.resizeIfNeeded(maxDimension: maxDimension)
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
        var quality = compressionQuality
        var data = self.jpegData(compressionQuality: quality)
        let targetSize: Int = 500 * 1024
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
    @State private var showUnlockView = false
    @State private var shouldDismissCameraFlow = false
    @State private var overlayText: String = ""
    @State private var overlayVerticalPosition: CGFloat = UIScreen.main.bounds.height / 2
    @State private var isDragging: Bool = false
    @State private var isEditingText: Bool = false
    @StateObject private var themesViewModel = ThemesViewModel()
    @Binding var selectedTheme: Theme?
    @State private var showingThemeSelection = false
    let characterLimit = 150
    var isFromCamera: Bool
    
    var body: some View {
         GeometryReader { proxy in
             ZStack {
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
                                 .padding(.vertical, 10)
                                 .background(AppTheme.accent)
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
                 
                 // Continue Button
                 VStack {
                     Spacer()
                     Button(action: {
                         proceedToUnlock()
                     }) {
                         Text("Continue")
                             .frame(maxWidth: .infinity, minHeight: 44)
                             .font(.system(size: 18, weight: .bold, design: .default))
                             .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                             .background(AppTheme.accent)
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
         .ignoresSafeArea(edges: .all)
         .fullScreenCover(isPresented: $showUnlockView) {
             UnlockView(
                 competition: competition,
                 competitionId: competitionId,
                 image: image,
                 overlayText: overlayText,
                 overlayVerticalPosition: overlayVerticalPosition,
                 isFromCamera: isFromCamera,
                 selectedTheme: selectedTheme
             )
         }
         .sheet(isPresented: $showingThemeSelection) {
             ThemeSelectionSheet(
                 viewModel: themesViewModel,
                 competitionId: competitionId,
                 selectedTheme: $selectedTheme
             )
         }
         .onAppear {
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
    
    // Navigate to unlock view instead of uploading immediately
    private func proceedToUnlock() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            return
        }
        
        // Check if user is superstar at the competition level
        let memberRef = Firestore.firestore()
            .collection("competitions")
            .document(competitionId)
            .collection("members")
            .document(userId)
        
        memberRef.getDocument { (document, error) in
            DispatchQueue.main.async {
                self.showUnlockView = true
            }
        }
    }
}
