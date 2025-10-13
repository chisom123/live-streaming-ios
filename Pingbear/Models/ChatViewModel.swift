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
    
    // User cache for performance
    private var userCache: [String: (name: String, profilePicture: String?)] = [:]
    // Photo cache for performance
    private var photoCache: [String: (photo: UserPhoto, owner: (name: String, profilePicture: String?))] = [:]
    
    enum ConnectionStatus {
        case connected
        case connecting
        case disconnected
    }
    
    init(competitionId: String) {
        self.competitionId = competitionId
        setupRealtimeListeners()
        fetchInitialMessages()
        observeNetworkStatus()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Photo Data Fetching
    func fetchPhotoData(for photoId: String, competitionId: String, completion: @escaping (UserPhoto?, (name: String, profilePicture: String?)?) -> Void) {
        // Check cache first
        if let cached = photoCache[photoId] {
            completion(cached.photo, cached.owner)
            return
        }
        
        // Fetch photo document from Firestore
        db.collection("competitions")
            .document(competitionId)
            .collection("entries")
            .document(photoId)
            .getDocument { [weak self] document, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching photo: \(error)")
                    completion(nil, nil)
                    return
                }
                
                guard let data = document?.data() else {
                    completion(nil, nil)
                    return
                }
                
                // Create UserPhoto from Firestore data
                let photo = UserPhoto(
                    id: photoId,
                    photoUrl: data["imageUrl"] as? String ?? "",
                    stars: data["stars"] as? Int ?? 0,
                    isSuperstar: data["superstar"] as? Bool ?? false,
                    creationDate: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                    themeName: data["themeName"] as? String,
                    themeId: data["themeId"] as? String,
                    overlayText: data["overlayText"] as? String,
                    overlayVerticalPosition: data["overlayVerticalPosition"] as? CGFloat ?? 0.5,
                    isFromCamera: data["isFromCamera"] as? Bool ?? true,
                    userId: data["userId"] as? String ?? "",
                    parlayStatus: data["parlayStatus"] as? String,
                    parlayPredictions: data["predictions"] as? [String: Any],
                    parlayPayout: data["potentialPayout"] as? Int,
                    parlayStake: data["entryCost"] as? Int
                )
                
                let userId = data["userId"] as? String ?? ""
                
                // Fetch user info
                self.fetchUserInfo(userId: userId) { userName, profilePicture in
                    let owner = (userName, profilePicture)
                    
                    // Cache the result
                    self.photoCache[photoId] = (photo, owner)
                    
                    completion(photo, owner)
                }
            }
    }
    
    private func fetchUserInfo(userId: String, completion: @escaping (String, String?) -> Void) {
        // Check cache first
        if let cached = userCache[userId] {
            completion(cached.name, cached.profilePicture)
            return
        }
        
        db.collection("users")
            .document(userId)
            .getDocument { [weak self] userDoc, userError in
                let userData = userDoc?.data()
                let userName = userData?["username"] as? String ?? "Unknown"
                let profilePicture = userData?["profilePictureUrl"] as? String
                
                // Cache the result
                self?.userCache[userId] = (userName, profilePicture)
                
                completion(userName, profilePicture)
            }
    }
    
    // MARK: - Setup Methods
    private func setupRealtimeListeners() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let messagesQuery = db.collection("competitions")
            .document(competitionId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
        
        let newMessagesListener = messagesQuery.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleError(error)
                return
            }
            
            guard let snapshot = snapshot else { return }
            
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
        
        listeners.append(newMessagesListener)
    }
    
    // MARK: - Message Handling
    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        fetchCurrentUserInfo { [weak self] userName, profilePicture in
            guard let self = self else { return }
            
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
            
            let messageRef = self.db.collection("competitions")
                .document(self.competitionId)
                .collection("messages")
                .document(messageId)
            
            messageRef.setData(message.toFirestore()) { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    self.handleSendError(messageId: messageId, error: error)
                } else {
                    self.handleSendSuccess(messageId: messageId)
                }
            }
        }
    }
    
    // MARK: - Simplified Photo Message Support
    func sendPhotoMessage(photo: UserPhoto, text: String = "") {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        fetchCurrentUserInfo { [weak self] userName, profilePicture in
            guard let self = self else { return }
            
            let messageId = UUID().uuidString
            let messageText = text.isEmpty ? "Shared a photo" : text
            
            let message = ChatMessage(
                id: messageId,
                senderId: currentUserId,
                senderName: userName,
                senderProfilePicture: profilePicture,
                text: messageText,
                timestamp: Date(),
                isRead: false,
                isCurrentUser: true,
                messageStatus: .sending,
                photoId: photo.id, // ONLY store the photo ID
                photoCompetitionId: self.competitionId
            )
            
            self.pendingMessages[messageId] = message
            
            DispatchQueue.main.async {
                self.messages.append(message)
            }
            
            let messageRef = self.db.collection("competitions")
                .document(self.competitionId)
                .collection("messages")
                .document(messageId)
            
            messageRef.setData(message.toFirestore()) { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    self.handleSendError(messageId: messageId, error: error)
                } else {
                    self.handleSendSuccess(messageId: messageId)
                }
            }
        }
    }
    
    private func handleNewMessage(_ message: ChatMessage) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let existingIndex = self.messages.firstIndex(where: { $0.id == message.id }) {
                self.messages[existingIndex] = message
            } else {
                let isNewMessage = !self.messages.contains(where: { $0.id == message.id })
                
                if isNewMessage {
                    if let lastMessage = self.messages.last,
                       message.timestamp >= lastMessage.timestamp {
                        self.messages.append(message)
                    } else {
                        if let insertIndex = self.messages.firstIndex(where: { $0.timestamp > message.timestamp }) {
                            self.messages.insert(message, at: insertIndex)
                        } else {
                            self.messages.append(message)
                        }
                    }
                }
            }
            
            self.pendingMessages.removeValue(forKey: message.id)
        }
    }
    
    private func handleSendError(messageId: String, error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                var failedMessage = self.messages[index]
                failedMessage = ChatMessage(
                    id: failedMessage.id,
                    senderId: failedMessage.senderId,
                    senderName: failedMessage.senderName,
                    senderProfilePicture: failedMessage.senderProfilePicture,
                    text: failedMessage.text,
                    timestamp: failedMessage.timestamp,
                    isRead: failedMessage.isRead,
                    isCurrentUser: failedMessage.isCurrentUser,
                    messageStatus: .failed,
                    photoId: failedMessage.photoId,
                    photoCompetitionId: failedMessage.photoCompetitionId
                )
                self.messages[index] = failedMessage
            }
            
            self.errorMessage = "Failed to send message. Tap to retry."
        }
    }
    
    private func handleSendSuccess(messageId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                var sentMessage = self.messages[index]
                sentMessage = ChatMessage(
                    id: sentMessage.id,
                    senderId: sentMessage.senderId,
                    senderName: sentMessage.senderName,
                    senderProfilePicture: sentMessage.senderProfilePicture,
                    text: sentMessage.text,
                    timestamp: sentMessage.timestamp,
                    isRead: sentMessage.isRead,
                    isCurrentUser: sentMessage.isCurrentUser,
                    messageStatus: .sent,
                    photoId: sentMessage.photoId,
                    photoCompetitionId: sentMessage.photoCompetitionId
                )
                self.messages[index] = sentMessage
            }
        }
    }
    
    // MARK: - Message Loading (unchanged)
    private func fetchInitialMessages() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        isLoadingMore = true
        
        let query = db.collection("competitions")
            .document(competitionId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: pageSize)
        
        query.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
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
            
            let newMessages = documents.compactMap { doc in
                ChatMessage(document: doc, currentUserId: currentUserId)
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
              let lastDocument = lastDocument,
              let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        isLoadingMore = true
        
        let query = db.collection("competitions")
            .document(competitionId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .start(afterDocument: lastDocument)
            .limit(to: pageSize)
        
        query.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleError(error)
                return
            }
            
            guard let documents = snapshot?.documents else {
                self.isLoadingMore = false
                return
            }
            
            self.lastDocument = documents.last
            self.hasMoreMessages = documents.count == self.pageSize
            
            let olderMessages = documents.compactMap { doc in
                ChatMessage(document: doc, currentUserId: currentUserId)
            }.reversed()
            
            DispatchQueue.main.async {
                self.messages.insert(contentsOf: olderMessages, at: 0)
                self.isLoadingMore = false
            }
        }
    }
    
    // MARK: - Helper Methods
    private func fetchCurrentUserInfo(completion: @escaping (String, String?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion("Unknown", nil)
            return
        }
        
        if let cached = userCache[currentUserId] {
            completion(cached.name, cached.profilePicture)
            return
        }
        
        db.collection("users").document(currentUserId).getDocument { [weak self] snapshot, error in
            guard let data = snapshot?.data() else {
                completion("Unknown", nil)
                return
            }
            
            let userName = data["username"] as? String ?? "Unknown"
            let profilePicture = data["profilePictureUrl"] as? String
            
            self?.userCache[currentUserId] = (userName, profilePicture)
            completion(userName, profilePicture)
        }
    }
    
    private func markMessagesAsRead() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let batch = db.batch()
        var hasUnreadMessages = false
        
        for message in messages where !message.isCurrentUser && !message.isRead {
            hasUnreadMessages = true
            let messageRef = db.collection("competitions")
                .document(competitionId)
                .collection("messages")
                .document(message.id)
            
            batch.updateData(["isRead": true], forDocument: messageRef)
        }
        
        if hasUnreadMessages {
            batch.commit()
        }
    }
    
    private func observeNetworkStatus() {
        // Network monitoring implementation
    }
    
    private func handleError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = error.localizedDescription
            self?.connectionStatus = .disconnected
        }
    }
    
    func cleanup() {
        // Remove listeners
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        
        // Clear caches to free memory
        userCache.removeAll()
        photoCache.removeAll()
        
        // Clear pending messages
        pendingMessages.removeAll()
    }
}
