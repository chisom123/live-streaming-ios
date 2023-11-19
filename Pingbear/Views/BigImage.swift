import SwiftUI
import SDWebImageSwiftUI

struct BigImageView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    var imageUrl: String // Accepts the image URL

    var body: some View {
        ZStack {
            // Load and display the image fullscreen, ignoring safe areas
            if let imageURL = URL(string: imageUrl) {
                WebImage(url: imageURL)
                    .resizable()
                    .scaledToFill()
                    .edgesIgnoringSafeArea(.all) // Makes image fullscreen, ignoring safe areas
            } else {
                ProgressView()
                    .edgesIgnoringSafeArea(.all)
            }

            // Button to dismiss the view
            VStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding(5)
                            .shadow(radius: 10)
                    }
                    Spacer()
                }
                .padding(.top, (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0) + 20) // Added 20 points more padding to the top
                .padding(.horizontal)
                Spacer()
            }
        }
    }
}

