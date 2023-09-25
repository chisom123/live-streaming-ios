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
        var lastInteractionTime: String {
            guard let timestamp = viewModel.friendLastViewed else { return " " }
            let interval = Date().timeIntervalSince(timestamp.dateValue())
            if interval < 60 {
                return "Here \(Int(interval))s ago"
            } else if interval < 3600 {
                return "Here \(Int(interval/60))m ago"
            } else if interval < 86400 {
                return "Here \(Int(interval/3600))h ago"
            } else {
                return "Here \(Int(interval/86400))d ago"
            }
        }

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
                
                Text(lastInteractionTime)
                    .font(.system(size: 17, weight: .semibold, design: .default))
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
                    Text(viewModel.lastPerson == Auth.auth().currentUser?.uid ? "" : "Your turn to type")
                        .foregroundColor(Color(hex: "#FF6347"))  // Change placeholder color conditionally
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .padding(.leading) // Adjust to match your TextField's padding
                        .padding(.top, 15)
                Spacer()
            }
            
            ZStack(alignment: .leading) {
                // Actual TextField
                TextField("", text: $message, onCommit: {
                    if !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        viewModel.sendMessage(to: friend, content: message)
                        DispatchQueue.main.async {
                            self.message = ""
                        }
                    }
                })
                .disabled(viewModel.lastPerson == Auth.auth().currentUser?.uid)
                .submitLabel(.send)
                .padding()
                .background(viewModel.lastPerson == Auth.auth().currentUser?.uid ? Color(hex: "#F5F5F5") : Color(hex: "#F5F5F5"))
                .cornerRadius(5)
                .font(.system(size: 16, weight: .semibold, design: .default))
                .foregroundColor(Color.black)

                // Conditional Placeholder
                if message.isEmpty {
                    Text(viewModel.lastPerson == Auth.auth().currentUser?.uid ? "Waiting for a reply" : "")
                        .foregroundColor(Color(hex: "#FF1493"))  // Change placeholder color conditionally
                        .padding(.leading) // Adjust to match your TextField's padding
                        .font(.system(size: 16, weight: .semibold, design: .default))
                }
            }
            .padding()
        }
        .onAppear {
            viewModel.fetchMessages(for: friend)
            viewModel.updateLastViewed(for: friend)
            viewModel.fetchLastViewed(for: friend)
            viewModel.fetchLastPerson(for: friend) // Fetch lastperson on view appear
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
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundColor(Color.black)
                            .lineSpacing(9)

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
