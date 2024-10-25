import SwiftUI

struct StarboardPhotoPlayer: View {
    let entry: Entry
    var competition: Competition
    
    @State private var navigateToCompDetails = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if let imageURL = URL(string: entry.photoUrl) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: entry.isFromCamera ? .fill : .fit)
                                .frame(width: size.width, height: size.height)
                                .clipped()
                                .overlay {
                                    if let overlayText = entry.overlayText {
                                        Text(overlayText)
                                            .foregroundColor(.white)
                                            .font(.system(size: 24, weight: .bold))
                                            .shadow(color: .black, radius: 2, x: 1, y: 1)
                                            .multilineTextAlignment(.center)
                                            .frame(width: size.width * 0.8)
                                            .position(x: size.width / 2, y: entry.overlayVerticalPosition)
                                    }
                                }
                        case .failure(_):
                            Image(systemName: "photo.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(.gray)
                                .frame(width: 80, height: 80)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)

                        @unknown default:
                            EmptyView()
                        }
                    }
                    .ignoresSafeArea()
                } else {
                    ProgressView()
                }
                
                VStack {
                    HStack {
                        Text(entry.userName)
                            .foregroundColor(.white)
                            .font(.system(size: 20, weight: .bold, design: .default))
                            .shadow(radius: 10)
                            .truncationMode(.tail)
                            .lineLimit(1)
                            .frame(maxWidth: 175, alignment: .leading)

                        Spacer()

                        Text(timeSince(date: entry.creationDate))
                            .foregroundColor(.white)
                            .font(.system(size: 17, weight: .bold, design: .default))
                            .shadow(radius: 10)
                            .truncationMode(.tail)
                            .lineLimit(1)
                            .frame(maxWidth: 175, alignment: .trailing)
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, safeAreaTopInset() + 20)
                    Spacer()
                }
            }
            .onTapGesture {
                navigateToCompDetails = true
            }
        }
        .fullScreenCover(isPresented: $navigateToCompDetails) {
            CompDetails(competition: competition)
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
