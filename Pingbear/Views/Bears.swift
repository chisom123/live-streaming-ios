import SwiftUI
import SDWebImageSwiftUI
import FirebaseAuth


struct BearsView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var isPbillViewPresented: Bool = false
    @State private var isMyBearsViewPresented: Bool = false
    @State private var isSettingsViewPresented: Bool = false
    @State private var bearWithInsufficientFunds: String? = nil
    @ObservedObject private var viewModel = BearsViewModel()
    @ObservedObject private var pbillViewModel = PbillViewModel()

    init() {
        viewModel.listenForPBillsPurchase(pbillViewModel: pbillViewModel)
    }
    
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
                    
                    Spacer() // This spacer will ensure the two buttons are at opposite ends.
                    
                    // Add your new button here:
                    Button(action: {
                        self.isSettingsViewPresented = true
                    }) {
                        Image("Settings") // Replace with your button image name.
                            .resizable()
                            .frame(width: 40, height: 40)
                            .padding(.trailing, 20)
                            .padding(.top, 20)
                    }
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
                    .background(Color(hex: "#F5F5F5"))
                    .cornerRadius(5)
                }
                .padding(.top, 30)
                .padding([.leading, .trailing], 20)

                
                ScrollView {
                    Button(action: {
                        self.isMyBearsViewPresented = true
                    }) {
                        HStack {
                            Text("My Bears")
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: "#1199FF"))

                            Spacer()

                        }
                        .padding([.top, .bottom], 20)
                        .padding([.leading, .trailing], 20)
                    }
                    .background(Color(hex: "#F5F5F5"))
                    .cornerRadius(5)
                    .padding(.top, 15)
                    .padding([.leading, .trailing], 20)
                    
                    
                    HStack {
                        Text("Shop")
                            .font(.system(size: 24, weight: .bold, design: .default))
                            .foregroundColor(Color(hex: "#000"))
                            .padding(.leading, 20) // Add padding to the left side
                            .padding(.top, 40)
                        
                        Spacer() // This will push the Text view to the left
                    }
                    
                    VStack(spacing: 25) {
                        ForEach(viewModel.bears, id: \.id) { bear in
                            Button(action: {
                                if viewModel.ownedBears.contains(where: { $0.imageUrl == bear.imageUrl }) {
                                    // Do nothing if the bear is already owned
                                    return
                                }

                                if viewModel.pBills >= bear.price {
                                    viewModel.purchaseBear(bear)
                                    bearWithInsufficientFunds = nil  // Clear the ID when there's enough funds to purchase
                                } else {
                                    bearWithInsufficientFunds = bear.id  // Store the ID of the bear with insufficient funds
                                }
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
                                        
                                        if viewModel.ownedBears.contains(where: { $0.imageUrl == bear.imageUrl }) {
                                            Text("Purchased")
                                                .font(.system(size: 15, weight: .bold, design: .default))
                                                .foregroundColor(Color(hex: "#ababab"))
                                        } else if bearWithInsufficientFunds == bear.id {
                                            Text("Buy more P-Bills")
                                                .font(.system(size: 15, weight: .bold, design: .default))
                                                .foregroundColor(Color(hex: "#CC2255"))
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
            .onChange(of: pbillViewModel.purchaseCompleted) { completed in
                if completed {
                    isPbillViewPresented = false
                }
            }
            .fullScreenCover(isPresented: $isPbillViewPresented, content: {
                PbillView(viewModel: pbillViewModel)
            })
            .fullScreenCover(isPresented: $isMyBearsViewPresented, content: {
                MyBearsView()
            })
            .fullScreenCover(isPresented: $isSettingsViewPresented, content: {
                SettingsView()
            })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
