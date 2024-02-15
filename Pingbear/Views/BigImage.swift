import SwiftUI
import SDWebImageSwiftUI

struct BigImageView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    var imageUrl: String // Accepts the image URL

    var body: some View {
        ZStack {
            // Load and display the image fullscreen, ignoring safe area
            if let imageURL = URL(string: imageUrl) {
                WebImage(url: imageURL)
                    .resizable()
                    .scaledToFill()
                    .edgesIgnoringSafeArea(.all) // Makes image fullscreen, ignoring safe areas
                    .onTapGesture {
                        presentationMode.wrappedValue.dismiss()
                    }
            } else {
                ProgressView()
                    .edgesIgnoringSafeArea(.all)
            }
        }
    }
}
