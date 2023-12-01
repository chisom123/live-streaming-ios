import SwiftUI
import NotificationBannerSwift

struct SuperstarInfoView: View {
    
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

                    Image(systemName: "star")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50) // Slightly larger star icon
                        .foregroundColor(Color(hex: "#DAA520"))
                        .padding(.top, 30)
                    
                    Text("Access the power of Superstar")
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(Color(hex: "#DAA520"))
                        .padding(.bottom, 20)
                        .padding(.top, 30)
                        .padding(.horizontal)
                    
                    Text("$4.99 a month")
                        .font(.system(size: 17, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(Color(hex: "#ababab"))
                        .padding(.bottom, 30)
                        .padding(.horizontal)
                    
                    ScrollView(.vertical) {
                        VStack {
                            
                            Text("A Superstar is worth 8 stars - double the usual amount")
                                .font(.system(size: 17, weight: .semibold, design: .default))
                                .multilineTextAlignment(.center)
                                .lineSpacing(10)
                                .foregroundColor(.black)
                                .padding(.bottom, 10)
                                .padding(.horizontal)
                                .padding(.top, 10)
                            
                        }
                        .frame(minWidth: 0, maxWidth: .infinity) // Making VStack full width
                        .padding()
                        .background(Color(hex: "#F5F5F5"))
                        .cornerRadius(5)
                        .padding(.horizontal, 20)
                        
                        VStack {
                            
                            Text("Everyone can Superstar your photos - which will boost your leaderboard ranking")
                                .font(.system(size: 17, weight: .semibold, design: .default))
                                .multilineTextAlignment(.center)
                                .lineSpacing(10)
                                .foregroundColor(.black)
                                .padding(.bottom, 10)
                                .padding(.horizontal)
                                .padding(.top, 10)
                            
                        }
                        .frame(minWidth: 0, maxWidth: .infinity) // Making VStack full width
                        .padding()
                        .background(Color(hex: "#F5F5F5"))
                        .cornerRadius(5)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        VStack {
                            
                            Text("You can Superstar anyone's photos")
                                .font(.system(size: 17, weight: .semibold, design: .default))
                                .multilineTextAlignment(.center)
                                .lineSpacing(10)
                                .foregroundColor(.black)
                                .padding(.bottom, 10)
                                .padding(.horizontal)
                                .padding(.top, 10)
                            
                        }
                        .frame(minWidth: 0, maxWidth: .infinity) // Making VStack full width
                        .padding()
                        .background(Color(hex: "#F5F5F5"))
                        .cornerRadius(5)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }

                    Button(action: {
                        if let subscriptionProduct = viewModel.products.first(where: { $0.productIdentifier == "sup1" }) {
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
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                    
                    
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
                    .padding(.top, 20)

                    Spacer()
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
