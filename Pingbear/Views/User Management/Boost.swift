import SwiftUI
import Combine
import Firebase

struct BoostView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: BoostViewModel

    var body: some View {
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
                Spacer()
            }
            Spacer() // This Spacer pushes the remaining content to center vertically
            Text(viewModel.boostStatus)
                .font(.system(size: 25, weight: .bold, design: .default))
                .foregroundColor(.white)
                .padding() // Adds padding around the text.
                .padding(.horizontal, 20)
                .background(viewModel.isBoostActive ? Color.green : Color.red) // Adds background color with slight transparency.
                .cornerRadius(200) // Sets the corner radius.
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
            return "Boost Expired"
        }
        return expirationDate.timeIntervalSinceNow > 0 ? "Boost Active" : "Boost Expired"
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
