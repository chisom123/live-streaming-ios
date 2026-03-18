import SwiftUI

struct HowToWinView: View {
    var onContinue: () -> Void
    @StateObject private var viewModel = HowToWinViewModel()

    var body: some View {
        ZStack {
            Color(hex: "#10183C")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    // Header
                    Text("My Stats")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color(hex: "#323862"))

                    // Player Stars Card
                    VStack(spacing: 16) {
                        ProfilePictureView(url: viewModel.profilePictureUrl, size: 70)

                        Text(viewModel.displayName.isEmpty ? "Loading..." : viewModel.displayName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text("\(viewModel.totalStars)")
                                .font(.system(size: 21, weight: .bold))
                                .foregroundColor(.white)

                            Image("gem")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(.white)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 22, height: 22)
                        }
                        .padding(EdgeInsets(top: 7, leading: 18, bottom: 7, trailing: 18))
                        .background(Color(hex: "#6A5ACD"))
                        .cornerRadius(200)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .padding(.horizontal, 20)
                    .background(Color(hex: "#2A3255"))
                }
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#1A2245"))
                .cornerRadius(10)
                .padding(.horizontal, 20)

                Spacer()

                Button(action: {
                    Analytics.shared.trackTap(
                        elementId: "how_to_win_continue",
                        screenName: "how_to_win"
                    )
                    onContinue()
                }) {
                    Text("Continue")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color(hex: "#4169E1"))
                        .cornerRadius(200)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Analytics.shared.trackScreen(name: "how_to_win")
            viewModel.load()
        }
    }
}
