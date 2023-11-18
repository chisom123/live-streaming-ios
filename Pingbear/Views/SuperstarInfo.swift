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

                // "Continue" Button at the bottom
                Button(action: {
                    if let subscriptionProduct = viewModel.products.first(where: { $0.productIdentifier == "sup1" }) {
                        viewModel.purchase(product: subscriptionProduct)
                    }
                }) {
                    Text("Continue")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(Color(hex: "#1199FF")) // Assuming Color(hex: "#1199FF") is equivalent to blue
                        .foregroundColor(.white)
                        .cornerRadius(200)
                }
                .padding(.horizontal)
                .padding(.bottom, (UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0) + 20) // Added 20 points more padding to the top
                
            }
        }
    }

}
