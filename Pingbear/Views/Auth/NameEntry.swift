import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import CryptoKit

struct NameEntryView: View {
    let phoneNumber: String
    let fullName:    String

    @State private var username:         String  = ""
    @State private var errorMessage:     String? = nil
    @State private var isLoading:        Bool    = false
    @State private var showWelcomeBonus: Bool    = false
    @State private var hadInviteGroups:  Bool    = false

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

                NavigationLink(
                    destination: WelcomeBonusView(hadInviteGroups: hadInviteGroups),
                    isActive: $showWelcomeBonus
                ) { EmptyView() }
                    .isDetailLink(false)

                Spacer()
            }
        }
        .navigationBarHidden(true)
    }

    func checkUsernameAndSave() {
        isLoading = true
        let processed  = username.lowercased().replacingOccurrences(of: " ", with: "")
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

    func saveUser(username: String) {
        guard let user = Auth.auth().currentUser else {
            isLoading    = false
            errorMessage = "Error fetching user ID"
            return
        }
        let userID      = user.uid
        let db          = Firestore.firestore()
        let hashedPhone = hashPhoneNumber(phoneNumber)

        var userData: [String: Any] = [
            "username":        username,
            "phoneNumberHash": hashedPhone,
            "name":            fullName,
            "userId":          userID,
            "totalEarned":     0,
            "createdAt":       FieldValue.serverTimestamp()
        ]

        #if !targetEnvironment(simulator)
        if let voipToken = UserDefaults.standard.string(forKey: "pendingVoIPToken") {
            userData["voipToken"] = voipToken
        }
        #endif

        db.collection("users").document(userID).setData(userData, merge: true) { error in
            if let error {
                self.isLoading    = false
                self.errorMessage = "Error saving user: \(error.localizedDescription)"
                return
            }
            UserDefaults.standard.removeObject(forKey: "pendingVoIPToken")
            Analytics.shared.track(
                event: AnalyticsEvent.accountCreated,
                properties: ["user_id": userID, "username": username]
            )
            self.resolveInviteGroups(userId: userID, phoneHash: hashedPhone, db: db) { hadInvites, friendIds in
                // Fire and forget — navigation doesn't wait for this
                if !friendIds.isEmpty {
                    Functions.functions().httpsCallable("notifyFriendJoined").call([
                        "friendUserIds": friendIds
                    ]) { _, error in
                        if let error {
                            print("notifyFriendJoined error: \(error.localizedDescription)")
                        }
                    }
                }
                DispatchQueue.main.async {
                    self.hadInviteGroups  = hadInvites
                    self.isLoading        = false
                    self.showWelcomeBonus = true
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - resolveInviteGroups
    //
    // Finds all invite_groups containing the new user's phone hash,
    // adds mutual friendships for every existing member, and returns
    // the resolved friend IDs so the caller can notify them.
    //
    // Friend IDs are read from inside the transaction (not from the
    // outer getDocuments snapshot) so we always act on the freshest
    // memberUserIds state — safe even when multiple invitees sign up
    // concurrently against the same invite_group document.
    // ─────────────────────────────────────────────────────────

    private func resolveInviteGroups(
        userId:     String,
        phoneHash:  String,
        db:         Firestore,
        completion: @escaping (Bool, [String]) -> Void
    ) {
        db.collection("invite_groups")
            .whereField("memberHashes", arrayContains: phoneHash)
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents, !docs.isEmpty else {
                    completion(false, []); return
                }

                var allFriendIds: [String] = []
                let group = DispatchGroup()

                for doc in docs {
                    group.enter()

                    // stream_id is read from the outer snapshot — it never
                    // changes after the doc is created so this is fine.
                    let streamId = doc.data()["stream_id"] as? String

                    db.runTransaction({ transaction, _ -> Any? in
                        // Read fresh inside the transaction so concurrent
                        // sign-ups don't race on a stale memberUserIds map.
                        let freshDoc           = try? transaction.getDocument(doc.reference)
                        let freshMemberUserIds = freshDoc?.data()?["memberUserIds"] as? [String: String] ?? [:]
                        let freshExistingIds   = freshMemberUserIds.values.filter { $0 != userId }

                        for existingUserId in freshExistingIds {
                            let newUserFriendRef = db
                                .collection("users").document(userId)
                                .collection("friends").document(existingUserId)
                            let existingUserFriendRef = db
                                .collection("users").document(existingUserId)
                                .collection("friends").document(userId)
                            transaction.setData(["uid": existingUserId], forDocument: newUserFriendRef)
                            transaction.setData(["uid": userId],         forDocument: existingUserFriendRef)
                        }

                        transaction.updateData(
                            ["memberUserIds.\(phoneHash)": userId],
                            forDocument: doc.reference
                        )

                        // Return the IDs so the completion block can use them
                        // without a second read.
                        return Array(freshExistingIds)

                    }) { result, error in
                        if let error {
                            print("resolveInviteGroups error: \(error.localizedDescription)")
                        } else {
                            let resolvedIds = result as? [String] ?? []
                            allFriendIds.append(contentsOf: resolvedIds)
                            Analytics.shared.track(
                                event: AnalyticsEvent.inviteGroupResolved,
                                properties: ["friends_added": resolvedIds.count]
                            )
                        }

                        if let streamId {
                            Functions.functions().httpsCallable("resolveInviteStream").call([
                                "streamId": streamId
                            ]) { _, error in
                                if let error {
                                    print("resolveInviteStream error for \(streamId): \(error.localizedDescription)")
                                }
                            }
                        }

                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    // Deduplicate in case the user appeared in multiple
                    // invite_group docs (e.g. invited twice by different people).
                    completion(true, Array(Set(allFriendIds)))
                }
            }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────────────────────────

    func hashPhoneNumber(_ phoneNumber: String) -> String {
        let cleaned = phoneNumber
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        let salt = "5Ax1HpaMDwxIv15M6t4ZdGuC8"
        let hash = SHA256.hash(data: Data((salt + cleaned).utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
