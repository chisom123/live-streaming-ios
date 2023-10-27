import SwiftUI
import Firebase
import FirebaseFirestore
import UIKit

struct CompDetails: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var competitionDescription: String = ""
    
    var competition: CustomPointAnnotation // this holds the selected competition details

    
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
                }
    
                VStack {
                    // Updated to use 'competitionDescription'
                    Text(competition.competitionDescription)
                        .padding()
                }
                
                Spacer()
            }
        }
    }
}
