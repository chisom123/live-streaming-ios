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
        updatedFullName != fullName || updatedName != userName
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "#10183C").ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: - Nav bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text("My Account")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(.white)
                        .padding(.horizontal)

                    Spacer()

                    // Balance spacer
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)

                // MARK: - Avatar
                VStack(spacing: 8) {
                    ProfilePictureView(
                        url: profileManager.currentProfileUrl ?? profilePictureUrl,
                        size: 84
                    )
                    .overlay(
                        ProfilePictureSelector(onUpdateSuccess: { newUrl in
                            profilePictureUrl = newUrl
                            Analytics.shared.track(
                                event: "profile_picture_updated",
                                properties: ["has_url": !newUrl.isEmpty]
                            )
                        })
                    )

                    Text("Tap to change photo")
                        .font(.system(size: 14, weight: .bold, design: .default))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                .padding(.bottom, 24)
                .padding(.top, 10)

                // MARK: - Form card
                ScrollView {
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 20) {

                            // Name field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Name")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.5))

                                TextField("Enter your name", text: $updatedFullName)
                                    .padding(.horizontal, 16)
                                    .frame(height: 58)
                                    .background(Color(hex: "#3B4374"))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .bold, design: .default))
                                    .accentColor(.white)
                                    .autocapitalization(.words)
                            }

                            // Username field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.5))

                                TextField("username", text: $updatedName)
                                    .padding(.horizontal, 16)
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .bold, design: .default))
                                    .accentColor(.white)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .frame(height: 58)
                                    .background(Color(hex: "#3B4374"))
                                    .cornerRadius(12)
                            }

                            // Hint / status
                            if let status = messageStatus {
                                switch status {
                                case .error:
                                    Text(errorMessage ?? "An error occurred")
                                        .foregroundColor(Color(hex: "#FF0000"))
                                        .font(.system(size: 16, weight: .bold, design: .default))

                                case .success:
                                    Text("Changes saved successfully")
                                        .foregroundColor(Color(hex: "#FFF"))
                                        .font(.system(size: 16, weight: .bold, design: .default))

                                case .none:
                                    EmptyView()
                                }
                            }
                        }
                        .padding(20)

                        // Bottom padding so content clears the sticky button
                        Spacer().frame(height: 100)
                    }
                }
            }
            
            Button(action: {
                saveChanges()
            }) {
                Text("Save Changes")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .background(hasChanges ? Color(hex: "#4169E1") : Color(hex: "#D3D3D3").opacity(0.2))
                    .foregroundColor(hasChanges ? Color(hex: "#FFF") : Color(hex: "#D3D3D3").opacity(0.2))
                    .cornerRadius(200)
            }
            .padding(.top, 10)
            .padding(.bottom, 10)
            .disabled(!hasChanges)
            .padding(.horizontal)
        }
        .background(Color(hex: "#10183C"))
        .onAppear {
            fetchUserData()
            Analytics.shared.trackScreen(name: "change_name")
        }
    }

    // MARK: - Data

    func fetchUserData() {
        guard let userId = userId else { return }
        db.collection("users").document(userId).getDocument { document, _ in
            guard let data = document?.data() else { return }
            self.userName = data["username"] as? String ?? ""
            self.updatedName = self.userName
            self.fullName = data["name"] as? String ?? ""
            self.updatedFullName = self.fullName
            self.profilePictureUrl = data["profilePictureUrl"] as? String ?? ""
        }
    }

    func saveChanges() {
        messageStatus = nil
        errorMessage = nil
        isLoading = true

        let processedName = String(updatedFullName.drop(while: { $0.isWhitespace }))

        guard !processedName.isEmpty else {
            showError("Please enter your name", event: "Name empty")
            return
        }

        guard processedName.count >= 2 else {
            showError("Name must be at least 2 characters", event: "Name too short")
            return
        }

        let processedUsername = updatedName.lowercased().replacingOccurrences(of: " ", with: "")
        let validation = isValidUsername(processedUsername)

        guard validation.isValid else {
            showError(validation.error ?? "Invalid username", event: validation.error ?? "Unknown")
            return
        }

        guard let userId = userId else { isLoading = false; return }

        if processedUsername != userName {
            db.collection("users")
                .whereField("username", isEqualTo: processedUsername)
                .getDocuments { snapshot, err in
                    if let err = err {
                        self.showError("Error checking username: \(err.localizedDescription)", event: err.localizedDescription)
                        Analytics.shared.trackError(message: err.localizedDescription, properties: ["context": "username_check"])
                    } else if snapshot!.documents.isEmpty || snapshot!.documents.first?.documentID == userId {
                        self.updateFirestore(name: processedName, username: processedUsername)
                    } else {
                        self.showError("This username is already taken", event: "already_taken")
                        Analytics.shared.track(event: "username_update_failed", properties: ["reason": "already_taken"])
                    }
                }
        } else {
            updateFirestore(name: processedName, username: processedUsername)
        }
    }

    func updateFirestore(name: String, username: String) {
        guard let userId = userId else { isLoading = false; return }

        let nameChanged = name != self.fullName
        let usernameChanged = username != self.userName

        db.collection("users").document(userId).updateData([
            "name": name,
            "username": username
        ]) { err in
            self.isLoading = false
            if let err = err {
                self.messageStatus = .error
                self.errorMessage = "Error saving changes: \(err.localizedDescription)"
                Analytics.shared.trackError(message: err.localizedDescription, properties: ["context": "save_changes"])
            } else {
                self.messageStatus = .success
                self.fullName = name
                self.updatedFullName = name
                self.userName = username
                self.updatedName = username
                hideKeyboard()
                Analytics.shared.track(
                    event: "profile_updated",
                    properties: ["name_changed": nameChanged, "username_changed": usernameChanged]
                )
            }
        }
    }

    // MARK: - Helpers

    private func showError(_ message: String, event: String) {
        messageStatus = .error
        errorMessage = message
        isLoading = false
        Analytics.shared.track(
            event: "validation_failed",
            properties: ["error": event]
        )
    }
}
