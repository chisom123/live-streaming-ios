import SwiftUI
import FirebaseFirestore

struct AddFriendsView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var username: String = ""
    @StateObject var viewModel = ContactViewModel()
    @ObservedObject var addFriendsModel: AddFriendsModel
    @State private var messageStatus: MessageStatus? = nil

    var onFriendAdded: ((String, String) -> Void)? = nil

    enum MessageStatus {
        case error, success, none
    }

    func processUsername(_ username: String) -> String {
        return username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(AppTheme.iconColor)
                }

                Spacer()

                Text("Add Friends")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(AppTheme.primaryText)
                    .padding(.horizontal)

                Spacer()

                Image(systemName: "arrow.left")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 27, height: 27)
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)

            VStack {
                HStack(alignment: .center, spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppTheme.secondaryText)
                            .padding(.leading, 15)

                        TextField("Enter Username", text: $username)
                            .padding(.vertical)
                            .padding(.leading, 5)
                            .foregroundColor(AppTheme.primaryText)
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .tint(AppTheme.accent)
                    }
                    .frame(height: 70)
                    .background(
                        AppTheme.cardBackground
                            .clipShape(RoundedCorner(radius: 10, corners: [.topLeft, .bottomLeft]))
                    )

                    Button(action: {
                        let processedUsername = processUsername(username)
                        addFriendsModel.addFriend(byUsername: processedUsername) { (success, error) in
                            if success {
                                messageStatus = .success
                                username = ""
                                hideKeyboard()

                                if let onFriendAdded {
                                    Firestore.firestore().collection("users")
                                        .whereField("username", isEqualTo: processedUsername)
                                        .getDocuments { snap, _ in
                                            guard let doc = snap?.documents.first else { return }
                                            let userId = doc.documentID
                                            let name = doc.data()["name"] as? String ?? processedUsername
                                            onFriendAdded(userId, name)
                                        }
                                }
                            } else {
                                messageStatus = .error
                            }
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold, design: .default))
                            .frame(width: 60, height: 70)
                            .foregroundColor(.white)
                            .background(
                                (username.isEmpty ? AppTheme.disabledBackground : AppTheme.accent)
                                    .clipShape(RoundedCorner(radius: 10, corners: [.topRight, .bottomRight]))
                            )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)

                if let status = messageStatus {
                    switch status {
                    case .error:
                        Text("Failed to add friend")
                            .foregroundColor(.red)
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .padding(.bottom, 30)
                            .padding(.horizontal)
                    case .success:
                        Text("Friend added successfully")
                            .foregroundColor(AppTheme.green)
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .padding(.bottom, 30)
                            .padding(.horizontal)
                    case .none:
                        EmptyView()
                    }
                }
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(viewModel.matchedUsers.indices, id: \.self) { index in
                        VStack(spacing: 0) {
                            HStack {
                                ProfilePictureView(url: viewModel.matchedUsers[index].profileImageUrl, size: 40)
                                    .padding(.leading, 25)

                                VStack(alignment: .leading, spacing: 10) {
                                    Text(viewModel.matchedUsers[index].fullName)
                                        .font(.system(size: 16, weight: .bold, design: .default))
                                        .foregroundColor(AppTheme.primaryText)
                                        .lineLimit(1)
                                        .truncationMode(.tail)

                                    Text(viewModel.matchedUsers[index].username)
                                        .font(.system(size: 14, weight: .bold, design: .default))
                                        .foregroundColor(AppTheme.secondaryText)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .padding(.leading, 10)

                                Spacer()

                                if !viewModel.matchedUsers[index].isAdded {
                                    Button(action: {
                                        let contact = viewModel.matchedUsers[index]
                                        addFriendsModel.addFriend(byUsername: contact.username) { success, error in
                                            if success {
                                                DispatchQueue.main.async {
                                                    viewModel.matchedUsers[index].isAdded = true
                                                    Analytics.shared.track(
                                                        event: "friend_added_from_contacts",
                                                        properties: ["username": contact.username]
                                                    )
                                                }

                                                if let onFriendAdded {
                                                    Firestore.firestore().collection("users")
                                                        .whereField("username", isEqualTo: contact.username)
                                                        .getDocuments { snap, _ in
                                                            guard let doc = snap?.documents.first else { return }
                                                            let userId = doc.documentID
                                                            onFriendAdded(userId, contact.fullName)
                                                        }
                                                }
                                            } else if let error = error {
                                                print("Error adding friend: \(error.localizedDescription)")
                                            }
                                        }
                                    }) {
                                        Text("Add")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(EdgeInsets(top: 3, leading: 15, bottom: 3, trailing: 15))
                                            .background(AppTheme.accent)
                                            .cornerRadius(200)
                                    }
                                    .padding(.trailing, 30)
                                } else {
                                    HStack(spacing: 8) {
                                        Text("Added")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(.white)

                                        Image(systemName: "checkmark.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 18, height: 18)
                                            .foregroundColor(.white)
                                    }
                                    .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                                    .background(AppTheme.green)
                                    .cornerRadius(200)
                                    .padding(.trailing, 30)
                                    .opacity(0)
                                }
                            }
                            .padding(.vertical, 25)

                            if index != viewModel.matchedUsers.count - 1 {
                                Divider()
                                    .background(AppTheme.divider)
                            }
                        }
                    }
                }
                .background(AppTheme.cardBackground)
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
        .background(AppTheme.pageBackground)
        .onAppear {
            viewModel.requestContactAccess()
            Analytics.shared.trackScreen(name: "add_friends")
        }
    }
}
