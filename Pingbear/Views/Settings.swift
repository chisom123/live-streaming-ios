import SwiftUI
import Firebase

struct SettingsView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var showChangeNameView = false  // State to control the full screen cover for ChangeNameView
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            presentationMode.wrappedValue.dismiss()
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError)")
        }
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
                    
                    Spacer() // This spacer will ensure the two buttons are at opposite ends.
                }
                
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

                    // Add Friends Button
                    Button(action: {
                        // Add your action for Button 2 here
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

                    // My Friends Button
                    Button(action: {
                        // Add your action for Button 3 here
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
                    
                    // Log Out Button
                    Button(action: {
                        self.signOut()
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
                    
                }
                .padding(.top, 30)
                .padding([.leading, .trailing], 20)
                
                Spacer()
                
            }
        }
    }
}
