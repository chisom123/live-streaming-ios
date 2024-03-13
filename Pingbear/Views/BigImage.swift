import SwiftUI
import SDWebImageSwiftUI

struct BigImageView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    var imageUrl: String // Accepts the image URL

    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            
            // Load and display the image fullscreen, ignoring safe area
            if let imageURL = URL(string: imageUrl) {
                WebImage(url: imageURL)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
            }
        }
        .edgesIgnoringSafeArea(.all) // Ensure the ZStack fills the entire screen area
        .onTapGesture {
            presentationMode.wrappedValue.dismiss() // Apply the tap gesture to the entire ZStack
        }
    }
}
