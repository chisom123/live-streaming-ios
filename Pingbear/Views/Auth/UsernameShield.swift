import SwiftUI
import Firebase
import FirebaseFirestore

struct UsernameShieldView: View {
    
    @State private var userCode: String = ""
    @State private var errorMessage: String = ""
    @State private var navigateToHome = false
    @State private var listenerRegistration: ListenerRegistration?

    var body: some View {
        VStack {
            Spacer()
            
            Text("You need a code to access Pingbear")
                .font(.system(size: 20, weight: .bold, design: .default)) // Apply common styling here
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(.black) // This affects the entire Text view, might need adjustment if it overrides individual colors
                .padding(.horizontal)
            
            ChunkyTextField("Enter Code", text: $userCode)
                .padding(.horizontal)
                .padding(.horizontal)
                .padding(.top, 10)
            
            Button(action: {
                generateCode()
            }) {
                Text("Create a new code")
                    .underline()
            }
            .font(.system(size: 20, weight: .bold, design: .default))
            .foregroundColor(.blue)
            .padding(.top, 50)
            
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
            
//            Button("Access Pingbear!") {
//                validateEnteredCode()
//            }
//            .padding(.top, 50)
//            .padding(.horizontal)
//            .padding(.horizontal)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensures VStack fills all available space
        .background(Color(hex: "00BFFF")) // Applies background to the expanded VStack
        .fullScreenCover(isPresented: $navigateToHome) {
            ContentView()
        }
        .onAppear {
            setupListener()
        }
        .onDisappear {
            removeListener()
        }
    }
    
    private func setupListener() {
        let userId = Auth.auth().currentUser?.uid ?? ""
        guard !userId.isEmpty else { return }
        
        let db = Firestore.firestore()
        listenerRegistration = db.collection("users").document(userId)
            .addSnapshotListener { documentSnapshot, error in
                if let document = documentSnapshot, document.exists {
                    let allowIn = document.get("allow_in") as? Bool ?? false
                    if allowIn {
                        navigateToHome = true
                    }
                } else if let error = error {
                    errorMessage = "Error listening to user changes: \(error.localizedDescription)"
                }
            }
    }
    
    private func removeListener() {
        listenerRegistration?.remove()
    }
    
    private func generateCode() {
        let newCode = generateRandomCode()
        let userId = Auth.auth().currentUser?.uid ?? ""
        
        let db = Firestore.firestore()
        db.collection("codes").document(newCode).setData(["active_users": [userId]]) { error in
            if let error = error {
                errorMessage = "Failed to save code: \(error.localizedDescription)"
            } else {
                userCode = newCode
                setupListener()
            }
        }
    }
    
    private func validateEnteredCode() {
        let userId = Auth.auth().currentUser?.uid ?? ""
        let db = Firestore.firestore()
        let codeDocument = db.collection("codes").document(userCode)

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let codeDocumentSnapshot: DocumentSnapshot
            do {
                try codeDocumentSnapshot = transaction.getDocument(codeDocument)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard let activeUsers = codeDocumentSnapshot.data()?["active_users"] as? [String] else {
                errorMessage = "Invalid code."
                return nil
            }

            if !activeUsers.contains(userId) {
                var updatedUsers = activeUsers
                updatedUsers.append(userId)
                transaction.updateData(["active_users": updatedUsers], forDocument: codeDocument)

                // Check if this is the second user
                if updatedUsers.count == 2 {
                    for user in updatedUsers {
                        let userDoc = db.collection("users").document(user)
                        transaction.updateData(["allow_in": true], forDocument: userDoc)
                    }
                }
            } else {
                errorMessage = "This code has already been used by you."
            }

            return nil
        }) { (object, error) in
            if let error = error {
                errorMessage = "Transaction failed: \(error.localizedDescription)"
            } else {
                navigateToHome = true
                
                let db = Firestore.firestore()
                db.collection("codes").document(userCode).delete() { error in
                    if let error = error {
                        // Handle deletion error if necessary
                        print("Error deleting code: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    
    private func generateRandomCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).compactMap { _ in characters.randomElement() })
    }
    
    
    struct ChunkyTextField: View {
        @Binding var text: String
        private var placeholder: String

        init(_ placeholder: String, text: Binding<String>) {
            self._text = text
            self.placeholder = placeholder
        }

        var body: some View {
            TextField(placeholder, text: $text)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    ZStack {
                        if #available(iOS 17.0, *) {
                            Capsule()
                                .fill(.blue)
                                .stroke(.black, lineWidth:3)
                                .offset(y: 10)
                        } else {
                            Capsule()
                                .fill(Color.blue)
                                .overlay(
                                    Capsule().stroke(Color.black, lineWidth: 3)
                                        .offset(y: 10)
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
                .offset(y: 10)
                .padding(.vertical, 10)
        }
    }
}
