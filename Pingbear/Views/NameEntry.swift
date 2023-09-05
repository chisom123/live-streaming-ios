import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct NameEntryView: View {
    let phoneNumber: String
    @State private var name: String = ""
    @State private var errorMessage: String? = nil
    @State private var navigateToHome = false

    func normalizePhoneNumber(_ number: String) -> String {
        return number.filter { $0.isNumber }
    }
    
    func isValidName(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty
    }

    var body: some View {
        VStack {
            Text("Enter your name")
                .font(.system(size: 18, weight: .semibold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(.black)
                .padding(.bottom, 40)
                .padding(.horizontal)
            
            TextField("Enter your name", text: $name)
                .padding()
                .background(Color(hex: "#F5F5F5"))
                .foregroundColor(Color(hex: "#000"))
                .cornerRadius(5)
                .font(.system(size: 16, weight: .medium, design: .default))
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(Color(hex: "#CC2255"))
                    .font(.system(size: 15, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .padding(.bottom, 10)
                    .padding(.top, 20)
                    .padding(.horizontal)
            }
            
            Button(action: {
                self.saveNameToFirestore()
            }) {
                Text("Continue")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .background(Color(hex: "#1199FF"))
                    .foregroundColor(Color(hex: "#fff"))
                    .cornerRadius(200)
            }
            .padding(.top, 20)

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

        // Validate the name
        guard isValidName(name) else {
            errorMessage = "Please enter your name"
            return
        }

        let db = Firestore.firestore()
        let normalizedPhoneNumber = normalizePhoneNumber(phoneNumber)
        
        db.collection("users").document(userID).setData([
            "name": name,
            "phoneNumber": normalizedPhoneNumber
        ], merge: true) { error in
            if let error = error {
                self.errorMessage = "Error saving user: \(error.localizedDescription)"
            } else {
                self.navigateToHome = true
            }
        }
    }

}
