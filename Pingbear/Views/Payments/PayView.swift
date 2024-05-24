import SwiftUI
import NotificationBannerSwift

struct PayView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: PbillViewModel
    
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
                        }
                        .font(.system(size: 15.5, weight: .bold, design: .default))
                        .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 25)
                    
                    (Text("Get an ")
                        + Text("extra star")
                            .underline()
                        + Text(" every time your videos are rated"))
                        .font(.system(size: 22, weight: .bold, design: .default)) // Apply common styling here
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(Color(hex: "#1199FF")) // This affects the entire Text view, might need adjustment if it overrides individual colors
                        .padding(.bottom, 30)
                        .padding(.top, 30)
                        .padding()
                    
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
                                                .foregroundColor(.black)
                                            
                                            Text(formattedPrice(for: subscriptionProduct1))
                                                .font(.system(size: 15, weight: .bold, design: .default))
                                                .foregroundColor(.gray)
                                                .padding(.top, 5)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.right")
                                            .foregroundColor(Color(hex: "#000"))
                                            .font(.system(size: 28))
                                    }
                                    .padding(EdgeInsets(top: 30, leading: 30, bottom: 30, trailing: 30))
                                    .background(Color(hex: "#F5F5F5"))
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
                                                .foregroundColor(.black)
                                            
                                            HStack(spacing: 10) {
                                                Text(formattedPrice(for: subscriptionProduct2))
                                                    .font(.system(size: 15, weight: .bold, design: .default))
                                                    .foregroundColor(.gray)
                                                
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
                                            .foregroundColor(Color(hex: "#000"))
                                            .font(.system(size: 28))
                                    }
                                    .padding(EdgeInsets(top: 30, leading: 30, bottom: 30, trailing: 30))
                                    .background(Color(hex: "#F5F5F5"))
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
                                                .foregroundColor(.black)
                                            
                                            HStack(spacing: 10) {
                                                Text(formattedPrice(for: subscriptionProduct3))
                                                    .font(.system(size: 15, weight: .bold, design: .default))
                                                    .foregroundColor(.gray)
                                                
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
                                            .foregroundColor(Color(hex: "#000"))
                                            .font(.system(size: 28))
                                    }
                                    .padding(EdgeInsets(top: 30, leading: 30, bottom: 30, trailing: 30))
                                    .background(Color(hex: "#F5F5F5"))
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
                    .foregroundColor(.black)
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
        }
    }
    
}
