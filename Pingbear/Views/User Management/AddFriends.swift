import SwiftUI

struct AddFriendsView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var username: String = ""
    @StateObject var viewModel = ContactViewModel() // Using ContactViewModel for fetching contacts
    @ObservedObject var addFriendsModel: AddFriendsModel
    @State private var messageStatus: MessageStatus? = nil

    enum MessageStatus {
        case error, success, none
    }
    
    func processUsername(_ username: String) -> String {
        return username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
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
                
                Text("Add Friends")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                 
                }) {
                    Image(systemName: "arrow.left")
                        .resizable() // Allows resizing of the image
                        .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                        .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                        .foregroundColor(Color.white) // Your desired color
                }
                .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            
            VStack {
                HStack(alignment: .center, spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.leading, 15)
                        
                        TextField("Enter Username", text: $username)
                            .padding(.vertical)
                            .padding(.leading, 5)
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .accentColor(.white)
                    }
                    .frame(height: 70) // Same fixed height
                    .background(
                        Color(hex: "#3B4374")
                            .clipShape(
                                RoundedCorner(
                                    radius: 10,
                                    corners: [.topLeft, .bottomLeft]
                                )
                            )
                    )
                    
                    Button(action: {
                        let processedUsername = processUsername(username)
                        addFriendsModel.addFriend(byUsername: processedUsername) { (success, error) in
                            if success {
                                messageStatus = .success
                                username = ""
                                hideKeyboard()
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
                                Color(hex: username.isEmpty ? "#323862" : "#FF4081")
                                    .clipShape(
                                        RoundedCorner(
                                            radius: 10,
                                            corners: [.topRight, .bottomRight]
                                        )
                                    )
                            )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
                
                if let status = messageStatus {
                    switch status {
                    case .error:
                        Text("Failed to add friend")
                            .foregroundColor(Color(hex: "#FF0000"))
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .padding(.bottom, 30)
                            .padding(.horizontal)
                                    
                    case .success:
                        Text("Friend added successfully")
                            .foregroundColor(Color(hex: "#FFF"))
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
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    
                                    Text(viewModel.matchedUsers[index].username)
                                        .font(.system(size: 14, weight: .bold, design: .default))
                                        .foregroundColor(Color(hex: "#D3D3D3"))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .padding(.leading, 10)
                                
                                Spacer()
                                
                                if !viewModel.matchedUsers[index].isAdded {
                                    Button(action: {
                                        addFriendsModel.addFriend(byUsername: viewModel.matchedUsers[index].username) { success, error in
                                            if success {
                                                DispatchQueue.main.async {
                                                    viewModel.matchedUsers[index].isAdded = true
                                                    Analytics.shared.track(
                                                        event: "friend_added_from_contacts",
                                                        properties: ["username": viewModel.matchedUsers[index].username]
                                                    )
                                                }
                                            } else if let error = error {
                                                print("Error adding friend: \(error.localizedDescription)")
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            Text("Add")
                                                .font(.system(size: 17, weight: .bold))
                                                .foregroundColor(Color(hex: "#FFF"))
                                        }
                                        .padding(EdgeInsets(top: 3, leading: 15, bottom: 3, trailing: 15))
                                        .background(Color(hex: "#FF4081"))
                                        .cornerRadius(200)
                                    }
                                    .padding(.trailing, 30)
                                } else {
                                    HStack(spacing: 8) {
                                        Text("Added")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(Color(hex: "#DAA520"))
                                        
                                        Image(systemName: "checkmark.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 18, height: 18)
                                            .foregroundColor(Color(hex: "#DAA520"))
                                    }
                                    .padding(EdgeInsets(top: 2.75, leading: 10, bottom: 2.75, trailing: 10))
                                    .background(Color(hex: "#FF4081"))
                                    .cornerRadius(200)
                                    .padding(.trailing, 30)
                                    .opacity(0)
                                }
                            }
                            .padding(.vertical, 25)
                            
                            if index != viewModel.matchedUsers.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.2))
                            }
                        }
                    }
                }
                .background(Color(hex: "#1A2245"))
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
        .background(Color(hex: "#10183C"))
        .onAppear {
            viewModel.requestContactAccess()
            Analytics.shared.trackScreen(name: "add_friends")
        }
    }
}
