import SwiftUI

struct LocationCheckView: View {
    @State private var navigateToNextView = false
    @State private var navigateBack = false
    @EnvironmentObject var sharedViewModel: SharedViewModel

    var competition: Competition // Add this line
    
    var body: some View {
        VStack {
            HStack {
                
                Spacer()
                
                Button("Skip") {
                    navigateBack = true
                }
                .font(.system(size: 15.5, weight: .bold, design: .default))
                .foregroundColor(.gray)
                .padding()
            }
            
            Spacer()
            
            HStack {
                Image(systemName: "star")
            }
            .font(.system(size: 30, weight: .bold, design: .default))
            .foregroundColor(Color(hex: "#DAA520"))
            .padding()
            .background(Circle()
                .stroke(Color(hex: "#DAA520"), lineWidth: 3.5)
            )
            .padding(.horizontal)
            
            Text("Access the power of Superstar")
                .font(.system(size: 22, weight: .bold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(Color(hex: "#DAA520"))
                .padding(.bottom, 30)
                .padding(.top, 30)
                .padding(.horizontal)
            
            Text("I'm baby jianbing sartorial mlkshk vexillologist. Lomo small batch jean shorts, readymade migas squid paleo next level tumeric chicharrones fashion axe man bun.")
                .font(.system(size: 17, weight: .semibold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(.black)
                .padding(.bottom, 10)
            
            
            Button(action: {
                navigateToNextView = true
            }) {
                Text("Continue")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .background(Color(hex: "#DAA520"))
                    .foregroundColor(Color(hex: "#fff"))
                    .cornerRadius(200)
            }
            .padding(.top, 30)
            
            Spacer()
            
        }
        .fullScreenCover(isPresented: $navigateToNextView) {
            PayView(viewModel: PbillViewModel()) // Replace this with the actual view you want to present
        }
        .fullScreenCover(isPresented: $navigateBack) {
            CompDetails(competition: competition, fromLocationCheckView: true) // Pass the competition to the CompDetails view
        }
        .padding()
    }
}
