import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ChangeNameView: View {
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileManager = ProfilePictureManager.shared
    @State private var userName: String = ""
    @State private var fullName: String = ""
    @State private var profilePictureUrl: String = ""
    @State private var updatedName: String = ""
    @State private var updatedFullName: String = ""
    @State private var errorMessage: String?
    @State private var messageStatus: MessageStatus? = nil
    @State private var isLoading: Bool = false

    let db = Firestore.firestore()
    let userId = Auth.auth().currentUser?.uid

    enum MessageStatus {
        case error, success, none
    }
    
    var hasChanges: Bool {
        return updatedFullName != fullName || updatedName != userName
    }

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(Color.white)
                    }
                    
                    Spacer()
                    
                    Text("My Account")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(Color.white)
                    }
                    .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                Spacer()

                VStack {
                    HStack(spacing: 20) {
                        ProfilePictureView(url: profileManager.currentProfileUrl ?? profilePictureUrl, size: 90)
                        
                        ProfilePictureSelector(onUpdateSuccess: { newUrl in
                            profilePictureUrl = newUrl
                            Analytics.shared.track(
                                event: "profile_picture_updated",
                                properties: ["has_url": !newUrl.isEmpty]
                            )
                        })
                    }
                    .padding(.bottom, 20)
                    
                    Divider()
                    
                    // Name Section
                    HStack {
                        Text("My Name")
                            .font(.system(size: 17, weight: .bold, design: .default))
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                        
                        Spacer()
                    }
                    
                    TextField("Enter your name", text: $updatedFullName)
                        .padding()
                        .frame(height: 70)
                        .background(
                            Color(hex: "#3B4374")
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        )
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .accentColor(.white)
                        .autocapitalization(.words)
                        .padding(.bottom, 10)
                    
                    Divider()
                        .padding(.vertical, 10)
                    
                    // Username Section
                    HStack {
                        Text("My Username")
                            .font(.system(size: 17, weight: .bold, design: .default))
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .onAppear {
                                Analytics.shared.trackScreen(name: "change_name")
                            }
                        
                        Spacer()
                    }
                    
                    TextField("Enter new username", text: $updatedName)
                        .padding()
                        .frame(height: 70)
                        .background(
                            Color(hex: "#3B4374")
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        )
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .accentColor(.white)
                        .autocapitalization(.none)
                    
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
                    
                    // Shared Save Button
                    if isLoading {
                        ProgressView()
                            .padding(.vertical, 20)
                            .tint(.white)
                    } else {
                        Button(action: {
                            saveChanges()
                        }) {
                            Text("Save Changes")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .font(.system(size: 18, weight: .bold, design: .default))
                                .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .background(Color(hex: hasChanges ? "#4169E1" : "#323862"))
                                .foregroundColor(Color(hex: "#fff"))
                                .cornerRadius(200)
                        }
                        .disabled(!hasChanges)
                        .padding(.top, 20)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color(hex: "#1A2245"))
                .cornerRadius(10)
                .padding(.horizontal, 20)

                Spacer()
            }
            .onAppear(perform: fetchUserData)
        }
        .background(Color(hex: "#10183C"))
    }

    func fetchUserData() {
        guard let userId = userId else { return }
        let docRef = db.collection("users").document(userId)

        docRef.getDocument { (document, error) in
            if let document = document, document.exists {
                let data = document.data()
                self.userName = data?["username"] as? String ?? ""
                self.updatedName = self.userName
                self.fullName = data?["name"] as? String ?? ""
                self.updatedFullName = self.fullName
                self.profilePictureUrl = data?["profilePictureUrl"] as? String ?? ""
            } else {
                print("Document does not exist or data not found")
            }
        }
    }
    
    func saveChanges() {
        messageStatus = nil
        errorMessage = nil
        isLoading = true
        
        // Validate and process name
        let processedName = String(updatedFullName.drop(while: { $0.isWhitespace }))
        
        guard !processedName.isEmpty else {
            messageStatus = .error
            errorMessage = "Please enter your name"
            isLoading = false
            Analytics.shared.track(
                event: "name_validation_failed",
                properties: ["error": "Name empty"]
            )
            return
        }
        
        guard processedName.count >= 2 else {
            messageStatus = .error
            errorMessage = "Name must be at least 2 characters"
            isLoading = false
            Analytics.shared.track(
                event: "name_validation_failed",
                properties: ["error": "Name too short"]
            )
            return
        }
        
        // Validate and process username
        let processedUsername = updatedName.lowercased().replacingOccurrences(of: " ", with: "")
        
        let validation = isValidUsername(processedUsername)
        guard validation.isValid else {
            messageStatus = .error
            errorMessage = validation.error
            isLoading = false
            Analytics.shared.track(
                event: "username_validation_failed",
                properties: ["error": validation.error ?? "Unknown validation error"]
            )
            return
        }

        guard let userId = userId else {
            isLoading = false
            return
        }
        
        // Check if username is taken (only if username changed)
        if processedUsername != userName {
            db.collection("users").whereField("username", isEqualTo: processedUsername).getDocuments { (querySnapshot, err) in
                if let err = err {
                    self.messageStatus = .error
                    self.errorMessage = "Error checking username: \(err.localizedDescription)"
                    self.isLoading = false
                    Analytics.shared.trackError(
                        message: err.localizedDescription,
                        properties: ["context": "username_check"]
                    )
                } else if querySnapshot!.documents.isEmpty || (querySnapshot!.documents.first?.documentID == userId) {
                    // Username is available, proceed with update
                    self.updateFirestore(name: processedName, username: processedUsername)
                } else {
                    // Username already exists
                    self.messageStatus = .error
                    self.errorMessage = "This username is already taken"
                    self.isLoading = false
                    Analytics.shared.track(
                        event: "username_update_failed",
                        properties: ["reason": "already_taken"]
                    )
                }
            }
        } else {
            // Username didn't change, just update name
            updateFirestore(name: processedName, username: processedUsername)
        }
    }
    
    func updateFirestore(name: String, username: String) {
        guard let userId = userId else {
            isLoading = false
            return
        }
        
        let docRef = db.collection("users").document(userId)
        
        docRef.updateData([
            "name": name,
            "username": username
        ]) { err in
            self.isLoading = false
            if let err = err {
                self.messageStatus = .error
                self.errorMessage = "Error saving changes: \(err.localizedDescription)"
                Analytics.shared.trackError(
                    message: err.localizedDescription,
                    properties: ["context": "save_changes"]
                )
            } else {
                self.messageStatus = .success
                self.fullName = name
                self.updatedFullName = name
                self.userName = username
                self.updatedName = username
                hideKeyboard()
                Analytics.shared.track(
                    event: "profile_updated",
                    properties: [
                        "name_changed": name != self.fullName,
                        "username_changed": username != self.userName
                    ]
                )
            }
        }
    }
}
