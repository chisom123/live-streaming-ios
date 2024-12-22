import SwiftUI
import Firebase
import FirebaseFirestore
import PostHog

struct MyPostsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel: MyPostsViewModel
    @State private var isLoading = true
    @ObservedObject var competition: Competition
    
    init(competition: Competition) {
        self.competition = competition
        _viewModel = StateObject(wrappedValue: MyPostsViewModel(competitionId: competition.id))
    }
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .resizable() // Allows resizing of the image
                        .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                        .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                        .foregroundColor(Color.black) // Your desired color
                }
                
                Spacer()
                
                Text("My Photos")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.horizontal)
                    .onAppear {
                        PostHogSDK.shared.capture("My Posts View Opened")
                    }
                
                Spacer()
                
                Button(action: {
             
                }) {
                    Image(systemName: "arrow.left")
                        .resizable() // Allows resizing of the image
                        .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                        .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                        .foregroundColor(Color.black) // Your desired color
                        .opacity(0)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.entries.isEmpty {
                Spacer()
                Text("No Photos Yet")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(.gray)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(viewModel.entries) { entry in
                            PostCard(entry: entry)
                        }
                    }
                    .padding(.bottom)
                }
                .refreshable {
                    viewModel.refreshEntries()
                }
            }
        }
        .onAppear {
            viewModel.fetchUserEntries { success in
                isLoading = false
            }
        }
    }
}

struct PostCard: View {
    let entry: Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image - moved outside padding to fill container
            AsyncImage(
                url: URL(string: entry.photoUrl),
                transaction: Transaction(animation: .easeInOut)
            ) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                case .success(let image):
                    ZStack(alignment: .bottomLeading) {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 200)
                            .clipped()
                            
                        if let overlayText = entry.overlayText, !overlayText.isEmpty {
                            Text(overlayText)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                                .multilineTextAlignment(.leading) // Changed to .leading
                                .frame(maxWidth: .infinity, alignment: .leading) // Added frame alignment
                        }
                    }
                    .transition(.opacity)
                case .failure:
                    Image(systemName: "photo")
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color.gray.opacity(0.1))
                @unknown default:
                    EmptyView()
                }
            }
            
            // Stats - keep padding for bottom content
            HStack {
                HStack(spacing: 7) {
                    Text("\(entry.stars)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Image(systemName: "star.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 17, height: 17)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: "#DAA520"))
                .cornerRadius(20)
                
                if entry.isSuperstar {
                    HStack(spacing: 7) {
                        Text("Boost")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green)
                    .cornerRadius(20)
                }
                
                Spacer()
                
                Text(formatDate(entry.creationDate))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .background(Color(hex: "#F5F5F5"))
        .cornerRadius(5)
        .padding(.horizontal, 20)
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.second, .minute, .hour, .day], from: date, to: now)
        
        if let days = components.day, days > 0 {
            return days == 1 ? "1d ago" : "\(days)d ago"
        }
        
        if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1h ago" : "\(hours)h ago"
        }
        
        if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1m ago" : "\(minutes)m ago"
        }
        
        if let seconds = components.second, seconds > 0 {
            return seconds == 1 ? "1s ago" : "\(seconds)s ago"
        }
        
        return "Just now"
    }
}
