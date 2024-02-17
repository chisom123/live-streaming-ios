import SwiftUI

struct PayView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
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
    }
}
