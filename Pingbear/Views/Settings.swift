import SwiftUI
import Firebase
import Combine
import Flurry_iOS_SDK
import FirebaseFirestore

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
                        self.showChangeNameView = true // Toggle the state to show the ChangeNameView
                    }) {
                        HStack {
                            Text("Change My Name")
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
                    
                    
                    // Log Out Button
                    Button(action: {
                        self.showSignOutAlert = true
                        Flurry.log(eventName: "Sign-Out")
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
                            Flurry.log(eventName: "Sign-Out")
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
                            // Delete from Firebase Auth
                            let user = Auth.auth().currentUser
                            user?.delete { error in
                                if let error = error {
                                    print("Error deleting user: \(error)")
                                    return
                                } else {
                                    UserDefaults.standard.set(false, forKey: "isLoggedIn")
                                    didLogOut.send(())
                                    Flurry.log(eventName: "Account Deleted")
                                }
                            }
                        },
                              secondaryButton: .cancel())
                    }
                }
                .padding([.leading, .trailing], 20)
            }
        }
    }
}
