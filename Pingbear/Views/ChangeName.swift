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

                Text("My Name")
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.bottom, 40)
                    .padding(.top, 30)
                    .padding(.horizontal)
                
                TextField("My Name", text: $updatedName)
                    .padding()
                    .background(Color(hex: "#F5F5F5"))
                    .foregroundColor(Color(hex: "#000"))
                    .cornerRadius(5)
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .padding(.horizontal)
                
                // Message Text
                if let status = messageStatus {
                    switch status {
                    case .error:
                        Text("Please enter your name")
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
    }

    func fetchUserName() {
        if let userId = userId {
            let docRef = db.collection("users").document(userId)

            docRef.getDocument { (document, error) in
                if let document = document, document.exists {
                    let data = document.data()
                    if let name = data?["name"] as? String {
                        self.userName = name
                        self.updatedName = name
                    }
                } else {
                    print("Document does not exist")
                }
            }
        }
    }
    
    func updateUserName() {
        if updatedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messageStatus = .error
            return
        }
        
        if let userId = userId {
            let docRef = db.collection("users").document(userId)

            docRef.updateData([
                "name": updatedName
            ]) { err in
                if let err = err {
                    messageStatus = .error
                } else {
                    messageStatus = .success
                }
            }
        }
    }
}
