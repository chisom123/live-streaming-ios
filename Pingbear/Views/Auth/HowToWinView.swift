import SwiftUI

struct HowToWinView: View {
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            GeometryReader { geo in
                Image("hero")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Photo competitions with friends")
                    .font(.system(size: 35, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 60)

                HStack {
                    HStack(spacing: 8) {
                        Text("Win Points")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Image("gem")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(.white)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 26, height: 26)
                    }
                    .padding(EdgeInsets(top: 5, leading: 15, bottom: 5, trailing: 15))
                    .background(Color(hex: "#6A5ACD"))
                    .cornerRadius(200)

                    Spacer()
                }
                .padding(.horizontal, 24)

                Spacer()

                Button(action: {
                    Analytics.shared.trackTap(
                        elementId: "how_to_win_view_continue",
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
        }
    }
}
