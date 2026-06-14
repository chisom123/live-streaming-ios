import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import CryptoKit

struct NameEntryView: View {
    let phoneNumber: String
    let fullName:    String

    @State private var username:      String  = ""
    @State private var errorMessage:  String? = nil
    @State private var isLoading:     Bool    = false

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()
            VStack {
                Spacer()
                VStack {
                    Text("Create a username")
                        .font(.system(size: 18, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppTheme.primaryText)
                        .padding(.top, 20)
                        .padding(.bottom, 25)
                        .onAppear { Analytics.shared.trackScreen(name: "username_entry") }

                    TextField("Enter your username", text: $username)
                        .padding()
                        .frame(height: 60)
                        .background(AppTheme.inputBackground.clipShape(RoundedRectangle(cornerRadius: 10)))
                        .foregroundColor(AppTheme.primaryText)
                        .font(.system(size: 16, weight: .bold))
                        .autocapitalization(.none)
                        .tint(AppTheme.accent)

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.system(size: 16, weight: .bold))
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)
                            .padding(.horizontal)
                    }

                    if isLoading {
                        ProgressView().padding(.vertical, 20).tint(AppTheme.primaryText)
                    } else {
                        Button(action: { hideKeyboard(); checkUsernameAndSave() }) {
                            Text("Continue")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .font(.system(size: 18, weight: .bold))
                                .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .background(AppTheme.accent)
                                .foregroundColor(.white)
                                .cornerRadius(200)
                        }
                        .padding(.vertical, 20)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(AppTheme.cardBackground)
                .cornerRadius(10)
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Validate username

    func checkUsernameAndSave() {
        isLoading = true
        let processed = username.lowercased().replacingOccurrences(of: " ", with: "")

        let validation = isValidUsername(processed)
        guard validation.isValid else {
            errorMessage = validation.error
            isLoading    = false
            return
        }

        let db = Firestore.firestore()
        db.collection("users").whereField("username", isEqualTo: processed).getDocuments { snapshot, error in
            if let error {
                self.isLoading    = false
                self.errorMessage = "Error checking username: \(error.localizedDescription)"
                return
            }
            guard snapshot?.documents.isEmpty == true else {
                self.isLoading    = false
                self.errorMessage = "This username is already taken"
                return
            }
            self.saveUser(username: processed)
        }
    }

    // MARK: - Save user

    func saveUser(username: String) {
        guard let user = Auth.auth().currentUser else {
            isLoading    = false
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
            "totalEarned":     0,
            "averageRating":   0,
            "ratingCount":     0,
            "createdAt":       FieldValue.serverTimestamp(),
            "lastActiveAt":    FieldValue.serverTimestamp()
        ], merge: true) { error in
            if let error {
                self.isLoading    = false
                self.errorMessage = "Error saving user: \(error.localizedDescription)"
                return
            }

            Analytics.shared.track(
                event: AnalyticsEvent.accountCreated,
                properties: ["user_id": userID, "username": username]
            )

            // Resolve invite groups — auto-friends + pending transactions
            self.resolveInviteGroups(userId: userID, phoneHash: hashedPhone, db: db) {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.goToHome()
                }
            }
        }
    }

    // MARK: - Go to home

    private func goToHome() {
        Analytics.shared.track(event: "onboarding_completed")
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        UserDefaults.standard.set(true, forKey: "isFriendActivated")
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .authStateDidChange, object: nil)
    }

    // MARK: - Resolve invite groups

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
                    let data            = doc.data()
                    let memberUserIds   = data["memberUserIds"] as? [String: String] ?? [:]
                    let pendingTxIds    = data["pendingTransactionIds"] as? [String] ?? []
                    let existingUserIds = memberUserIds.values.filter { $0 != userId }

                    db.runTransaction({ transaction, _ -> Any? in
                        // Mutual friendships
                        for existingUserId in existingUserIds {
                            let newUserFriendRef      = db.collection("users").document(userId).collection("friends").document(existingUserId)
                            let existingUserFriendRef = db.collection("users").document(existingUserId).collection("friends").document(userId)
                            transaction.setData(["uid": existingUserId], forDocument: newUserFriendRef)
                            transaction.setData(["uid": userId], forDocument: existingUserFriendRef)
                        }
                        // Add this user to memberUserIds
                        transaction.updateData(
                            ["memberUserIds.\(phoneHash)": userId],
                            forDocument: doc.reference
                        )
                        return nil
                    }) { _, error in
                        if let error {
                            print("resolveInviteGroups error: \(error.localizedDescription)")
                        } else {
                            Analytics.shared.track(
                                event: AnalyticsEvent.inviteGroupResolved,
                                properties: ["friends_added": existingUserIds.count]
                            )
                        }

                        // Resolve pending transactions
                        guard !pendingTxIds.isEmpty else { group.leave(); return }

                        let txGroup = DispatchGroup()
                        for txId in pendingTxIds {
                            txGroup.enter()
                            Functions.functions().httpsCallable("resolveInviteTransaction").call([
                                "transactionId": txId
                            ]) { _, error in
                                if let error {
                                    print("resolveInviteTransaction error for \(txId): \(error.localizedDescription)")
                                }
                                txGroup.leave()
                            }
                        }
                        txGroup.notify(queue: .main) { group.leave() }
                    }
                }

                group.notify(queue: .main) { completion() }
            }
    }

    // MARK: - Helpers

    func hashPhoneNumber(_ phoneNumber: String) -> String {
        let cleaned = phoneNumber
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        let salt = "5Ax1HpaMDwxIv15M6t4ZdGuC8"
        let hash = SHA256.hash(data: Data((salt + cleaned).utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
