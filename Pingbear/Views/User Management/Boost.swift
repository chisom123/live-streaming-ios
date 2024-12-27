import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct BoostView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: BoostViewModel

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .resizable() // Allows resizing of the image
                        .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                        .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                        .foregroundColor(Color.black) // Your desired color
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            
            Spacer() // This Spacer pushes the remaining content to center vertically
            
            Text(viewModel.boostStatus)
                .font(.system(size: 25, weight: .bold, design: .default))
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(viewModel.isBoostActive ? Color.green : Color.red) // Adds background color with slight transparency.
                .cornerRadius(5) // Sets the corner radius.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Spacer() // This Spacer ensures the text stays centered even if the view resizes
        }
        .onAppear {
            viewModel.fetchBoostExpiration()
        }
    }
}

class BoostViewModel: ObservableObject {
    @Published var expirationDate: Date?
    var boostStatus: String {
        guard let expirationDate = expirationDate else {
            return "Boost Inactive"
        }
        return expirationDate.timeIntervalSinceNow > 0 ? "Boost Active" : "Boost Inactive"
    }
    
    var isBoostActive: Bool {
        if let expiration = expirationDate {
            return expiration.timeIntervalSinceNow > 0
        }
        return false
    }

    func fetchBoostExpiration() {
        let userID = Auth.auth().currentUser?.uid ?? ""
        let userDocRef = Firestore.firestore().collection("users").document(userID)
        userDocRef.getDocument { (document, error) in
            if let document = document, document.exists {
                if let timestamp = document.get("boost") as? Timestamp {
                    self.expirationDate = timestamp.dateValue()
                } else {
                    self.expirationDate = nil // Ensure the boost status updates if there is no valid boost
                }
            }
        }
    }
}
