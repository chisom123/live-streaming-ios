import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import CryptoKit

struct NameEntryView: View {
    let phoneNumber: String
    let fullName: String
    @State private var username: String = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var navigateToWelcomeBonus = false

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()
            VStack {
                Spacer()
                VStack {
                    Text("Create a username")
                        .font(.system(size: 18, weight: .bold))
                        .multilineTextAlignment(.center).foregroundColor(AppTheme.primaryText)
                        .padding(.top, 20).padding(.bottom, 25)
                        .onAppear { Analytics.shared.trackScreen(name: "username_entry") }

                    TextField("Enter your username", text: $username)
                        .padding().frame(height: 60)
                        .background(AppTheme.inputBackground.clipShape(RoundedRectangle(cornerRadius: 10)))
                        .foregroundColor(AppTheme.primaryText)
                        .font(.system(size: 16, weight: .bold)).autocapitalization(.none)
                        .tint(AppTheme.accent)

                    if let error = errorMessage {
                        Text(error).foregroundColor(.red).font(.system(size: 16, weight: .bold))
                            .multilineTextAlignment(.center).padding(.top, 20).padding(.horizontal)
                    }

                    if isLoading {
                        ProgressView().padding(.vertical, 20).tint(AppTheme.primaryText)
                    } else {
                        Button(action: { self.hideKeyboard(); self.checkUsernameAndSave() }) {
                            Text("Continue").frame(maxWidth: .infinity, minHeight: 44)
                                .font(.system(size: 18, weight: .bold))
                                .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .background(AppTheme.accent).foregroundColor(.white).cornerRadius(200)
                        }
                        .padding(.vertical, 20)
                    }
                }
                .frame(maxWidth: .infinity).padding(20)
                .background(AppTheme.cardBackground).cornerRadius(10).padding(.horizontal, 20)

                NavigationLink(destination: WelcomeBonusView(), isActive: $navigateToWelcomeBonus) { EmptyView() }.isDetailLink(false)
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Validate username

    func checkUsernameAndSave() {
        isLoading = true
        let processedUsername = username.lowercased().replacingOccurrences(of: " ", with: "")

        let validation = isValidUsername(processedUsername)
        guard validation.isValid else {
            errorMessage = validation.error
            isLoading = false
            return
        }

        let db = Firestore.firestore()
        db.collection("users").whereField("username", isEqualTo: processedUsername).getDocuments { snapshot, error in
            if let error {
                self.isLoading = false
                self.errorMessage = "Error checking username: \(error.localizedDescription)"
                return
            }
            guard snapshot?.documents.isEmpty == true else {
                self.isLoading = false
                self.errorMessage = "This username is already taken"
                return
            }
            self.saveUser(username: processedUsername)
        }
    }

    // MARK: - Save user

    func saveUser(username: String) {
        guard let user = Auth.auth().currentUser else {
            isLoading = false
            errorMessage = "Error fetching user ID"
            return
        }

        let userID      = user.uid
        let db          = Firestore.firestore()
        let hashedPhone = hashPhoneNumber(phoneNumber)

        db.collection("users").document(userID).setData([
            "username":        username,
            "phoneNumberHash": hashedPhone,
            "name":            fullName,
            "userId":          userID,
            "createdAt":       FieldValue.serverTimestamp(),
            "lastActiveAt":    FieldValue.serverTimestamp()
        ], merge: true) { error in
            if let error {
                self.isLoading = false
                self.errorMessage = "Error saving user: \(error.localizedDescription)"
                return
            }

            Analytics.shared.track(
                event: "new_user_created",
                properties: ["user_id": userID, "username": username]
            )

            // Resolve any invite groups — non-fatal, never blocks signup
            self.resolveInviteGroups(userId: userID, phoneHash: hashedPhone, db: db) {
                user.getIDTokenForcingRefresh(true) { _, _ in
                    Functions.functions().httpsCallable("creditWelcomeBonus").call([:]) { _, error in
                        DispatchQueue.main.async {
                            self.isLoading = false
                            if let error {
                                print("creditWelcomeBonus failed: \(error.localizedDescription)")
                            }
                            self.navigateToWelcomeBonus = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Resolve invite groups

    /// Finds any invite_groups containing this user's phoneHash.
    /// For each group:
    ///   1. Creates mutual friendships with all members who already have a userId
    ///   2. Adds this user's userId to the group's memberUserIds map
    ///      so future signups from the same group connect to them too.
    private func resolveInviteGroups(userId: String, phoneHash: String, db: Firestore, completion: @escaping () -> Void) {
        db.collection("invite_groups")
            .whereField("memberHashes", arrayContains: phoneHash)
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents, !docs.isEmpty else {
                    completion(); return
                }

                let group = DispatchGroup()

                for doc in docs {
                    group.enter()
                    let data           = doc.data()
                    let memberUserIds  = data["memberUserIds"] as? [String: String] ?? [:]

                    // Collect all existing userIds except our own
                    let existingUserIds = memberUserIds.values.filter { $0 != userId }

                    db.runTransaction({ transaction, errorPointer -> Any? in
                        // 1. Create mutual friendships with everyone already in the group
                        for existingUserId in existingUserIds {
                            let newUserFriendRef = db.collection("users").document(userId)
                                .collection("friends").document(existingUserId)
                            let existingUserFriendRef = db.collection("users").document(existingUserId)
                                .collection("friends").document(userId)

                            transaction.setData(["uid": existingUserId], forDocument: newUserFriendRef)
                            transaction.setData(["uid": userId], forDocument: existingUserFriendRef)
                        }

                        // 2. Add this user to the group's memberUserIds map
                        transaction.updateData(
                            ["memberUserIds.\(phoneHash)": userId],
                            forDocument: doc.reference
                        )

                        return nil
                    }) { _, error in
                        if let error = error {
                            print("resolveInviteGroups transaction error: \(error.localizedDescription)")
                        } else {
                            Analytics.shared.track(
                                event: "invite_group_resolved",
                                properties: ["friends_added": existingUserIds.count]
                            )
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) { completion() }
            }
    }

    // MARK: - Hash phone number

    func hashPhoneNumber(_ phoneNumber: String) -> String {
        let cleaned = phoneNumber
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        let salt = "5Ax1HpaMDwxIv15M6t4ZdGuC8"
        let hash = SHA256.hash(data: Data((salt + cleaned).utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
