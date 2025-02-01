import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import PostHog

struct ChangeNameView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var userName: String = ""
    @State private var updatedName: String = ""
    @State private var errorMessage: String?
    @State private var messageStatus: MessageStatus? = nil  // 1. Add an enum-based state for the message status
    @State private var isLoading: Bool = false

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
                        Image(systemName: "arrow.left")
                            .resizable() // Allows resizing of the image
                            .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                            .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                            .foregroundColor(Color.white) // Your desired color
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                Spacer()

                VStack {
                    Text("My Username")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(.white)
                        .padding(.vertical, 20)
                        .onAppear {
                            PostHogSDK.shared.capture("Change Name View Opened")
                        }
                    
                    TextField("Enter new username", text: $updatedName)
                        .padding()
                        .frame(height: 60)
                        .background(Color(hex: "#3B4374"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .padding(.horizontal)
                        .accentColor(.white)
                    
                    // Message Text
                    if let status = messageStatus {
                        switch status {
                        case .error:
                            Text(errorMessage ?? "An error occurred")
                                .foregroundColor(Color(hex: "#FF0000"))
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .multilineTextAlignment(.center)
                                .lineSpacing(10)
                                .padding(.top, 20)
                                .padding(.horizontal)
                            
                        case .success:
                            Text("Successfully Saved")
                                .foregroundColor(Color(hex: "#FFF"))
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .multilineTextAlignment(.center)
                                .lineSpacing(10)
                                .padding(.top, 20)
                                .padding(.horizontal)
                        case .none:
                            EmptyView()
                        }
                    }
                    
                    if isLoading {
                        ProgressView()
                            .padding(.vertical, 20)
                            .tint(.white)
                    } else {
                        Button(action: {
                            updateUserName()
                        }) {
                            Text("Save")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .font(.system(size: 18, weight: .bold, design: .default))
                                .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .background(Color(hex: "#FF4081"))
                                .foregroundColor(Color(hex: "#fff"))
                                .cornerRadius(200)
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color(hex: "#1A2245"))
                .cornerRadius(10)
                .padding(.horizontal, 20)

                Spacer()
            }
            .onAppear(perform: fetchUserName)  // <-- Here's the change
        }
        .background(Color(hex: "#10183C"))
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
        isLoading = true
        // Process and validate updated username
        let processedUsername = updatedName.lowercased().replacingOccurrences(of: " ", with: "")
        
        // Use the new validation function
        let validation = isValidUsername(processedUsername)
        guard validation.isValid else {
            messageStatus = .error
            errorMessage = validation.error
            isLoading = false
            return
        }

        guard let userId = userId else {
            isLoading = false
            return
        }
        let docRef = db.collection("users").document(userId)

        // Check if username already exists
        db.collection("users").whereField("username", isEqualTo: processedUsername).getDocuments { (querySnapshot, err) in
            if let err = err {
                self.messageStatus = .error
                self.errorMessage = "Error checking username: \(err.localizedDescription)"
                self.isLoading = false
            } else if querySnapshot!.documents.isEmpty || (querySnapshot!.documents.first?.documentID == userId) {
                // Username is either unique or belongs to the current user, proceed to update
                docRef.updateData([
                    "username": processedUsername
                ]) { err in
                    self.isLoading = false
                    if let err = err {
                        self.messageStatus = .error
                        self.errorMessage = "Error updating username: \(err.localizedDescription)"
                    } else {
                        self.messageStatus = .success
                        PostHogSDK.shared.capture("Username Updated")
                    }
                }
            } else {
                // Username already exists
                self.messageStatus = .error
                self.errorMessage = "This username is already taken"
                self.isLoading = false
            }
        }
    }
}
