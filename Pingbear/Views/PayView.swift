import SwiftUI

struct PayView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var cardNumber: String = ""
    @State private var expiryDate: String = ""
    @State private var cvv: String = ""
    
    @ObservedObject var viewModel = PaymentViewModel(clientID: "AWi9TmUagirOf6ev1JOMu4qPJO5N0GaFz24a2XvO1s_i17ipombKODIwNvs0yr3wPIu0Zt3rfuhS57mS")

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
                Text("Enter your payment details")
                    .font(.system(size: 19, weight: .semibold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.bottom, 20)
                
                TextField("Card Number", text: $cardNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                
                HStack {
                    TextField("MM/YY", text: $expiryDate)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .frame(maxWidth: .infinity)
                    
                    TextField("CVV", text: $cvv)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .frame(maxWidth: .infinity)
                }
                
                Button(action: {
                    viewModel.processPayment(cardNumber: cardNumber, expiryDate: expiryDate, cvv: cvv)
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
    }
}
