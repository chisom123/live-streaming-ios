import SwiftUI
import PhotosUI
import FirebaseStorage

struct UseLinkInstructionsView: View {
    let link: RatingLink
    let viewModel: RecruitsViewModel
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
    
    private var calculatorSection: some View {
        VStack(spacing: 15) {
            calculatorContent
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var calculatorContent: some View {
        VStack(spacing: 18) {
            calculatorSlider
            ratingsRow
        }
    }
    
    private var ratingsRow: some View {
        HStack {
            Text("Ratings")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("\(Int(calculatorRatings))")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
        }
    }
    
    private var calculatorSlider: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * CGFloat((calculatorRatings - 10) / (100 - 10)), height: 6)
                
                Circle()
                    .fill(Color.blue)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2.5)
                    )
                    .offset(x: geometry.size.width * CGFloat((calculatorRatings - 10) / (100 - 10)) - 12)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let percent = max(0, min(1, value.location.x / geometry.size.width))
                                let newValue = 10 + (percent * (100 - 10))
                                calculatorRatings = round(newValue / 10) * 10
                            }
                            .onEnded { _ in
                                Analytics.shared.track(
                                    event: "ratings_calculator_used",
                                    properties: [
                                        AnalyticsProperty.screenName: "link_instructions",
                                        "link_id": link.id,
                                        "calculated_ratings": Int(calculatorRatings)
                                    ]
                                )
                            }
                    )
            }
        }
        .frame(height: 24)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        Analytics.shared.trackTap(
                            elementId: "close_button",
                            screenName: "link_instructions",
                            properties: [
                                "link_id": link.id,
                                "completion_type": "close_button",
                                "final_calculator_ratings": Int(calculatorRatings),
                                "has_uploaded_photo": link.photoUrl != nil
                            ]
                        )
                        dismiss()
                    }
                    .foregroundColor(.black)
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
                    name: "link_instructions",
                    properties: [
                        "link_id": link.id,
                        "link_rating_count": link.ratingCount,
                        "has_photo": link.photoUrl != nil,
                        "assigned_user_id": link.assignedUserId ?? ""
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
                        viewModel.uploadLinkPhoto(image, for: link)
                    }
                }
            }
        }
        .onChange(of: viewModel.isUploadingPhoto) { uploading in
            if !uploading && uploadedPhoto != nil {
                // Photo upload completed
                hasUploadedPhoto = true
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
                    .font(.system(size: 18, weight: .semibold))
            }
            
            Text("Upload the photo that will be used in your Instagram story")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            VStack(spacing: 12) {
                // Photo Preview
                if viewModel.isUploadingPhoto {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .overlay(
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
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
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            }
                        )
                }
                
                // Upload Button
                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack {
                        Text(photoIsUploaded ? "Change Photo" : "Upload Photo")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(viewModel.isUploadingPhoto)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
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
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Text(photoIsUploaded ? "Copy your unique rating link" : "Upload a photo first to unlock this step")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            VStack(spacing: 12) {
                Text("https://\(link.url)")
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity)
                    .padding(5)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .opacity(photoIsUploaded ? 1.0 : 0.5)
                
                Button(action: copyLink) {
                    HStack(spacing: 8) {
                        Text(showCopiedMessage ? "Link Copied" : (photoIsUploaded ? "Copy Link" : "Upload Photo First"))
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        showCopiedMessage ? Color.green :
                        (photoIsUploaded ? Color.blue : Color.gray.opacity(0.4))
                    )
                    .foregroundColor(photoIsUploaded ? .white : Color.gray.opacity(0.7))
                    .cornerRadius(8)
                }
                .disabled(!photoIsUploaded)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
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
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Text("Add the link to your Instagram story when sharing your photo")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .lineSpacing(2.5)
                .opacity(1.0)
            
            Button(action: {
                Analytics.shared.trackTap(
                    elementId: "see_examples_button",
                    screenName: "link_instructions",
                    properties: ["link_id": link.id]
                )
                showExamples = true
            }) {
                Text("See Examples")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
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
                    .foregroundColor(.primary)
            }
            
            Text("People will rate your story and you can see the results")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .lineSpacing(2.5)
            
            calculatorSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Copy Link Function
    private func copyLink() {
        // Don't copy if no photo uploaded
        guard photoIsUploaded else {
            Analytics.shared.track(
                event: "copy_link_blocked_no_photo",
                properties: [
                    AnalyticsProperty.screenName: "link_instructions",
                    "link_id": link.id
                ]
            )
            return
        }
        
        Analytics.shared.trackTap(
            elementId: "copy_link_button",
            screenName: "link_instructions",
            properties: [
                "link_id": link.id,
                "link_url": link.url
            ]
        )
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        UIPasteboard.general.string = "https://\(link.url)"
        showCopiedMessage = true
        
        Analytics.shared.track(
            event: "link_copied_to_clipboard",
            properties: [
                AnalyticsProperty.screenName: "link_instructions",
                "link_id": link.id
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
                                .foregroundColor(currentIndex > 0 ? .blue : .gray)
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
                                .foregroundColor(currentIndex < exampleImages.count - 1 ? .blue : .gray)
                                .padding()
                        }
                        .disabled(currentIndex == exampleImages.count - 1)
                    }
                }
                
                Text("\(currentIndex + 1) of \(exampleImages.count)")
                    .foregroundColor(.gray)
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.vertical, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
