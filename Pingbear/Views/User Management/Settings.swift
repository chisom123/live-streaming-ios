import SwiftUI
import FirebaseAuth
import Combine

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var activeSheet: ActiveSheet?
    @StateObject private var myFriendsModel = MyFriendsModel()
    @Environment(\.didLogOut) private var didLogOut: PassthroughSubject<Void, Never>
    
    enum ActiveSheet: Identifiable {
        case addFriends, myFriends, myAccount
        
        var id: Int {
            switch self {
            case .addFriends: return 0
            case .myFriends: return 1
            case .myAccount: return 2
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            FirestoreListenerManager.shared.removeAllListeners()
            Analytics.shared.track(event: "user_logged_out")
            Analytics.shared.reset()
            UserDefaults.standard.set(false, forKey: "isLoggedIn")
            didLogOut.send(())
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    var body: some View {
        VStack {
            // Top Navigation Bar
            HStack {
                Color.clear
                    .frame(width: 30, height: 30)
                
                Spacer()
                
                Text("Settings")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(.white)
                
                Spacer()
                
                Color.clear
                    .frame(width: 30, height: 30)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            
            ScrollView {
                VStack(spacing: 50) {
                    // Account Settings Section
                    VStack(spacing: 0) {
                        ForEach(["Add Friends", "My Friends", "My Account"], id: \.self) { text in
                            VStack(spacing: 0) {
                                Button(action: {
                                    switch text {
                                    case "Add Friends": activeSheet = .addFriends
                                    case "My Friends": activeSheet = .myFriends
                                    case "My Account": activeSheet = .myAccount
                                    default: break
                                    }
                                }) {
                                    SettingsRow(text: text, color: .white)
                                }
                                
                                if text != "My Account" {
                                    Divider()
                                        .background(Color.white.opacity(0.2))
                                }
                            }
                        }
                    }
                    .background(Color(hex: "#1A2245"))
                    .cornerRadius(10)
                    
                    // Support & Account Actions Section
                    VStack(spacing: 0) {
                        ForEach(["Contact Us", "Log Out", "Delete Account"], id: \.self) { text in
                            VStack(spacing: 0) {
                                Button(action: {
                                    switch text {
                                    case "Contact Us":
                                        if let url = URL(string: "mailto:info@socialstarapp.com") {
                                            UIApplication.shared.open(url)
                                            Analytics.shared.trackTap(
                                                elementId: "contact_us_button",
                                                screenName: "settings"
                                            )
                                        }
                                    case "Log Out": showSignOutAlert = true
                                    case "Delete Account": showDeleteAccountAlert = true
                                    default: break
                                    }
                                }) {
                                    SettingsRow(text: text, color: Color(hex: "#D3D3D3"))
                                }
                                
                                if text != "Delete Account" {
                                    Divider()
                                        .background(Color.white.opacity(0.2))
                                }
                            }
                        }
                    }
                    .background(Color(hex: "#1A2245"))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(Color(hex: "#10183C"))
        .fullScreenCover(item: $activeSheet) { sheet in
            switch sheet {
            case .addFriends:
                AddFriendsView(addFriendsModel: AddFriendsModel())
            case .myFriends:
                MyFriendsView(viewModel: myFriendsModel)
            case .myAccount:
                ChangeNameView()
            }
        }
        .alert("Are you sure?", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Yes", role: .destructive) {
                signOut()
            }
        }
        .alert("Are you sure?", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Yes", role: .destructive) {
                signOut()
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "settings")
        }
    }
}

struct SettingsRow: View {
    let text: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 16, weight: .bold, design: .default))
                .foregroundColor(color)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(Color(hex: "#D3D3D3"))
                .font(.system(size: 15, weight: .bold))
        }
        .padding([.top, .bottom], 30)
        .padding([.leading, .trailing], 20)
    }
}
