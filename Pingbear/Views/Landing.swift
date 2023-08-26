import SwiftUI

struct LandingView: View {
    @State private var navigateToPhoneEntry = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#FFE4E1")
                    .edgesIgnoringSafeArea(.all)

                VStack {
                    Spacer()

                    Image("transparent-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)

                    Spacer()

                    Text("By continuing, you agree to Pingbear's Terms \n of Service and Privacy Policy.")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(13)
                        .foregroundColor(.black)
                        .padding(.bottom, 40)
                        .padding(.horizontal)

                    NavigationLink(
                        destination: PhoneEntryView(),
                        isActive: $navigateToPhoneEntry,
                        label: {
                            EmptyView()
                        })

                    Button("Continue") {
                        navigateToPhoneEntry = true
                    }
                    .padding(EdgeInsets(top: 18, leading: 0, bottom: 18, trailing: 0))
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "#1199FF"))
                    .foregroundColor(Color(hex: "#fff"))
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .cornerRadius(200)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
        .accentColor(.black) 
    }
}

