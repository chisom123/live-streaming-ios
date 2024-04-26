import SwiftUI
import Firebase
import FirebaseFirestore

struct AddFriendsView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var username: String = ""
    @ObservedObject var viewModel: AddFriendsModel
    @State private var messageStatus: MessageStatus? = nil

    enum MessageStatus {
        case error, success, none
    }
    
    func processUsername(_ username: String) -> String {
        return username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image("Close")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .padding(.leading, 20)
                            .padding(.top, 20)
                    }
                    
                    Spacer()
                }
                
                Spacer()

                Text("Add Friend")
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.bottom, 40)
                    .padding(.horizontal)
                
                // Username TextField
                TextField("Enter username", text: $username)
                    .padding()
                    .background(Color(hex: "#F5F5F5"))
                    .foregroundColor(Color(hex: "#000"))
                    .cornerRadius(5)
                    .font(.system(size: 16, weight: .bold, design: .default))
                    .padding(.horizontal)
                
                if let status = messageStatus {
                    switch status {
                    case .error:
                        Text("Failed to add friend")
                            .foregroundColor(Color(hex: "#CC2255"))
                            .font(.system(size: 15, weight: .bold, design: .default))
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .padding(.bottom, 5)
                            .padding(.top, 20)
                            .padding(.horizontal)
                                    
                    case .success:
                        Text("Friend added successfully")
                            .foregroundColor(Color(hex: "#556B2F"))
                            .font(.system(size: 15, weight: .bold, design: .default))
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .padding(.bottom, 5)
                            .padding(.top, 20)
                            .padding(.horizontal)
                    case .none:
                        EmptyView()
                    }
                }
                
                Button(action: {
                    let processedUsername = processUsername(username)
                    viewModel.addFriend(byUsername: processedUsername) { (success, error) in
                        if success {
                            messageStatus = .success
                            username = ""
                        } else {
                            messageStatus = .error
                        }
                    }
                }) {
                    Text("Continue")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(Color(hex: "#1199FF"))
                        .foregroundColor(Color(hex: "#fff"))
                        .cornerRadius(200)
                }
                .padding(.top, 20)
                .padding(.horizontal)

                Spacer()
            }
            
            Spacer()
        }
    }
}
