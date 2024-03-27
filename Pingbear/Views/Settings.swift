import SwiftUI
import Firebase
import Combine
import PostHog
import FirebaseFirestore
import NotificationBannerSwift

struct SettingsView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var showChangeNameView = false  // State to control the full screen cover for ChangeNameView
    @State private var showMyFriendsView = false  // State to control the full screen cover for ChangeNameView
    @State private var showAddFriendsView = false  // State to control the full screen cover for ChangeNameView
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @Environment(\.didLogOut) private var didLogOut: PassthroughSubject<Void, Never>
    
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            UserDefaults.standard.set(false, forKey: "isLoggedIn")
            didLogOut.send(())
            PostHogSDK.shared.capture("Sign Out")
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }
    
    var body: some View {
        ZStack {
            VStack {
                
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
                        AddFriendsView(viewModel: AddFriendsModel())
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
                    
                    
                    // Change Name Button
                    Button(action: {
                        self.showChangeNameView = true // Toggle the state to show the ChangeNameView
                    }) {
                        HStack {
                            Text("Change My Username")
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
                    
                    Button(action: {
                        let banner = NotificationBanner(title: "Purchases Successfully Restored", style: .success)
                        banner.show()
                    }) {
                        HStack {
                            Text("Restore Purchases")
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: "#1199FF"))
                            Spacer()
                        }
                        .padding([.top, .bottom], 20)
                        .padding([.leading, .trailing], 20)
                    }
                    .background(Color(hex: "#F5F5F5"))
                    .cornerRadius(5)
                    
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
                            Text("Delete My Account")
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
                .padding([.leading, .trailing], 20)
            }
        }
    }
}
