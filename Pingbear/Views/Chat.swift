import SwiftUI
import Firebase
import FirebaseFirestoreSwift

struct ChatView: View {
    @ObservedObject var viewModel: ChatModel
    var friend: AppUser
    @Environment(\.presentationMode) var presentationMode
    @State private var message: String = ""

    // Utility function to format the Timestamp
    func formatTimestamp(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mma - dd/MM/yy"
        return formatter.string(from: date).lowercased()
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
            ScrollView {
                ForEach(viewModel.messages.reversed(), id: \.id) { message in
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(message.content)
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundColor(message.senderID == friend.id ? Color.black : Color(hex: "#006400"))
                                .padding(10)

                            Text(formatTimestamp(message.timestamp))
                                .font(.system(size: 14, weight: .semibold, design: .default))
                                .padding(10)
                                .foregroundColor(.init(white: 0.75))
                        }
                        Spacer() // Push content to the left
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 15) // Added padding to the top
            Spacer()
            HStack {
                Button(action: {
                    self.message = ""
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.init(white: 0.75))
                        .font(.system(size: 19, weight: .bold))
                }
                .padding(10)

                TextField("Type here", text: $message)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)

                Button(action: {
                    viewModel.sendMessage(to: friend, content: message)
                }) {
                    Image(systemName: "arrow.up")
                        .foregroundColor(Color(hex: "#1199FF"))
                        .font(.system(size: 19, weight: .bold))
                }
                .padding(5)
                .padding(5)
            }
            .padding()
        }
        .onAppear {
            viewModel.fetchMessages(for: friend)
        }
    }
}
