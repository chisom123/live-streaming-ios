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
                .background(Color(hex: "#e8e8e8"))
                .foregroundColor(Color(hex: "#000"))
                .cornerRadius(5)
                .padding([.leading, .trailing], 20)
                .padding(.top, 30)
            List(filteredUsers, id: \.id) { user in
                Text(user.name)
                    .onTapGesture {
                        if let index = users.firstIndex(of: user) {
                            self.selectedUserIndex = index
                            self.isPresented = false
                        }
                    }
            }
        }
    }
}
