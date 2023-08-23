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
                Spacer()
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .padding(.top, 30)
                        .padding(.trailing, 30)
                        .foregroundColor(.black)
                }
            }
            TextField("Search Friends", text: $searchText)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                .padding([.leading, .trailing], 20)
                .padding(.top, 10)
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
