import SwiftUI

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
                    
                    VStack {
                        
                        Image(systemName: "star")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50) // Slightly larger star icon
                            .foregroundColor(Color(hex: "#DAA520"))
                            .padding(.top, 15)
                        
                        Text("Superstar = 8 stars")
                            .font(.system(size: 22, weight: .semibold, design: .default))
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .foregroundColor(Color(hex: "#DAA520"))
                            .padding(.bottom, 35)
                            .padding(.top, 35)
                            .padding(.horizontal)
                        
                        Text("• Everyone will be able to Superstar your pictures")
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .foregroundColor(.black)
                            .padding(.bottom, 30)
                            .padding(.horizontal)
                        
                        Text("• You will be able to Superstar everyones pictures")
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .foregroundColor(.black)
                            .padding(.bottom, 30)
                            .padding(.horizontal)
                        
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
                        .padding(.bottom, 15)
                        .padding(.top, 10)
                    }
                    .padding(20)
                    .background(Color(hex: "#F5F5F5"))
                    .cornerRadius(5)
                    .padding(.horizontal, 20)
                    


                    Spacer()
                }
            }
            
            Spacer()
            
            
        }
    }

}
