import SwiftUI

struct LandingView: View {
    @State private var navigateToPhoneEntry = false

    var body: some View {
        NavigationView {
            GeometryReader { _ in
                ZStack {
                    AppColors.background
                        .edgesIgnoringSafeArea(.all)
                    
                    MainContent(navigateToPhoneEntry: $navigateToPhoneEntry)
                    
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

struct MainContent: View {
    @Binding var navigateToPhoneEntry: Bool

    var body: some View {
        VStack {
            Spacer()

            AppLogo()

            Spacer()
            
            DisclaimerText()
            
            ContinueButton(action: {
                navigateToPhoneEntry = true
            })
        }
    }
}

struct AppLogo: View {
    var body: some View {
        Image("Logo")
            .resizable()
            .scaledToFit()
            .frame(width: 100, height: 100)
            .cornerRadius(200)
    }
}

struct DisclaimerText: View {
    var body: some View {
        VStack {
            
            HStack(spacing: 5) {
                Text("Read our")
                
                Text("Privacy Policy")
                    .underline()
                    .onTapGesture {
                        openURL("https://chay-b6172c.webflow.io/privacy-policy")
                    }
                
                Text("and")
                    .font(.system(size: 15, weight: .semibold, design: .default))
                
                Text("Terms of Use")
                    .underline()
                    .onTapGesture {
                        openURL("https://chay-b6172c.webflow.io")
                    }
            }
            .font(.system(size: 15, weight: .semibold, design: .default))
            .foregroundColor(.black)
            .padding(.bottom, 35)
        }
    }
}


struct ContinueButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Agree & Continue")
                .frame(maxWidth: .infinity, minHeight: 44)
                .font(.system(size: 18, weight: .bold, design: .default))
                .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .background(AppColors.primary)
                .foregroundColor(AppColors.white)
                .cornerRadius(200)
        }
        .padding(.horizontal)
        .padding(.bottom, 25)
        .accessibilityLabel("Continue Button")
    }
}
