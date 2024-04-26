import SwiftUI
import NotificationBannerSwift

struct PayView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: PbillViewModel
    
    var competitionId: String
    var entryDocId: String
    
    @State private var navigateToCompDetails = false // State to control navigation
    
    var competition: Competition

    
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
                    
                    (Text("With Superstar you will receive ")
                        + Text("three extra stars")
                            .foregroundColor(Color(hex: "#1199FF")) // Apply unique styling here
                        + Text(" every time your image is rated five stars."))
                        .font(.system(size: 18, weight: .bold, design: .default)) // Apply common styling here
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(.black) // This affects the entire Text view, might need adjustment if it overrides individual colors
                        .padding(.horizontal)
                        .padding(.horizontal)

                     
                    
                    Button(action: {
                        if let subscriptionProduct = viewModel.products.first(where: { $0.productIdentifier == "superstar" }) {
                            viewModel.purchase(product: subscriptionProduct)
                        }
                    }) {
                        Text("Activate Superstar!")
                    }
                    .buttonStyle(ChunkyButton())
                    .padding(.top, 50)
                    .padding(.horizontal)
                    .padding(.horizontal)
                    
                    Text("$0.99")
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(Color(hex: "#ababab"))
                        .padding(.top, 40)
                        .padding(.horizontal)
                    
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
                    navigateToCompDetails = true
                }
            }
            .fullScreenCover(isPresented: $navigateToCompDetails) {
                CompDetails(competition: competition) // Adjust according to your needs
            }
            .onAppear {
                viewModel.competitionId = self.competitionId
                viewModel.entryDocId = self.entryDocId
            }
        }
    }
 
    struct ChunkyButton: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    ZStack{
                        if #available(iOS 17.0, *) {
                            Capsule()
                                .fill(Color(hex: "#FFD700"))
                                .stroke(.black, lineWidth:3)
                                .offset(y:configuration.isPressed ? 0 : 10)
                        } else {
                            Capsule()
                                .fill(Color(hex: "#FFD700"))
                                .overlay(
                                    Capsule().stroke(Color.black, lineWidth: 3)
                                        .offset(y:configuration.isPressed ? 0 : 10)
                                )
                        }
                        
                        if #available(iOS 17.0, *) {
                            Capsule()
                                .fill(.white)
                                .stroke(.black, lineWidth:3)
                        } else {
                            Capsule()
                                .fill(Color.white)
                                .overlay(
                                    Capsule().stroke(Color.black, lineWidth: 3)
                                )
                        }
                    }
                )
                .offset(y:configuration.isPressed ? 10 : 0)
        }
    }
    
}
