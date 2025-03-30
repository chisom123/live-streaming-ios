import SwiftUI

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
                .tint(.white)
                .scaleEffect(1.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#10183C"))
        } else {
            GeometryReader { geometry in
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            navigateToCompDetails = true
                            Analytics.shared.track(event: "boost_skipped")
                        }) {
                            Image("x")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(.white) // or any color you want
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 35, height: 35)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    
                    Text("Boost Your Ratings")
                        .font(.system(size: 25, weight: .bold, design: .default)) // Apply common styling here
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(Color(hex: "#FFF")) // This affects the entire Text view, might need adjustment if it overrides individual colors
                        .padding(.bottom, 20)
                        .padding(.top, 20)
                        .padding(.horizontal, 20)
                    
                    HStack {
                        Text("Get an extra star every time your photos are rated")
                            .font(.system(size: 18, weight: .bold, design: .default)) // Apply common styling here
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .foregroundColor(Color(hex: "#FFF").opacity(0.8)) // This affects the entire Text view, might need adjustment if it overrides individual colors
                            .padding(.bottom, 20)
                            .padding(.horizontal, 20)
                    }
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            if let subscriptionProduct3 = viewModel.products.first(where: { $0.productIdentifier == "one_hour_boost" }) {
                                Button(action: {
                                    viewModel.purchase(product: subscriptionProduct3)
                                }) {
                                    HStack {
                                        HStack {
                                            Text(subscriptionProduct3.localizedTitle)
                                                .font(.system(size: 18, weight: .bold, design: .default))
                                                .foregroundColor(.white)
                                            
                                            Text(formattedPrice(for: subscriptionProduct3))
                                                .font(.system(size: 15, weight: .bold, design: .default))
                                                .foregroundColor(Color(hex: "#FFF").opacity(0.8))
                                        }
                                        Spacer()
                                        ZStack {
                                            Image(systemName: "arrow.right")
                                                .foregroundColor(.white) // White arrow
                                                .font(.system(size: 18, weight: .bold))
                                        }
                                        .frame(width: 36, height: 36) // Adjust the size as needed
                                        .background(Color(hex: "#FF4081")) // Pink background
                                        .cornerRadius(5)
                                    }
                                    .padding(EdgeInsets(top: 30, leading: 30, bottom: 30, trailing: 30))
                                }
                                
                                // Add divider after first item if it's not the last item
                                Divider()
                                    .background(Color.white.opacity(0.2))
                            }
                            
                            if let subscriptionProduct1 = viewModel.products.first(where: { $0.productIdentifier == "one_day_boost" }) {
                                Button(action: {
                                    viewModel.purchase(product: subscriptionProduct1)
                                }) {
                                    HStack {
                                        HStack {
                                            Text(subscriptionProduct1.localizedTitle)
                                                .font(.system(size: 18, weight: .bold, design: .default))
                                                .foregroundColor(.white)
                                            
                                            Text(formattedPrice(for: subscriptionProduct1))
                                                .font(.system(size: 15, weight: .bold, design: .default))
                                                .foregroundColor(Color(hex: "#FFF").opacity(0.8))
                                        }
                                        Spacer()
                                        ZStack {
                                            Image(systemName: "arrow.right")
                                                .foregroundColor(.white) // White arrow
                                                .font(.system(size: 18, weight: .bold))
                                        }
                                        .frame(width: 36, height: 36) // Adjust the size as needed
                                        .background(Color(hex: "#FF4081")) // Pink background
                                        .cornerRadius(5)
                                    }
                                    .padding(EdgeInsets(top: 30, leading: 30, bottom: 30, trailing: 30))
                                }
                                
                                // Add divider after second item if there's still another item
                                Divider()
                                    .background(Color.white.opacity(0.2))
                            }
                            
                            if let subscriptionProduct2 = viewModel.products.first(where: { $0.productIdentifier == "one_week_boost" }) {
                                Button(action: {
                                    viewModel.purchase(product: subscriptionProduct2)
                                }) {
                                    HStack {
                                        HStack {
                                            Text(subscriptionProduct2.localizedTitle)
                                                .font(.system(size: 18, weight: .bold, design: .default))
                                                .foregroundColor(.white)
                                            
                                            Text(formattedPrice(for: subscriptionProduct2))
                                                .font(.system(size: 15, weight: .bold, design: .default))
                                                .foregroundColor(Color(hex: "#FFF").opacity(0.8))
                                        }
                                        Spacer()
                                        ZStack {
                                            Image(systemName: "arrow.right")
                                                .foregroundColor(.white) // White arrow
                                                .font(.system(size: 18, weight: .bold))
                                        }
                                        .frame(width: 36, height: 36) // Adjust the size as needed
                                        .background(Color(hex: "#FF4081")) // Pink background
                                        .cornerRadius(5)
                                    }
                                    .padding(EdgeInsets(top: 30, leading: 30, bottom: 30, trailing: 30))
                                }
                            }
                        }
                        .background(Color(hex: "#1A2245"))
                        .cornerRadius(5)
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
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                    .padding(.vertical, 20)
                }
            }
            .background(Color(hex: "#10183C"))
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
                NotificationQueueManager.shared.processQueuedNotifications()
                Analytics.shared.trackScreen(name: "boost_options")
            }
        }
    }
    
}
