import SwiftUI

struct InteractionsListView: View {
    let interactions: [PhotoInteraction]
    let isLoading: Bool
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(.white)
                }

                Spacer()

                Text("Viewers")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: {

                }) {
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(.white)
                        .opacity(0)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color(hex: "#1A2245"))

            if isLoading {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                Spacer()
            } else if interactions.isEmpty {
                Spacer()
                Text("No viewers yet")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(interactions) { interaction in
                            VStack(spacing: 0) {
                                HStack {
                                    ProfilePictureView(url: interaction.profilePictureUrl, size: 40)
                                    
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(interaction.userName)
                                            .font(.system(size: 16, weight: .bold, design: .default))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                        
                                        Text("Viewed \(timeAgoString(from: interaction.viewedAt))")
                                            .font(.system(size: 14, weight: .bold, design: .default))
                                            .foregroundColor(Color(hex: "#D3D3D3"))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                    }
                                    .padding(.leading, 10)

                                    Spacer()

                                    if let rating = interaction.rating {
                                        HStack(spacing: 6) {
                                            Text("\(rating)")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)

                                            Image(systemName: "star.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 16, height: 16)
                                                .foregroundColor(.white)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color(hex: "#DAA520"))
                                        .cornerRadius(20)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 15)

                                if interaction.id != interactions.last?.id {
                                    Divider()
                                        .background(Color.white.opacity(0.2))
                                }
                            }
                        }
                    }
                    .background(Color(hex: "#1A2245"))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
        }
        .background(Color(hex: "#10183C").ignoresSafeArea())
        .onAppear {
            Analytics.shared.trackScreen(name: "interactions_list")
        }
    }

    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours >= 24 {
            return "24h ago"
        } else if hours > 0 {
            return "\(hours)h ago"
        } else if minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "just now"
        }
    }
}
