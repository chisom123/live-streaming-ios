import SwiftUI

struct LandingView: View {
    @State private var navigateToPhoneEntry = false

    var body: some View {
        NavigationView {
            GeometryReader { fullView in
                ZStack {
                    Color(hex: "#FFE4E1")
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        Spacer()

                        Image("transparent-logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 75, height: 75)

                        Spacer()
                        
                        Text("By continuing, you agree to Pingbear's Privacy Policy and Terms of Service.")
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .multilineTextAlignment(.center)
                            .lineSpacing(13)
                            .foregroundColor(.black)
                            .padding(.horizontal, 25)
                            .padding(.bottom, 25)

                        Button(action: {
                            navigateToPhoneEntry = true
                        }) {
                            Text("Continue")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .font(.system(size: 18, weight: .bold, design: .default))
                                .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .background(Color(hex: "#1199FF"))
                                .foregroundColor(Color(hex: "#fff"))
                                .cornerRadius(200)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 25)
                    }
                    
                    NavigationLink(
                        destination: PhoneEntryView(),
                        isActive: $navigateToPhoneEntry,
                        label: {
                            EmptyView()
                        })
                }
            }
        }
        .accentColor(.black)
    }
}
