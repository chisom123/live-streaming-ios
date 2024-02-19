import SwiftUI
import NotificationBannerSwift

struct PayView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: PbillViewModel
    
    
    var body: some View {
        if viewModel.isLoading {
            ProgressView()
                .padding()
        } else {
            ZStack {
                VStack {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image("Close")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .padding(.leading, 20)
                                .padding(.top, 20)
                        }
                        
                        Spacer() // This spacer will ensure the two buttons are at opposite ends.
                    }
                    
                    Spacer()
                    
                    Text("Access the power of Superstar")
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(Color(hex: "#000"))
                        .padding(.bottom, 20)
                        .padding(.horizontal)
                    
                    Text("£4.99")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(Color(hex: "#ababab"))
                        .padding(.bottom, 20)
                        .padding(.horizontal)

                    Button(action: {
                        if let subscriptionProduct = viewModel.products.first(where: { $0.productIdentifier == "superstar" }) {
                            viewModel.purchase(product: subscriptionProduct)
                        }
                    }) {
                        Text("Get Superstar")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .background(Color(hex: "#1199FF"))
                            .foregroundColor(Color(hex: "#fff"))
                            .cornerRadius(200)
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    
                    HStack(spacing: 5) {
                        Text("Privacy Policy")
                            .onTapGesture {
                                openURL("https://chay-b6172c.webflow.io/privacy-policy")
                            }
                        
                        Text("•")
                            .font(.system(size: 14, weight: .semibold, design: .default))
                        
                        Text("Terms of Use")
                            .onTapGesture {
                                openURL("https://chay-b6172c.webflow.io")
                            }
                    }
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundColor(.black)
                    .padding(.bottom, 20)
                }
            }
            
            Spacer()
            .onChange(of: viewModel.purchaseCompleted) { completed in
                if completed {
                    presentationMode.wrappedValue.dismiss()
        
                    let banner = NotificationBanner(title: "Superstar Successfully Activated", style: .success)
                    banner.show()
                }
            }
            
        }
    }
    
    
}
