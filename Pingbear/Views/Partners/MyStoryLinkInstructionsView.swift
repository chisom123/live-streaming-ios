import SwiftUI
import PhotosUI
import FirebaseStorage

struct MyStoryLinkInstructionsView: View {
    let link: RatingLink
    let viewModel: MyStoryLinksViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedMessage = false
    @State private var hasTrackedView = false
    @State private var calculatorRatings = 30.0
    @State private var showExamples = false
    
    // Photo upload states
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var uploadedPhoto: UIImage?
    @State private var isUploadingPhoto = false
    @State private var hasUploadedPhoto = false
    
    // Computed property to check if photo is available
    private var photoIsUploaded: Bool {
        hasUploadedPhoto || link.photoUrl != nil
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    Text("How to Use Link")
                        .font(.system(size: 24, weight: .bold))
                        .padding(.bottom)
                    
                    // Step 1: Upload Photo
                    uploadPhotoStepView
                    
                    // Step 2: Copy Link
                    copyLinkStepView
                    
                    // Step 3: Add to Story
                    addToStoryStepView
                    
                    // Step 4: Get Ratings
                    getRatingsStepView
                }
                .padding()
            }
            .background(Color(hex: "#10183C"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        Analytics.shared.trackTap(
                            elementId: "close_button",
                            screenName: "my_story_link_instructions",
                            properties: [
                                "link_id": link.id,
                                "completion_type": "close_button",
                                "final_calculator_ratings": Int(calculatorRatings),
                                "has_uploaded_photo": link.photoUrl != nil,
                                "recruiter_id": link.recruiterId
                            ]
                        )
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showExamples) {
            ExamplesView()
        }
        .onAppear {
            if !hasTrackedView {
                Analytics.shared.trackScreen(
                    name: "my_story_link_instructions",
                    properties: [
                        "link_id": link.id,
                        "link_rating_count": link.ratingCount,
                        "has_photo": link.photoUrl != nil,
                        "recruiter_id": link.recruiterId
                    ]
                )
                hasTrackedView = true
            }
            
            // Set hasUploadedPhoto if photo already exists
            if link.photoUrl != nil {
                hasUploadedPhoto = true
            }
        }
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        uploadedPhoto = image
                        isUploadingPhoto = true
                    }
                    
                    // Upload the photo
                    viewModel.uploadLinkPhoto(image, for: link)
                }
            }
        }
        .onChange(of: viewModel.isUploadingPhoto) { uploading in
            DispatchQueue.main.async {
                isUploadingPhoto = uploading
                
                if !uploading && uploadedPhoto != nil {
                    // Photo upload completed
                    hasUploadedPhoto = true
                }
            }
        }
    }
    
    // MARK: - Upload Photo Step
    private var uploadPhotoStepView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                Text("1")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.green)
                
                Text("Upload Photo")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("Upload the photo that will be used in your Instagram story")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.gray)
                .lineSpacing(2)
            
            VStack(spacing: 12) {
                // Photo Preview
                if viewModel.isUploadingPhoto {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .overlay(
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                } else if let photoUrl = link.photoUrl, !photoUrl.isEmpty {
                    AsyncImage(url: URL(string: photoUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                    }
                } else if let uploadedPhoto = uploadedPhoto {
                    Image(uiImage: uploadedPhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        )
                }
                
                // Upload Button
                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Text(photoIsUploaded ? "Change Photo" : "Upload Photo")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color(hex: "#4169E1"))
                        .foregroundColor(.white)
                        .cornerRadius(200)
                        .padding(.top, 10)
                }
                .disabled(viewModel.isUploadingPhoto)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(hex: "#1A2245"))
        .cornerRadius(8)
    }
    
    // MARK: - Copy Link Step
    private var copyLinkStepView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                Text("2")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.green)
                
                Text("Copy Link")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(photoIsUploaded ? "Copy your unique rating link" : "Upload a photo first to unlock this step")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.gray)
                .lineSpacing(2)
            
            VStack(spacing: 12) {
                Text("https://\(link.url)")
                    .frame(maxWidth: .infinity)
                    .padding(5)
                    .padding(.vertical, 10)
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .opacity(photoIsUploaded ? 1.0 : 0.5)
                
                Button(action: copyLink) {
                    Text(showCopiedMessage ? "Link Copied" : (photoIsUploaded ? "Copy Link" : "Upload Photo First"))
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            showCopiedMessage ? Color(hex: "#00AA00") :
                            (photoIsUploaded ? Color(hex: "#4169E1") : Color.gray.opacity(0.4))
                        )
                        .foregroundColor(photoIsUploaded ? .white : Color.gray.opacity(0.7))
                        .cornerRadius(200)
                        .padding(.top, 10)
                }
                .disabled(!photoIsUploaded)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(hex: "#1A2245"))
        .cornerRadius(8)
    }
    
    // MARK: - Add to Story Step
    private var addToStoryStepView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                Text("3")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.green)
                
                Text("Add Link to Story")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("Add the link to your Instagram story when sharing your photo")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.gray)
                .lineSpacing(2)
            
            Button(action: {
                Analytics.shared.trackTap(
                    elementId: "see_examples_button",
                    screenName: "my_story_link_instructions",
                    properties: [
                        "link_id": link.id,
                        "recruiter_id": link.recruiterId
                    ]
                )
                showExamples = true
            }) {
                Text("See Examples")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color(hex: "#4169E1"))
                    .foregroundColor(.white)
                    .cornerRadius(200)
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(hex: "#1A2245"))
        .cornerRadius(8)
    }
    
    // MARK: - Get Ratings Step
    private var getRatingsStepView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                Text("4")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.green)
                
                Text("Get Ratings")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text("The ratings you receive boost your rank in the $100 weekly prize pool")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.gray)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(hex: "#1A2245"))
        .cornerRadius(8)
    }
    
    // MARK: - Copy Link Function
    private func copyLink() {
        // Don't copy if no photo uploaded
        guard photoIsUploaded else {
            Analytics.shared.track(
                event: "story_link_copy_blocked_no_photo",
                properties: [
                    AnalyticsProperty.screenName: "my_story_link_instructions",
                    "link_id": link.id,
                    "recruiter_id": link.recruiterId
                ]
            )
            return
        }
        
        Analytics.shared.trackTap(
            elementId: "copy_link_button",
            screenName: "my_story_link_instructions",
            properties: [
                "link_id": link.id,
                "link_url": link.url,
                "recruiter_id": link.recruiterId
            ]
        )
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        UIPasteboard.general.string = "https://\(link.url)"
        showCopiedMessage = true
        
        Analytics.shared.track(
            event: "story_link_copied_to_clipboard",
            properties: [
                AnalyticsProperty.screenName: "my_story_link_instructions",
                "link_id": link.id,
                "recruiter_id": link.recruiterId
            ]
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedMessage = false
        }
    }
}

struct ExamplesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    
    private let exampleImages = ["example1", "example2", "example3", "example4"]
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Example Stories")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.vertical)
                
                ZStack {
                    TabView(selection: $currentIndex) {
                        ForEach(0..<exampleImages.count, id: \.self) { index in
                            Image(exampleImages[index])
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .tag(index)
                                .cornerRadius(8)
                                .padding(.horizontal, 70)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    
                    HStack {
                        Button(action: {
                            withAnimation {
                                currentIndex = max(0, currentIndex - 1)
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(currentIndex > 0 ? .white : .gray)
                                .padding()
                        }
                        .disabled(currentIndex == 0)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                currentIndex = min(exampleImages.count - 1, currentIndex + 1)
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(currentIndex < exampleImages.count - 1 ? .white : .gray)
                                .padding()
                        }
                        .disabled(currentIndex == exampleImages.count - 1)
                    }
                }
                
                Text("\(currentIndex + 1) of \(exampleImages.count)")
                    .foregroundColor(.white)
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.vertical, 8)
            }
            .background(Color(hex: "#10183C"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
