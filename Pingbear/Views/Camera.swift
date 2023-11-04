import SwiftUI
import AVFoundation


struct CameraView: View {
    
    var body: some View {
        ZStack {
            HStack {
                Button(action: {
                    
                }) {
                    Image("Close")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .padding(.leading, 20)
                        .padding(.top, 20)
                }
                
                Spacer() // This spacer will ensure the two buttons are at opposite ends.
            }
        }
    }
    
}
