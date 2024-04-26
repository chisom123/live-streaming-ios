import SwiftUI

struct LocationCheckView: View {
    @State private var navigateToNextView = false
    @State private var navigateBack = false
    @State private var rotateAngle: Double = 0

    var competition: Competition // Add this line
    
    var competitionId: String // Add this line to hold the competition ID
    var entryDocId: String // Add this line to hold the entry document ID
    
    var body: some View {
        VStack {
            HStack {
                
                Spacer()
                
                Button("Skip") {
                    navigateBack = true
                }
                .font(.system(size: 15.5, weight: .bold, design: .default))
                .foregroundColor(.black)
                .padding()
            }
            
            Spacer()
            
            ZStack {
                // Star with rotation animation
                Image(systemName: "star.fill")
                    .font(.system(size: 55, weight: .bold, design: .default))
                    .foregroundColor(Color(hex: "#FF4500"))
                    .rotationEffect(.degrees(rotateAngle))
                    .onAppear {
                        withAnimation(Animation.linear(duration: 5).repeatForever(autoreverses: false)) {
                            rotateAngle = 360
                        }
                    }
            }
            .padding()
            
            
            Button(action: {
                navigateToNextView = true
            }) {
                Text("Activate Superstar!")
            }
            .buttonStyle(ChunkyButton())
            .padding(.top, 50)
            .padding(.horizontal)
            
            
            Spacer()
            
        }
        .fullScreenCover(isPresented: $navigateToNextView) {
            PayView(viewModel: PbillViewModel(), competitionId: competitionId, entryDocId: entryDocId, competition: competition) // Replace this with the actual view you want to present
        }
        .fullScreenCover(isPresented: $navigateBack) {
            CompDetails(competition: competition) // Pass the competition to the CompDetails view
        }
        .padding()
        .background(Color(hex: "#FFD700")) // Set the background color to gray
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
                                .fill(.blue)
                                .stroke(.black, lineWidth:3)
                                .offset(y:configuration.isPressed ? 0 : 10)
                        } else {
                            Capsule()
                                .fill(Color.blue)
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
