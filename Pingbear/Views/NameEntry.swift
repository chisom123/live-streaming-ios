import SwiftUI
import Firebase
import FirebaseFirestore

struct NameEntryView: View {
    let phoneNumber: String
    @State private var name: String = ""
    @State private var errorMessage: String? = nil
    @State private var navigateToHome = false

    var body: some View {
        VStack(spacing: 20) {
            TextField("Enter your name", text: $name)
                .padding()
                .border(Color.gray, width: 0.5)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
            
            Button("Save Name") {
                self.saveNameToFirestore()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            NavigationLink(destination: HomeView(), isActive: $navigateToHome) {
                EmptyView()
            }.isDetailLink(false) // To avoid any potential navigation issues

        }
        .padding()
    }

    func saveNameToFirestore() {
        guard let userID = Auth.auth().currentUser?.uid else {
            errorMessage = "Error fetching user"
            return
        }
        
        let db = Firestore.firestore()
        
        db.collection("users").document(userID).setData([
            "name": name,
            "phoneNumber": phoneNumber
        ]) { error in
            if let error = error {
                self.errorMessage = "Error saving user: \(error.localizedDescription)"
            } else {
                self.navigateToHome = true
            }
        }
    }
}
