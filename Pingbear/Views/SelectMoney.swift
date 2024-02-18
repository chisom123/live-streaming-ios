import SwiftUI
import NotificationBannerSwift

struct SelectMoneyView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var navigatetopayview = false
    @State private var amount: String = ""
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image("Close") // Assuming "Close" is an SF Symbol. Replace with your image if different.
                        .resizable()
                        .frame(width: 40, height: 40)
                        .padding(.leading, 20)
                        .padding(.top, 20)
                }
                Spacer() // This spacer will ensure the button is at the leading edge.
            }
            
            Spacer() // Creates space between the close button and input fields
            
            VStack(spacing: 20) {
                Text("How much would you like to add to the prize pot?")
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.bottom, 40)
                    .padding(.horizontal)
                
                HStack { // Added HStack to align the pound sign and the TextField horizontally
                    Text("£") // Fixed £ symbol text
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundColor(Color(hex: "#000"))
                        .padding(.horizontal, 5)
                    
                    TextField("5", text: $amount)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(hex: "#F5F5F5"))
                        .foregroundColor(Color(hex: "#000"))
                        .cornerRadius(5)
                        .font(.system(size: 18, weight: .bold, design: .default))
                }
                
                Button(action: {
                    navigatetopayview = true
                }) {
                    Text("Continue")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(Color(hex: "#008000"))
                        .foregroundColor(Color(hex: "#fff"))
                        .cornerRadius(200)
                        .padding(.top, 20)
                }
            }
            .padding()
            
            Spacer() // Pushes everything to the top
        }
        .fullScreenCover(isPresented: $navigatetopayview) {
            PayView() // Replace this with the actual view you want to present
        }
    }
}
