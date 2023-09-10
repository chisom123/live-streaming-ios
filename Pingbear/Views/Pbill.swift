import SwiftUI

struct PbillView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: PbillViewModel

    var body: some View {
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
                Spacer()
            }
            
            ScrollView {
                VStack(spacing: 25) {
                    ForEach(viewModel.products, id: \.productIdentifier) { product in
                        Button(action: {
                            viewModel.purchase(product: product)
                        }) {
                            HStack {
                                // Display the image for the product
                                Image(viewModel.imageName(for: product))
                                    .resizable()
                                    .frame(width: 50, height: 50)
                                    .padding(.trailing, 20)
                                
                                VStack(alignment: .leading, spacing: 18) {
                                    Text(product.localizedTitle)
                                        .font(.system(size: 16, weight: .bold, design: .default))
                                        .foregroundColor(.black)
                                    Text("Continue")
                                        .font(.system(size: 15, weight: .bold, design: .default))
                                        .foregroundColor(Color(hex: "#1199FF"))
                                }

                                Spacer()  // This will push the HStack to take up the entire width.
                            }
                            .padding(.vertical, 35)
                            .padding(.horizontal, 20)
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                        }
                    }
                }
                .padding(.top, 30)
                .padding(.horizontal, 20)
            }


            Spacer().frame(height: 30)
        }
    }
}

