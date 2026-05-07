import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import MessageUI

struct JoinSelectView: View {
    @State var selectedFriends: Set<String> = []
    @State var currentUserId: String = Auth.auth().currentUser?.uid ?? ""
    @State private var isCustomShareSheetPresented = false
    @State private var showAddFriendsView = false
    @State private var isLoading = true
    @State private var showNotificationAlert = false
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationManager = PushNotificationManager.shared
    var competition: Competition
    @ObservedObject var viewModel: MyFriendsModel

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left").resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27).foregroundColor(AppTheme.primaryText)
                    }
                    Spacer()
                    Text("Add Players to Competition")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .multilineTextAlignment(.center).lineSpacing(10).foregroundColor(AppTheme.primaryText).padding(.horizontal)
                    Spacer()
                    Button(action: { self.showAddFriendsView = true }) {
                        Image(systemName: "person.crop.circle.badge.plus").resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27).foregroundColor(AppTheme.primaryText)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 20)

                VStack {
                    Button(action: {
                        isCustomShareSheetPresented = true
                        Analytics.shared.trackTap(elementId: "invite_share_sheet", screenName: "add_players")
                    }) {
                        HStack {
                            Text("Invite Friends to Play")
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundColor(AppTheme.primaryText).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 10)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(AppTheme.primaryText).padding(.trailing, 10)
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity).padding(20).padding(.vertical, 5)
                        .background(AppTheme.cardBackground).cornerRadius(10).padding(.bottom, 20).padding(.horizontal)
                    }
                    .sheet(isPresented: $isCustomShareSheetPresented) {
                        CustomShareSheet(shareText: createShareText(), shareLink: DeepLinkHandler.shared.createShareableLink(for: competition.id))
                    }

                    if isLoading {
                        Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.friends.isEmpty {
                        Spacer()
                        Text("No Friends Yet").font(.system(size: 18, weight: .bold, design: .default)).foregroundColor(AppTheme.primaryText)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(viewModel.friends, id: \.id) { friend in
                                    VStack(spacing: 0) {
                                        SelectableFriendView(
                                            friend: friend.name, profileImageUrl: friend.profileImageUrl,
                                            isSelected: self.selectedFriends.contains(friend.id)
                                        ) {
                                            if self.selectedFriends.contains(friend.id) { self.selectedFriends.remove(friend.id) }
                                            else { self.selectedFriends.insert(friend.id) }
                                        }
                                        if friend.id != viewModel.friends.last?.id {
                                            Divider().background(AppTheme.divider)
                                        }
                                    }
                                }
                            }
                            .background(AppTheme.cardBackground).cornerRadius(10).padding(.horizontal)
                        }
                    }

                    Button(action: { updateCompetitionAllowJoin(); dismiss() }) {
                        Text("Continue").frame(maxWidth: .infinity, minHeight: 44)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .background(!self.selectedFriends.isEmpty ? AppTheme.accent : AppTheme.disabledBackground)
                            .foregroundColor(!self.selectedFriends.isEmpty ? .white : AppTheme.disabledText)
                            .cornerRadius(200)
                    }
                    .padding(.top, 10).padding(.bottom, 10).disabled(self.selectedFriends.isEmpty).padding(.horizontal)
                }
            }
        }
        .background(AppTheme.pageBackground)
        .onAppear {
            viewModel.fetchFriends { isLoading = false }
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async { if settings.authorizationStatus == .notDetermined { self.showNotificationAlert = true } }
            }
            Analytics.shared.trackScreen(name: "add_players")
        }
        .fullScreenCover(isPresented: $showAddFriendsView, onDismiss: { viewModel.fetchFriends { isLoading = false } }) {
            AddFriendsView(addFriendsModel: AddFriendsModel())
        }
        .alert("Get Notified When Your Friends Join the Competition", isPresented: $showNotificationAlert) {
            Button("OK") {
                notificationManager.requestNotificationPermission { granted in
                    if granted {
                        if let userId = Auth.auth().currentUser?.uid { notificationManager.queueTokenUpdate(userId: userId) }
                        Analytics.shared.trackTap(elementId: "notification_permission_granted", screenName: "add_players")
                    } else {
                        Analytics.shared.trackTap(elementId: "notification_permission_denied", screenName: "add_players")
                    }
                }
            }
        }
    }

    private func createShareText() -> String {
        let shareLink = DeepLinkHandler.shared.createShareableLink(for: competition.id)
        return "Hey i started a photo competition on SocialStar. Join it! \(shareLink)"
    }

    private func isUserAlreadyMember(userId: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        db.collection("groupMemberships").document(userId).collection("competitions")
            .whereField("competitionId", isEqualTo: competition.id).getDocuments { snapshot, error in
                if let error = error { print("Error checking membership: \(error)"); completion(false) }
                else if let snapshot = snapshot, !snapshot.documents.isEmpty { completion(true) }
                else { completion(false) }
            }
    }

    func updateCompetitionAllowJoin() {
        let db = Firestore.firestore()
        db.collection("users").document(currentUserId).getDocument { (document, error) in
            if let document = document, let username = document.data()?["name"] as? String {
                self.updateCompetitionWithNotifications(username: username)
            }
        }
    }

    func updateCompetitionWithNotifications(username: String) {
        let db = Firestore.firestore()
        let dispatchGroup = DispatchGroup()
        for userId in selectedFriends {
            dispatchGroup.enter()
            let memberRef = db.collection("competitions").document(competition.id).collection("members").document(userId)
            memberRef.setData(["userId": userId, "coins": 1000]) { error in
                if let error = error { print("Error adding member: \(error)"); dispatchGroup.leave(); return }
                let membershipRef = db.collection("groupMemberships").document(userId).collection("competitions").document(competition.id)
                membershipRef.setData(["competitionId": competition.id]) { error in
                    if let error = error { print("Error adding to groupMemberships: \(error)"); dispatchGroup.leave(); return }
                    Analytics.shared.trackCompetition(action: "join", competitionId: competition.id, properties: ["user_id": userId])
                    db.collection("users").document(userId).getDocument { userDoc, _ in
                        let newMemberName = userDoc?.data()?["name"] as? String ?? "Someone"
                        NotificationQueueManager.shared.queueIndividualNotification(to: userId, title: self.competition.description, body: "\(username) added you to the competition", senderId: self.currentUserId)
                        NotificationQueueManager.shared.queueGroupNotification(competitionId: self.competition.id, title: self.competition.description, body: "\(newMemberName) joined the competition", senderId: self.currentUserId, excludeUsers: [self.currentUserId, userId])
                        dispatchGroup.leave()
                    }
                }
            }
        }
        dispatchGroup.notify(queue: .main) { NotificationQueueManager.shared.processQueuedNotifications() }
    }
}

struct SelectableFriendView: View {
    var friend: String
    var profileImageUrl: String?
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                HStack(spacing: 20) {
                    ProfilePictureView(url: profileImageUrl, size: 40)
                    Text(friend).font(.system(size: 16, weight: .bold)).lineLimit(1).lineSpacing(9)
                        .foregroundColor(AppTheme.primaryText).truncationMode(.tail).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, 30)
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.primaryText).padding(.trailing, 30)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 20)
            .background(isSelected ? AppTheme.accent.opacity(0.2) : Color.clear)
        }
    }
}

struct RadioButtonField: View {
    let id: String; let label: String; let isMarked: Bool; let callback: (String) -> ()
    init(id: String, label: String, isMarked: Bool = false, callback: @escaping (String) -> ()) {
        self.id = id; self.label = label; self.isMarked = isMarked; self.callback = callback
    }
    var body: some View {
        Button(action: { self.callback(self.id) }) {
            HStack(alignment: .center, spacing: 20) {
                Image(systemName: self.isMarked ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(self.isMarked ? AppTheme.accent : .white)
                Text(self.label).foregroundColor(AppTheme.primaryText).font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .background(AppTheme.cardBackground).cornerRadius(20)
        }
    }
}
