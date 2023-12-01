import SwiftUI

// Theme or constants file
struct AppColors {
    static let background = Color(hex: "#FFF")
    static let primary = Color(hex: "#1199FF")
    static let white = Color(hex: "#fff")
}

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
        Image("transparent-logo")
            .resizable()
            .scaledToFit()
            .frame(width: 115, height: 115)
    }
}

struct DisclaimerText: View {
    var body: some View {
        VStack {
            
            HStack(spacing: 5) {
                Text("Privacy Policy")
                    .onTapGesture {
                        openURL("https://chay-b6172c.webflow.io/privacy-policy")
                    }
                
                Text("•")
                    .font(.system(size: 15, weight: .semibold, design: .default))
                
                Text("Terms of Service")
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

func openURL(_ urlString: String) {
    if let url = URL(string: urlString) {
        UIApplication.shared.open(url)
    }
}



struct ContinueButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Continue")
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
