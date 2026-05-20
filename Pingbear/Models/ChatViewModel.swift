import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoadingMore = false
    @Published var hasMoreMessages = true
    @Published var connectionStatus: ConnectionStatus = .connected
    @Published var errorMessage: String?

    private let competitionId: String
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    private var cancellables = Set<AnyCancellable>()
    private var lastDocument: DocumentSnapshot?
    private let pageSize = 50
    private var pendingMessages: [String: ChatMessage] = [:]
    private var initialLoadComplete = false

    private var userCache: [String: (name: String, profilePicture: String?)] = [:]

    enum ConnectionStatus {
        case connected
        case connecting
        case disconnected
    }

    init(competitionId: String) {
        self.competitionId = competitionId
        setupRealtimeListeners()
        fetchInitialMessages()
    }

    deinit {
        cleanup()
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Setup
    // ─────────────────────────────────────────────────────────────

    private func setupRealtimeListeners() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        let messagesQuery = db.collection("competitions")
            .document(competitionId)
            .collection("messages")
            .order(by: "timestamp", descending: false)

        let listener = messagesQuery.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                self.handleError(error)
                return
            }

            guard let snapshot else { return }

            snapshot.documentChanges.forEach { change in
                if change.type == .added {
                    if let message = ChatMessage(document: change.document, currentUserId: currentUserId) {
                        if self.initialLoadComplete || message.isCurrentUser {
                            self.handleNewMessage(message)
                        }
                    }
                }
            }
        }

        listeners.append(listener)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Send Message
    // ─────────────────────────────────────────────────────────────

    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let currentUserId = Auth.auth().currentUser?.uid else { return }

        fetchCurrentUserInfo { [weak self] userName, profilePicture in
            guard let self else { return }

            let messageId = UUID().uuidString
            let message = ChatMessage(
                id: messageId,
                senderId: currentUserId,
                senderName: userName,
                senderProfilePicture: profilePicture,
                text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                timestamp: Date(),
                isRead: false,
                isCurrentUser: true,
                messageStatus: .sending
            )

            self.pendingMessages[messageId] = message

            DispatchQueue.main.async {
                self.messages.append(message)
            }

            self.db.collection("competitions")
                .document(self.competitionId)
                .collection("messages")
                .document(messageId)
                .setData(message.toFirestore()) { [weak self] error in
                    guard let self else { return }
                    if let error {
                        self.handleSendError(messageId: messageId, error: error)
                    } else {
                        self.handleSendSuccess(messageId: messageId)
                    }
                }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Message Handling
    // ─────────────────────────────────────────────────────────────

    private func handleNewMessage(_ message: ChatMessage) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if let existingIndex = self.messages.firstIndex(where: { $0.id == message.id }) {
                self.messages[existingIndex] = message
            } else if !self.messages.contains(where: { $0.id == message.id }) {
                if let lastMessage = self.messages.last,
                   message.timestamp >= lastMessage.timestamp {
                    self.messages.append(message)
                } else if let insertIndex = self.messages.firstIndex(where: { $0.timestamp > message.timestamp }) {
                    self.messages.insert(message, at: insertIndex)
                } else {
                    self.messages.append(message)
                }
            }

            self.pendingMessages.removeValue(forKey: message.id)
        }
    }

    private func handleSendError(messageId: String, error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                let msg = self.messages[index]
                self.messages[index] = ChatMessage(
                    id: msg.id,
                    senderId: msg.senderId,
                    senderName: msg.senderName,
                    senderProfilePicture: msg.senderProfilePicture,
                    text: msg.text,
                    timestamp: msg.timestamp,
                    isRead: msg.isRead,
                    isCurrentUser: msg.isCurrentUser,
                    messageStatus: .failed
                )
            }
            self.errorMessage = "Failed to send message. Tap to retry."
        }
    }

    private func handleSendSuccess(messageId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                let msg = self.messages[index]
                self.messages[index] = ChatMessage(
                    id: msg.id,
                    senderId: msg.senderId,
                    senderName: msg.senderName,
                    senderProfilePicture: msg.senderProfilePicture,
                    text: msg.text,
                    timestamp: msg.timestamp,
                    isRead: msg.isRead,
                    isCurrentUser: msg.isCurrentUser,
                    messageStatus: .sent
                )
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Message Loading
    // ─────────────────────────────────────────────────────────────

    private func fetchInitialMessages() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        isLoadingMore = true

        db.collection("competitions")
            .document(competitionId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: pageSize)
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    self.handleError(error)
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.isLoadingMore = false
                    self.initialLoadComplete = true
                    return
                }

                self.lastDocument = documents.last
                self.hasMoreMessages = documents.count == self.pageSize

                let newMessages = documents.compactMap {
                    ChatMessage(document: $0, currentUserId: currentUserId)
                }.reversed()

                DispatchQueue.main.async {
                    self.messages = Array(newMessages)
                    self.isLoadingMore = false
                    self.initialLoadComplete = true
                    self.markMessagesAsRead()
                }
            }
    }

    func loadMoreMessages() {
        guard !isLoadingMore,
              hasMoreMessages,
              let lastDocument,
              let currentUserId = Auth.auth().currentUser?.uid else { return }

        isLoadingMore = true

        db.collection("competitions")
            .document(competitionId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .start(afterDocument: lastDocument)
            .limit(to: pageSize)
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    self.handleError(error)
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.isLoadingMore = false
                    return
                }

                self.lastDocument = documents.last
                self.hasMoreMessages = documents.count == self.pageSize

                let olderMessages = documents.compactMap {
                    ChatMessage(document: $0, currentUserId: currentUserId)
                }.reversed()

                DispatchQueue.main.async {
                    self.messages.insert(contentsOf: olderMessages, at: 0)
                    self.isLoadingMore = false
                }
            }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────────────────────────────

    private func fetchCurrentUserInfo(completion: @escaping (String, String?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion("Unknown", nil)
            return
        }

        if let cached = userCache[currentUserId] {
            completion(cached.name, cached.profilePicture)
            return
        }

        db.collection("users").document(currentUserId).getDocument { [weak self] snapshot, _ in
            guard let data = snapshot?.data() else {
                completion("Unknown", nil)
                return
            }
            let userName = data["name"] as? String ?? "Unknown"
            let profilePicture = data["profilePictureUrl"] as? String
            self?.userCache[currentUserId] = (userName, profilePicture)
            completion(userName, profilePicture)
        }
    }

    private func markMessagesAsRead() {
        let batch = db.batch()
        var hasUnread = false

        for message in messages where !message.isCurrentUser && !message.isRead {
            hasUnread = true
            let ref = db.collection("competitions")
                .document(competitionId)
                .collection("messages")
                .document(message.id)
            batch.updateData(["isRead": true], forDocument: ref)
        }

        if hasUnread { batch.commit() }
    }

    private func handleError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = error.localizedDescription
            self?.connectionStatus = .disconnected
        }
    }

    func cleanup() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        userCache.removeAll()
        pendingMessages.removeAll()
    }
}
