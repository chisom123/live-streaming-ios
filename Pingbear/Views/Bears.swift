import SwiftUI
import SDWebImageSwiftUI

struct BearsView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var isPbillViewPresented: Bool = false
    @ObservedObject private var viewModel = BearsViewModel()
    
    var body: some View {
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
                    Spacer()
                }
                
                VStack {
                    Button(action: {
                        self.isPbillViewPresented = true
                    }) {
                        HStack {
                            Text("You have \(viewModel.pBills) P-Bills")
                                .font(.system(size: 16, weight: .semibold, design: .default))
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            Text("Buy P-Bills")
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: "#1199FF"))
                        }
                        .padding([.top, .bottom], 20)
                        .padding([.leading, .trailing], 20)
                    }
                }
                .background(Color(hex: "#F5F5F5"))
                .cornerRadius(5)
                .padding(.top, 30)
                .padding([.leading, .trailing], 20)
                
                ScrollView {
                    HStack {
                        Text("Store")
                            .font(.system(size: 24, weight: .bold, design: .default))
                            .foregroundColor(Color(hex: "#000"))
                            .padding(.leading, 20) // Add padding to the left side
                            .padding(.top, 40)
                        
                        Spacer() // This will push the Text view to the left
                    }
                    
                    VStack(spacing: 25) {
                        ForEach(viewModel.bears, id: \.id) { bear in
                            Button(action: {
                                // Purchase action or navigate to bear details
                            }) {
                                HStack {
                                    // Display the bear image
                                    WebImage(url: URL(string: bear.imageUrl))  // SDWebImageSwiftUI's WebImage to load images from URLs
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 75, height: 75)
                                        .padding(.trailing, 20)
                                    
                                    VStack(alignment: .leading, spacing: 18) {
                                        Text(bear.name)
                                            .font(.system(size: 16, weight: .bold, design: .default))
                                            .foregroundColor(.black)
                                        
                                        if viewModel.pBills >= bear.price {
                                            Text("Buy for \(bear.price) P-Bills")
                                                .font(.system(size: 15, weight: .bold, design: .default))
                                                .foregroundColor(Color(hex: "#1199FF"))
                                        } else {
                                            Text("Buy for \(bear.price) P-Bills")
                                                .font(.system(size: 15, weight: .bold, design: .default))
                                                .foregroundColor(Color(hex: "#1199FF"))
                                        }
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
                
                // This will add padding (whitespace) to the bottom of the last item
                Spacer().frame(height: 30)
                
            }
            .fullScreenCover(isPresented: $isPbillViewPresented, content: {
                PbillView()
            })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
