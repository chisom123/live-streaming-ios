import SwiftUI
import SDWebImageSwiftUI

struct BigImageView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    var imageUrl: String // Accepts the image URL
    var creationDate: Date // Accept the creation date
    
    // No need for @State private var timeAgo: String = "" anymore
    private func timeSince(date: Date) -> String {
        let currentTime = Date()
        let timeInterval = currentTime.timeIntervalSince(date)

        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return minutes == 1 ? "1 min ago" : "\(minutes) mins ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else {
            let days = Int(timeInterval / 86400)
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
    }

    
    // Compute timeAgo statically
    private var timeAgo: String {
        timeSince(date: creationDate)
    }
    
    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            
            if let imageURL = URL(string: imageUrl) {
                WebImage(url: imageURL)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                VStack {
                    HStack {
                        Spacer()
                        Text(timeAgo) // Use the statically computed timeAgo
                            .font(.system(size: 15, weight: .bold, design: .default))
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.75))
                            .foregroundColor(.white)
                            .cornerRadius(200)
                    }
                    .padding(.top, (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0) + 20)
                    .padding(.trailing, (UIApplication.shared.windows.first?.safeAreaInsets.right ?? 0) + 20)
                    Spacer()
                }
            } else {
                ProgressView()
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onTapGesture {
            presentationMode.wrappedValue.dismiss()
        }
    }
}
