import SwiftUI

struct SearchView: View {
    @Binding var selectedUserIndex: Int?
    @Binding var isPresented: Bool
    let users: [AppUser]
    @State private var searchText: String = ""

    @Environment(\.presentationMode) var presentationMode

    var filteredUsers: [AppUser] {
        if searchText.isEmpty {
            return []
        } else {
            return users.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }

    var body: some View {
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
            
            TextField("Search Friends", text: $searchText)
                .padding()
                .background(Color(hex: "#F5F5F5"))
                .foregroundColor(Color(hex: "#000"))
                .cornerRadius(5)
                .font(.system(size: 16, weight: .medium, design: .default))
                .padding([.leading, .trailing], 20)
                .padding(.top, 30)

            ScrollView {
                VStack(spacing: 25) {
                    ForEach(filteredUsers, id: \.id) { user in
                        
                        Button(action: {
                            if let index = users.firstIndex(of: user) {
                                self.selectedUserIndex = index
                                self.isPresented = false
                            }
                        }) {
                            HStack {
                                Text(user.name)
                                    .font(.system(size: 16, weight: .bold, design: .default))
                                    .foregroundColor(Color(hex: "#000"))
                                
                                Spacer()  // This will push the HStack to take up the entire width.
                            }
                            .padding(.vertical, 20)
                            .padding(.horizontal, 20)
                            .background(Color(hex: "#F5F5F5"))
                            .cornerRadius(5)
                        }
                        .buttonStyle(PlainButtonStyle())  // This removes the default button highlighting
                    }
                }
                .padding(.top, 30)
                .padding(.horizontal, 20)
            }
        }
    }
}
