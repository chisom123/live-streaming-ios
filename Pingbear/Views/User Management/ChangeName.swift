import SwiftUI
import Firebase
import FirebaseFirestore

struct ChangeNameView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var userName: String = ""
    @State private var updatedName: String = ""
    @State private var errorMessage: String?
    @State private var messageStatus: MessageStatus? = nil  // 1. Add an enum-based state for the message status

    let db = Firestore.firestore()
    let userId = Auth.auth().currentUser?.uid

    enum MessageStatus {
        case error, success, none
    }

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
                
                Spacer()

                Text("My Username")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.bottom, 40)
                    .padding(.horizontal)
                
                TextField("Enter new username", text: $updatedName)
                    .padding()
                    .background(Color(hex: "#F5F5F5"))
                    .foregroundColor(Color(hex: "#000"))
                    .cornerRadius(5)
                    .font(.system(size: 16, weight: .bold, design: .default))
                    .padding(.horizontal)
                
                // Message Text
                if let status = messageStatus {
                    switch status {
                    case .error:
                        Text(errorMessage ?? "An error occurred")
                            .foregroundColor(Color(hex: "#CC2255"))
                            .font(.system(size: 15, weight: .bold, design: .default))
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .padding(.bottom, 5)
                            .padding(.top, 20)
                            .padding(.horizontal)
                        
                    case .success:
                        Text("Successfully Saved")
                            .foregroundColor(Color(hex: "#556B2F"))
                            .font(.system(size: 15, weight: .bold, design: .default))
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .padding(.bottom, 5)
                            .padding(.top, 20)
                            .padding(.horizontal)
                    case .none:
                        EmptyView()
                    }
                }
                
                Button(action: {
                    updateUserName()
                }) {
                    Text("Save")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(Color(hex: "#1199FF"))
                        .foregroundColor(Color(hex: "#fff"))
                        .cornerRadius(200)
                }
                .padding(.top, 20)
                .padding(.horizontal)

                Spacer()
            }
            .onAppear(perform: fetchUserName)  // <-- Here's the change
        }
        Spacer()
    }

    func fetchUserName() {
        guard let userId = userId else { return }
        let docRef = db.collection("users").document(userId)

        docRef.getDocument { (document, error) in
            if let document = document, document.exists, let username = document.data()?["username"] as? String {
                self.userName = username
                self.updatedName = username
            } else {
                print("Document does not exist or username not found")
            }
        }
    }
    
    func updateUserName() {
        // Process and validate updated username
        let processedUsername = updatedName.lowercased().replacingOccurrences(of: " ", with: "")
        
        // Use the new validation function
        let validation = isValidUsername(processedUsername)
        guard validation.isValid else {
            messageStatus = .error
            errorMessage = validation.error
            return
        }

        guard let userId = userId else { return }
        let docRef = db.collection("users").document(userId)

        // Check if username already exists
        db.collection("users").whereField("username", isEqualTo: processedUsername).getDocuments { (querySnapshot, err) in
            if let err = err {
                self.messageStatus = .error
                self.errorMessage = "Error checking username: \(err.localizedDescription)"
            } else if querySnapshot!.documents.isEmpty || (querySnapshot!.documents.first?.documentID == userId) {
                // Username is either unique or belongs to the current user, proceed to update
                docRef.updateData([
                    "username": processedUsername
                ]) { err in
                    if let err = err {
                        self.messageStatus = .error
                        self.errorMessage = "Error updating username: \(err.localizedDescription)"
                    } else {
                        self.messageStatus = .success
                    }
                }
            } else {
                // Username already exists
                self.messageStatus = .error
                self.errorMessage = "This username is already taken"
            }
        }
    }
}
