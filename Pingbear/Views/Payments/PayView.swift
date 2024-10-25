import SwiftUI
import NotificationBannerSwift
import PostHog

struct PayView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: PayViewModel
    
    @State private var navigateToCompDetails = false // State to control navigation
    
    var competition: Competition
    var competitionId: String // Add this line to hold the competition ID
    var entryDocId: String // Add this line to hold the entry document ID

    
    var body: some View {
        if viewModel.isLoading {
            ProgressView()
                .padding()
        } else {
            GeometryReader { geometry in
                VStack {
                    HStack {
                        Spacer()
                        Button("Skip") {
                            navigateToCompDetails = true
                            PostHogSDK.shared.capture("Boost Skip")
                        }
                        .font(.system(size: 17, weight: .bold, design: .default))
                        .foregroundColor(Color(hex: "#767BFA"))
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 25)
                    .padding(.bottom, 25)
                    
                    Image(systemName: "star.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 45, height: 45)
                        .foregroundColor(Color(hex: "#FFD700"))
                    
                    Text("Get More Stars")
                        .font(.system(size: 25, weight: .bold, design: .default)) // Apply common styling here
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(Color(hex: "#FFF")) // This affects the entire Text view, might need adjustment if it overrides individual colors
                        .padding(.bottom, 20)
                        .padding(.top, 25)
                        .padding(.horizontal, 20)
                    
                    HStack {
                        Text("Get an extra star every time your photos are starred by friends")
                            .font(.system(size: 17, weight: .bold, design: .default)) // Apply common styling here
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .foregroundColor(Color(hex: "#ABAFD1")) // This affects the entire Text view, might need adjustment if it overrides individual colors
                            .padding(.bottom, 20)
                            .padding(.horizontal, 20)
                    }
                    
                    ScrollView {
                        VStack {
                            if let subscriptionProduct1 = viewModel.products.first(where: { $0.productIdentifier == "one_day_boost" }) {
                                Button(action: {
                                    viewModel.purchase(product: subscriptionProduct1)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(subscriptionProduct1.localizedTitle)
                                                .font(.system(size: 18, weight: .bold, design: .default))
                                                .foregroundColor(.white)
                                            
                                            Text(formattedPrice(for: subscriptionProduct1))
                                                .font(.system(size: 15, weight: .bold, design: .default))
                                                .foregroundColor(Color(hex: "#ABAFD1"))
                                                .padding(.top, 5)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.right")
                                            .foregroundColor(Color(hex: "#FFF"))
                                            .font(.system(size: 28))
                                    }
                                    .padding(EdgeInsets(top: 30, leading: 30, bottom: 30, trailing: 30))
                                    .background(Color(hex: "#292544"))
                                    .cornerRadius(10)
                                }
                                .padding(.vertical, 10)
                            }
                            
                            if let subscriptionProduct2 = viewModel.products.first(where: { $0.productIdentifier == "one_week_boost" }) {
                                Button(action: {
                                    viewModel.purchase(product: subscriptionProduct2)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(subscriptionProduct2.localizedTitle)
                                                .font(.system(size: 18, weight: .bold, design: .default))
                                                .foregroundColor(.white)
                                            
                                            HStack(spacing: 10) {
                                                Text(formattedPrice(for: subscriptionProduct2))
                                                    .font(.system(size: 15, weight: .bold, design: .default))
                                                    .foregroundColor(Color(hex: "#ABAFD1"))
                                                
                                                Text("Save 28%")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .padding(EdgeInsets(top: 3, leading: 7, bottom: 3, trailing: 7))
                                                    .background(Color(hex: "#FF4500")) // Choose a color that stands out
                                                    .cornerRadius(5)
                                            }
                                            .padding(.top, 5)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.right")
                                            .foregroundColor(Color(hex: "#FFF"))
                                            .font(.system(size: 28))
                                    }
                                    .padding(EdgeInsets(top: 30, leading: 30, bottom: 30, trailing: 30))
                                    .background(Color(hex: "#292544"))
                                    .cornerRadius(10)
                                }
                                .padding(.vertical, 10)
                            }
                            
                            if let subscriptionProduct3 = viewModel.products.first(where: { $0.productIdentifier == "one_month_boost" }) {
                                Button(action: {
                                    viewModel.purchase(product: subscriptionProduct3)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(subscriptionProduct3.localizedTitle)
                                                .font(.system(size: 18, weight: .bold, design: .default))
                                                .foregroundColor(.white)
                                            
                                            HStack(spacing: 10) {
                                                Text(formattedPrice(for: subscriptionProduct3))
                                                    .font(.system(size: 15, weight: .bold, design: .default))
                                                    .foregroundColor(Color(hex: "#ABAFD1"))
                                                
                                                Text("Save 53%")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .padding(EdgeInsets(top: 3, leading: 7, bottom: 3, trailing: 7))
                                                    .background(Color(hex: "#FF4500")) // Choose a color that stands out
                                                    .cornerRadius(5)
                                            }
                                            .padding(.top, 5)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.right")
                                            .foregroundColor(Color(hex: "#FFF"))
                                            .font(.system(size: 28))
                                    }
                                    .padding(EdgeInsets(top: 30, leading: 30, bottom: 30, trailing: 30))
                                    .background(Color(hex: "#292544"))
                                    .cornerRadius(10)
                                }
                                .padding(.vertical, 10)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 5) {
                        Text("Privacy Policy")
                            .onTapGesture {
                                openURL("https://chay-b6172c.webflow.io/privacy-policy")
                            }
                        
                        Text("•")
                            .font(.system(size: 14, weight: .bold, design: .default))
                        
                        Text("Terms of Use")
                            .onTapGesture {
                                openURL("https://chay-b6172c.webflow.io")
                            }
                    }
                    .font(.system(size: 14, weight: .bold, design: .default))
                    .foregroundColor(Color(hex: "#ABAFD1"))
                    .padding(.vertical, 20)
                }
            }
            .fullScreenCover(isPresented: $navigateToCompDetails) {
                CompDetails(competition: competition) // Adjust according to your needs
            }
            .onChange(of: viewModel.purchaseCompleted) { completed in
                if completed {
                    navigateToCompDetails = true
                }
            }
            .onAppear {
                viewModel.competitionId = self.competitionId
                viewModel.entryDocId = self.entryDocId
            }
            .background(Color(hex: "#1B1735")) // Set the background color to gray
        }
    }
    
}
