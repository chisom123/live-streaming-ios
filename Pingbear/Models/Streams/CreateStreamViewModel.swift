import SwiftUI
import FirebaseAuth
import FirebaseFunctions
import Contacts
import UserNotifications
import Combine

// MARK: - CreateStreamViewModel
@MainActor
class CreateStreamViewModel: ObservableObject {

    @Published var selectedFriendIds:    Set<String> = []
    @Published var selectedOnAppIds:     Set<String> = []
    @Published var selectedOffAppHashes: Set<String> = []
    @Published var friendsSearchText:    String      = ""
    @Published var isSending                         = false
    @Published var errorMessage:         String?     = nil
    @Published var contactVM                         = ContactViewModel()

    @Published var notificationPermissionUndetermined: Bool? = nil

    private let functions  = Functions.functions()
    private var cancellables = Set<AnyCancellable>()

    init() {
        contactVM.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Filtered lists
    var filteredFriends: [FriendContact] {
        guard !friendsSearchText.isEmpty else { return contactVM.friends }
        return contactVM.friends.filter {
            $0.name.localizedCaseInsensitiveContains(friendsSearchText) ||
            $0.username.localizedCaseInsensitiveContains(friendsSearchText)
        }
    }

    var filteredOnAppContacts: [Contact] {
        guard !friendsSearchText.isEmpty else { return contactVM.onAppContacts }
        return contactVM.onAppContacts.filter {
            $0.fullName.localizedCaseInsensitiveContains(friendsSearchText) ||
            $0.username.localizedCaseInsensitiveContains(friendsSearchText)
        }
    }

    var filteredOffAppContacts: [Contact] {
        guard !friendsSearchText.isEmpty else { return contactVM.offAppContacts }
        return contactVM.offAppContacts.filter { $0.fullName.localizedCaseInsensitiveContains(friendsSearchText) }
    }

    var hasNoSearchResults: Bool {
        !friendsSearchText.isEmpty &&
        filteredFriends.isEmpty &&
        filteredOnAppContacts.isEmpty &&
        filteredOffAppContacts.isEmpty
    }

    var totalSelected: Int {
        selectedFriendIds.count + selectedOnAppIds.count + selectedOffAppHashes.count
    }

    var canCreate: Bool { totalSelected > 0 && !isSending }

    // MARK: - Notifications
    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationPermissionUndetermined = (settings.authorizationStatus == .notDetermined)
            }
        }
    }

    // MARK: - Create
    func createStream() async -> (streamId: String, token: String?, url: String?)? {
        guard canCreate else { return nil }
        isSending = true
        defer { isSending = false }

        let onAppContactUserIds = contactVM.onAppContacts
            .filter { selectedOnAppIds.contains($0.phoneNumber) }
            .compactMap { $0.userId }
        let allOnAppIds    = Array(selectedFriendIds) + onAppContactUserIds
        let offAppContacts = contactVM.offAppContacts.filter { selectedOffAppHashes.contains($0.phoneHash) }
        let offAppNamesMap = Dictionary(uniqueKeysWithValues: offAppContacts.map { ($0.phoneHash, $0.fullName) })

        let payload: [String: Any] = [
            "onAppInvitedIds":    allOnAppIds,
            "offAppPhoneHashes":  offAppContacts.map { $0.phoneHash },
            "offAppInviteeNames": offAppNamesMap
        ]

        do {
            let result = try await functions.httpsCallable("createStream").call(payload)
            guard let data     = result.data as? [String: Any],
                  let streamId = data["streamId"] as? String
            else { throw NSError(domain: "Stream", code: -1) }

            let token = data["token"]      as? String
            let url   = data["livekitUrl"] as? String

            Analytics.shared.trackStreamCreated(
                streamId:     streamId,
                invitedCount: allOnAppIds.count + offAppContacts.count
            )
            return (streamId: streamId, token: token, url: url)
        } catch {
            errorMessage = error.localizedDescription
            Analytics.shared.trackError(message: error.localizedDescription,
                                        properties: ["context": "create_stream"])
            return nil
        }
    }

    // MARK: - Toggles
    func toggleFriend(_ id: String) {
        if selectedFriendIds.contains(id) { selectedFriendIds.remove(id) }
        else { selectedFriendIds.insert(id); UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    func toggleOnApp(_ id: String) {
        if selectedOnAppIds.contains(id) { selectedOnAppIds.remove(id) }
        else { selectedOnAppIds.insert(id); UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    func toggleOffApp(_ hash: String) {
        if selectedOffAppHashes.contains(hash) { selectedOffAppHashes.remove(hash) }
        else { selectedOffAppHashes.insert(hash); UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }
}
