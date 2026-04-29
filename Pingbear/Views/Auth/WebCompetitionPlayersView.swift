// WebCompetitionPlayersView.swift
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import MessageUI

struct WebCompetitionPlayersView: View {
    let competitionId: String
    let competitionName: String
    let onContinue: () -> Void

    @StateObject private var addFriendsModel = AddFriendsModel()

    @State private var competitionMembers: [CompetitionMemberUser] = []
    @State private var membersListener: ListenerRegistration? = nil
    @State private var isLoadingMembers = true

    @State private var canContinue = false

    @State private var isShowingMessageComposer = false
    @State private var isShowingAddFriends = false

    private var currentUserId: String { Auth.auth().currentUser?.uid ?? "" }

    var body: some View {
        ZStack {
            Color(hex: "#10183C").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .opacity(0)

                    Spacer()

                    Text("Invite friends to play")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        isShowingAddFriends = true
                        Analytics.shared.trackTap(
                            elementId: "web_setup_add_friends",
                            screenName: "web_competition_players"
                        )
                    }) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 16) {

                        // ── Share link ───────────────────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(spacing: 0) {
                                Button(action: {
                                    isShowingMessageComposer = true
                                    Analytics.shared.trackTap(
                                        elementId: "web_setup_share_imessage",
                                        screenName: "web_competition_players"
                                    )
                                }) {
                                    HStack(spacing: 15) {
                                        Image(systemName: "message.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Color.green)
                                            .clipShape(Circle())

                                        Text("Share via iMessage")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundColor(Color(hex: "#D3D3D3"))
                                            .font(.system(size: 15, weight: .bold))
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                }

                                Divider().background(Color.white.opacity(0.2))

                                CopyLinkRow(competitionId: competitionId)
                            }
                            .background(Color(hex: "#1A2245"))
                            .cornerRadius(10)
                            .padding(.horizontal, 20)
                        }

                        // ── Live members ─────────────────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Players")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 20)

                            if isLoadingMembers {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(competitionMembers) { member in
                                        VStack(spacing: 0) {
                                            HStack {
                                                ProfilePictureView(url: member.profilePictureUrl, size: 40)
                                                    .padding(.leading, 20)

                                                Text(member.name)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .padding(.leading, 10)

                                                Spacer()

                                                if member.id == currentUserId {
                                                    Text("You")
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(.white.opacity(0.5))
                                                        .padding(.trailing, 20)
                                                }
                                            }
                                            .padding(.vertical, 16)

                                            if member.id != competitionMembers.last?.id {
                                                Divider().background(Color.white.opacity(0.2))
                                            }
                                        }
                                    }
                                }
                                .background(Color(hex: "#1A2245"))
                                .cornerRadius(10)
                                .padding(.horizontal, 20)
                            }
                        }

                        Color.clear.frame(height: 100)
                    }
                    .padding(.top, 8)
                }

                // ── Sticky continue button ───────────────────────────────
                VStack(spacing: 0) {
                    Divider().background(Color.white.opacity(0.06))

                    Button(action: {
                        Analytics.shared.trackTap(
                            elementId: "web_competition_players_continue",
                            screenName: "web_competition_players"
                        )
                        onContinue()
                    }) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(canContinue ? .white : .white.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(canContinue ? Color(hex: "#4169E1") : Color(hex: "#4169E1").opacity(0.3))
                            .cornerRadius(200)
                    }
                    .disabled(!canContinue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .animation(.easeInOut(duration: 0.3), value: canContinue)
                }
                .background(Color(hex: "#10183C"))
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $isShowingMessageComposer) {
            MessageComposer(
                message: "Hey I started a photo competition on SocialStar. Join it! \(DeepLinkHandler.shared.createShareableLink(for: competitionId))",
                isShowing: $isShowingMessageComposer
            )
        }
        .fullScreenCover(isPresented: $isShowingAddFriends) {
            AddFriendsView(addFriendsModel: addFriendsModel) { userId, userName in
                addMemberToCompetition(userId: userId, userName: userName) {}
            }
        }
        .onAppear {
            startMembersListener()
            Analytics.shared.trackScreen(name: "web_competition_players")
        }
        .onDisappear {
            membersListener?.remove()
        }
    }

    // MARK: - Members listener

    private func startMembersListener() {
        let db = Firestore.firestore()
        membersListener = db.collection("competitions")
            .document(competitionId)
            .collection("members")
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents, error == nil else { return }
                let ids = docs.compactMap { $0.data()["userId"] as? String }
                fetchMemberDetails(ids: ids)
                if docs.count >= 2 {
                    withAnimation { self.canContinue = true }
                }
            }
    }

    private func fetchMemberDetails(ids: [String]) {
        guard !ids.isEmpty else {
            DispatchQueue.main.async {
                self.competitionMembers = []
                self.isLoadingMembers = false
            }
            return
        }

        let db = Firestore.firestore()
        let group = DispatchGroup()
        var fetched: [CompetitionMemberUser] = []

        for id in ids {
            group.enter()
            db.collection("users").document(id).getDocument { doc, _ in
                defer { group.leave() }
                guard let data = doc?.data() else { return }
                let name = data["name"] as? String ?? "Unknown"
                let pic = data["profilePictureUrl"] as? String
                fetched.append(CompetitionMemberUser(id: id, name: name, profilePictureUrl: pic))
            }
        }

        group.notify(queue: .main) {
            self.competitionMembers = fetched.sorted { $0.id == self.currentUserId && $1.id != self.currentUserId }
            self.isLoadingMembers = false
        }
    }

    // MARK: - Write membership

    private func addMemberToCompetition(userId: String, userName: String, completion: @escaping () -> Void) {
        let db = Firestore.firestore()

        db.collection("competitions")
            .document(competitionId)
            .collection("members")
            .document(userId)
            .setData(["userId": userId, "coins": 1000]) { _ in
                db.collection("groupMemberships")
                    .document(userId)
                    .collection("competitions")
                    .document(self.competitionId)
                    .setData(["competitionId": self.competitionId]) { _ in

                        Analytics.shared.trackCompetition(
                            action: "join",
                            competitionId: self.competitionId,
                            properties: ["user_id": userId, "source": "web_setup"]
                        )

                        db.collection("users").document(self.currentUserId).getDocument { doc, _ in
                            let hostName = doc?.data()?["name"] as? String ?? "Someone"
                            NotificationQueueManager.shared.queueIndividualNotification(
                                to: userId,
                                title: self.competitionName,
                                body: "\(hostName) added you to the competition",
                                senderId: self.currentUserId
                            )
                            NotificationQueueManager.shared.processQueuedNotifications()
                            completion()
                        }
                    }
            }
    }

}

// MARK: - Sub views

struct CopyLinkRow: View {
    let competitionId: String
    @State private var copied = false

    var body: some View {
        Button(action: {
            let link = DeepLinkHandler.shared.createShareableLink(for: competitionId)
            UIPasteboard.general.string = link
            copied = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            Analytics.shared.trackTap(
                elementId: "web_setup_copy_link",
                screenName: "web_competition_players"
            )
        }) {
            HStack(spacing: 15) {
                Image(systemName: "doc.on.doc.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(copied ? Color(hex: "#25D366") : .white)
                    .padding(8)
                    .background(copied ? Color(hex: "#25D366").opacity(0.2) : Color.gray)
                    .clipShape(Circle())

                Text(copied ? "Link Copied" : "Copy Link")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if !copied {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(hex: "#D3D3D3"))
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .animation(.easeInOut(duration: 0.2), value: copied)
        }
    }
}

// MARK: - Model

struct CompetitionMemberUser: Identifiable {
    let id: String
    let name: String
    let profilePictureUrl: String?
}
