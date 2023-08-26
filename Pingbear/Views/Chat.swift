import SwiftUI
import Firebase
import FirebaseFirestoreSwift

struct ChatView: View {
    @ObservedObject var viewModel: ChatModel
    var friend: AppUser
    @Environment(\.presentationMode) var presentationMode
    @State private var message: String = ""

    func formatTime(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    func formatDate(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        if Calendar.current.isDate(date, inSameDayAs: today) {
            return "Today"
        } else if Calendar.current.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE dd MMM"
            return formatter.string(from: date)
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
                        .frame(width: 35, height: 35)
                        .padding(.leading, 20)
                        .padding(.top, 20)
                }
                
                Spacer()
                
                Text("Here 2s ago")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.black)
                    .padding(.trailing, 20)
                    .padding(.top, 20)
            }

            ScrollView {
                LazyVStack {
                    let groupedMessages = Dictionary(grouping: viewModel.messages, by: { Calendar.current.startOfDay(for: $0.timestamp.dateValue()) })

                    ForEach(groupedMessages.keys.sorted(), id: \.self) { dateKey in
                        let messagesForDay = groupedMessages[dateKey]?.sorted(by: { $0.timestamp.compare($1.timestamp) == .orderedAscending }) ?? []
                        MessageGroupView(date: formatDate(Timestamp(date: dateKey)), messages: messagesForDay, formatter: formatTime, friendId: friend.id)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 15)
            .padding(.bottom, 5)

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
                    .background(Color(hex: "#F5F5F5"))
                    .foregroundColor(Color(hex: "#000"))
                    .cornerRadius(5)

                Button(action: {
                    if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return
                    }
                    viewModel.sendMessage(to: friend, content: message)
                    self.message = ""
                }) {
                    Image(systemName: "arrow.up")
                        .foregroundColor(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .init(white: 0.75) : Color(hex: "#1199FF"))
                        .font(.system(size: 19, weight: .bold))
                }
                .padding(5)

            }
            .padding()
        }
        .onAppear {
            viewModel.fetchMessages(for: friend)
        }
    }
}

struct MessageGroupView: View {
    var date: String
    var messages: [Message]
    var formatter: (Timestamp) -> String
    var friendId: String

    var body: some View {
        VStack(spacing: 0) {
            Text(date)
                .padding(.vertical, 25)
                .foregroundColor(Color(hex: "#7a7a7a"))
                .font(.system(size: 15, weight: .semibold))
            
            ForEach(messages, id: \.id) { message in
                MessageView(message: message, friendId: friendId, formatter: formatter)
            }
        }
    }
}

struct MessageView: View {
    let message: Message
    let friendId: String
    let formatter: (Timestamp) -> String

    var body: some View {
        VStack {
            HStack {
                VStack {
                    HStack {
                        Text(message.content)
                            .font(.system(size: 15, weight: .semibold, design: .default))
                            .foregroundColor(Color.black)
                            .lineSpacing(8)

                        Spacer()

                        Text(formatter(message.timestamp))
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundColor(message.senderID == friendId ? Color(hex: "#7a7a7a") : Color(hex: "#37bf1d"))
                    }
                    .padding(15)
                    .background(message.senderID == friendId ? Color(hex: "#F5F5F5") : Color(hex: "#CCF6C4"))
                    .cornerRadius(5)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}
