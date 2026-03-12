import SwiftUI

struct HowToWinView: View {
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "#10183C")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    Image("gem")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.white)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 70, height: 70)
                        .padding(.top, -10)

                    Text("Win more prize points in photo competitions")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .padding(.horizontal, 10)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 50)
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
                    Text("Let's Go")
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
