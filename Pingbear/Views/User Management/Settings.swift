import SwiftUI
import Firebase
import Combine
import PostHog
import FirebaseFirestore
import NotificationBannerSwift

struct SettingsView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var showChangeNameView = false  // State to control the full screen cover for ChangeNameView
    @State private var showBoostView = false  // State to control the full screen cover for ChangeNameView
    @State private var showMyFriendsView = false  // State to control the full screen cover for ChangeNameView
    @State private var showAddFriendsView = false  // State to control the full screen cover for ChangeNameView
    @State private var showSignOutAlert = false
    @State private var isPresentingNewCompetition = false // State to control the presentation of the New Competition View
    @State private var showDeleteAccountAlert = false
    @Environment(\.didLogOut) private var didLogOut: PassthroughSubject<Void, Never>
    
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            UserDefaults.standard.set(false, forKey: "isLoggedIn")
            didLogOut.send(())
            PostHogSDK.shared.capture("Sign Out")
            PostHogSDK.shared.reset()
            FirestoreListenerManager.shared.removeAllListeners()
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                Text("Settings")
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .foregroundColor(.black) // Set the text color as needed
                    .padding(.horizontal, 20)

                Spacer() // Pushes the remaining content to the trailing edge
                
                Button(action: {
                    
                }) {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40) // Adjust the size as needed
                        .foregroundColor(Color(hex: "#1199FF")) // Your desired color
                        .background(Color.white)
                        .clipShape(Circle())
                        .padding(.horizontal, 20)
                        .opacity(0)
                }
            }
            .padding(.vertical, 15)
            
            Spacer()
            
            ScrollView {
                VStack {
                    VStack(spacing: 50) {
                        VStack(spacing: 25) {
                            // Change Name Button
                            Button(action: {
                                self.showAddFriendsView = true // Toggle the state to show the ChangeNameView
                            }) {
                                HStack {
                                    Text("Add Friends")
                                        .font(.system(size: 16, weight: .bold, design: .default))
                                        .foregroundColor(Color(hex: "#1199FF"))
                                    Spacer()
                                }
                                .padding([.top, .bottom], 20)
                                .padding([.leading, .trailing], 20)
                            }
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                            .fullScreenCover(isPresented: $showAddFriendsView) {  // Use the full screen cover modifier
                                AddFriendsView(addFriendsModel: AddFriendsModel())
                            }
                            
                            // Change Name Button
                            Button(action: {
                                self.showMyFriendsView = true // Toggle the state to show the ChangeNameView
                            }) {
                                HStack {
                                    Text("My Friends")
                                        .font(.system(size: 16, weight: .bold, design: .default))
                                        .foregroundColor(Color(hex: "#1199FF"))
                                    Spacer()
                                }
                                .padding([.top, .bottom], 20)
                                .padding([.leading, .trailing], 20)
                            }
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                            .fullScreenCover(isPresented: $showMyFriendsView) {  // Use the full screen cover modifier
                                MyFriendsView(viewModel: MyFriendsModel())
                            }
                        }
                        
                        VStack(spacing: 25) {
                            
                            // Change Name Button
                            Button(action: {
                                self.showChangeNameView = true // Toggle the state to show the ChangeNameView
                            }) {
                                HStack {
                                    Text("My Username")
                                        .font(.system(size: 16, weight: .bold, design: .default))
                                        .foregroundColor(Color(hex: "#1199FF"))
                                    Spacer()
                                }
                                .padding([.top, .bottom], 20)
                                .padding([.leading, .trailing], 20)
                            }
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                            .fullScreenCover(isPresented: $showChangeNameView) {  // Use the full screen cover modifier
                                ChangeNameView()
                            }
                            
                            Button(action: {
                                self.showBoostView = true // Toggle the state to show the ChangeNameView
                            }) {
                                HStack {
                                    Text("Boost")
                                        .font(.system(size: 16, weight: .bold, design: .default))
                                        .foregroundColor(Color(hex: "#1199FF"))
                                    Spacer()
                                }
                                .padding([.top, .bottom], 20)
                                .padding([.leading, .trailing], 20)
                            }
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                            .fullScreenCover(isPresented: $showBoostView) {  // Use the full screen cover modifier
                                BoostView(viewModel: BoostViewModel())
                            }
                            
                            Button(action: {
                                if let url = URL(string: "mailto:pingbearapp@gmail.com") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Text("Contact Us")
                                        .font(.system(size: 16, weight: .bold, design: .default))
                                        .foregroundColor(Color(hex: "#1199FF"))
                                    Spacer()
                                }
                                .padding([.top, .bottom], 20)
                                .padding([.leading, .trailing], 20)
                            }
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                        }
                        
                        VStack(spacing: 25) {
                            
                            // Log Out Button
                            Button(action: {
                                self.showSignOutAlert = true
                            }) {
                                HStack {
                                    Text("Log Out")
                                        .font(.system(size: 16, weight: .bold, design: .default))
                                        .foregroundColor(Color(hex: "#ababab"))
                                    Spacer()
                                }
                                .padding([.top, .bottom], 20)
                                .padding([.leading, .trailing], 20)
                            }
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                            .alert(isPresented: $showSignOutAlert) {
                                Alert(title: Text("Are you sure?"),
                                      primaryButton: .destructive(Text("Yes")) {
                                    self.signOut()
                                },
                                      secondaryButton: .cancel())
                            }
                            
                            Button(action: {
                                self.showDeleteAccountAlert = true
                            }) {
                                HStack {
                                    Text("Delete Account")
                                        .font(.system(size: 16, weight: .bold, design: .default))
                                        .foregroundColor(Color(hex: "#ababab"))
                                    Spacer()
                                }
                                .padding([.top, .bottom], 20)
                                .padding([.leading, .trailing], 20)
                            }
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                            .alert(isPresented: $showDeleteAccountAlert) {
                                Alert(title: Text("Are you sure?"),
                                      primaryButton: .destructive(Text("Yes")) {
                                    self.signOut()
                                },
                                      secondaryButton: .cancel())
                            }
                            
                        }
                    }
                    .padding([.leading, .trailing], 20)
                }
            }
            .fullScreenCover(isPresented: $isPresentingNewCompetition) {
                NewCompetition() // Replace this with the actual view you want to present
            }
        }
    }
}
