import SwiftUI
import Contacts
import Firebase
import FirebaseFirestore
import PhoneNumberKit
import PostHog

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
                        .foregroundColor(Color.black) // Your desired color
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            
            VStack {
                
                Text("Add Friends")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.horizontal)
                
                HStack(alignment: .center, spacing: 10) {
                    TextField("Enter Friend's Username", text: $username)
                        .padding()
                        .padding(.vertical, 5)
                        .background(Color(hex: "#F5F5F5"))
                        .foregroundColor(Color(hex: "#000"))
                        .cornerRadius(10)
                        .font(.system(size: 16, weight: .bold, design: .default))
                    
                    Button(action: {
                        let processedUsername = processUsername(username)
                        addFriendsModel.addFriend(byUsername: processedUsername) { (success, error) in
                            if success {
                                messageStatus = .success
                                username = ""
                            } else {
                                messageStatus = .error
                            }
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold, design: .default))
                            .padding()
                            .padding(.vertical, 5)
                            .background(Color(hex: "#1199FF"))
                            .foregroundColor(Color(hex: "#fff"))
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 30)
                
                if let status = messageStatus {
                    switch status {
                    case .error:
                        Text("Failed to add friend")
                            .foregroundColor(Color(hex: "#CC2255"))
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .padding(.bottom, 30)
                            .padding(.horizontal)
                                    
                    case .success:
                        Text("Friend added successfully")
                            .foregroundColor(Color(hex: "#008000"))
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
                VStack(spacing: 25) {
                    ForEach(viewModel.matchedUsers.indices, id: \.self) { index in
                        Button(action: {
                            if !viewModel.matchedUsers[index].isAdded {
                                addFriendsModel.addFriend(byUsername: viewModel.matchedUsers[index].username) { success, error in
                                    if success {
                                        DispatchQueue.main.async {
                                            viewModel.matchedUsers[index].isAdded = true
                                            PostHogSDK.shared.capture("Friend successfully added from standalone view")
                                        }
                                    } else if let error = error {
                                        print("Error adding friend: \(error.localizedDescription)")
                                    }
                                }
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 18) {
                                    Text(viewModel.matchedUsers[index].name)
                                        .font(.system(size: 16, weight: .bold, design: .default))
                                        .foregroundColor(.black)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 6) { // Control spacing between text and icon
                                    Text(viewModel.matchedUsers[index].isAdded ? "Added" : "Add")
                                        .fontWeight(.bold)
                                        .foregroundColor(viewModel.matchedUsers[index].isAdded ? Color.green : Color(hex: "#1199FF"))
                                        .font(.system(size: 16, weight: .bold, design: .default))
                                    
                                    Image(systemName: viewModel.matchedUsers[index].isAdded ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundColor(viewModel.matchedUsers[index].isAdded ? Color.green : Color(hex: "#1199FF"))
                                        .font(.system(size: 16, weight: .bold, design: .default))
                                }
                                
                            }
                            .padding(.vertical, 25)
                            .padding(.horizontal, 20)
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                        }
                        .disabled(viewModel.matchedUsers[index].isAdded)
                    }
                }
            }
            .padding(.horizontal)
        }
        .onAppear {
            viewModel.requestContactAccess()
        }
    }
}
