import SwiftUI
import AVKit

struct StarboardVideoPlayer: View {
    let entry: Entry
    var competition: Competition
    
    @State private var navigateToCompDetails = false
    @State private var isPlaying = true

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            if let videoURL = URL(string: entry.videoUrl) {
                CustomVideoPlayer(url: videoURL, isPlaying: $isPlaying)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isPlaying = false
                        navigateToCompDetails = true
                    }
            } else {
                ProgressView()
                    .onTapGesture {
                        isPlaying = false
                        navigateToCompDetails = true
                    }
            }
            
            VStack {
                HStack {
                    Text(entry.userName)
                        .foregroundColor(.white) // Set the text color to white
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .shadow(radius: 10)
                        .truncationMode(.tail) // Adds an ellipsis at the end of the text if it's too long
                        .lineLimit(1) // Ensures the text is on a single line
                        .frame(maxWidth: 175, alignment: .leading) // Adjust alignment to leading

                    Spacer()

                    Text(timeSince(date: entry.creationDate)) // Use the dynamically computed time
                        .font(.system(size: 15, weight: .bold, design: .default))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.75))
                        .foregroundColor(.white)
                        .cornerRadius(200)
                }
                .padding(.horizontal, 25) // General padding for right side and space between elements
                .padding(.top, safeAreaTopInset() + 20) // Adjust for safe area at the top
                Spacer() // Pushes the text to the top
            }
        }
        .fullScreenCover(isPresented: $navigateToCompDetails) {
            CompDetails(competition: competition) // Adjust according to your needs
        }
        .ignoresSafeArea(edges: .all)
    }
    
    func timeSince(date: Date) -> String {
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
    
    func safeAreaTopInset() -> CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0
    }
}
