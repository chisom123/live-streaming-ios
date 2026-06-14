import Contacts
import FirebaseAuth
import FirebaseFirestore
import PhoneNumberKit
import CryptoKit
import UIKit

// ─────────────────────────────────────────────────────────────
// MARK: - Contact
// ─────────────────────────────────────────────────────────────

struct Contact: Identifiable {
    var id:              String { phoneNumber }
    var firstName:       String
    var lastName:        String
    var username:        String
    var phoneNumber:     String        // raw E.164 for iMessage
    var phoneHash:       String        // hashed for Firestore
    var userId:          String?       // Firebase UID for on-app contacts
    var profileImageUrl: String?       // in-app profile pic (on-app contacts)
    var contactImage:    UIImage?      // device contacts photo (off-app contacts)
    var isAdded:         Bool  = false
    var isOnApp:         Bool  = false

    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - FriendContact
// ─────────────────────────────────────────────────────────────

struct FriendContact: Identifiable {
    let id:                String    // userId
    let name:              String
    let username:          String
    let profilePictureUrl: String?
}

// ─────────────────────────────────────────────────────────────
// MARK: - ContactViewModel
// ─────────────────────────────────────────────────────────────

class ContactViewModel: ObservableObject {

    @Published var friends:          [FriendContact] = []
    @Published var onAppContacts:    [Contact]        = []
    @Published var offAppContacts:   [Contact]        = []
    @Published var selectedToInvite: Set<String>      = []
    @Published var searchText:       String           = ""
    @Published var isLoading:        Bool             = false
    @Published var permissionDenied: Bool             = false

    var filteredFriends: [FriendContact] {
        guard !searchText.isEmpty else { return friends }
        return friends.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredOnApp: [Contact] {
        guard !searchText.isEmpty else { return onAppContacts }
        return onAppContacts.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredOffApp: [Contact] {
        guard !searchText.isEmpty else { return offAppContacts }
        return offAppContacts.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
    }

    private let db             = Firestore.firestore()
    private let phoneNumberKit = PhoneNumberKit()
    private var currentUserFriends: Set<String> = []
    private let salt = "5Ax1HpaMDwxIv15M6t4ZdGuC8"

    init() { fetchCurrentUserFriends() }

    // MARK: - Public

    func requestContactAccess() {
        fetchFriendsFromFirestore()
        let store = CNContactStore()
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            fetchAndResolveContacts()
        case .notDetermined:
            store.requestAccess(for: .contacts) { granted, _ in
                DispatchQueue.main.async {
                    if granted {
                        Analytics.shared.track(event: AnalyticsEvent.contactsPermissionGranted, properties: [:])
                        self.fetchAndResolveContacts()
                    } else {
                        Analytics.shared.track(event: AnalyticsEvent.contactsPermissionDenied, properties: [:])
                        self.permissionDenied = true
                    }
                }
            }
        default:
            DispatchQueue.main.async { self.permissionDenied = true }
        }
    }

    func toggleInviteSelection(for contact: Contact) {
        if selectedToInvite.contains(contact.phoneHash) {
            selectedToInvite.remove(contact.phoneHash)
        } else {
            selectedToInvite.insert(contact.phoneHash)
        }
    }

    /// Write invite_groups doc for off-app contacts.
    /// No competitionId — purely for friendship resolution on signup.
    /// For transaction-linked invites, pendingTransactionIds are written
    /// by the sendTransaction Cloud Function directly.
    func writePendingInvites(completion: @escaping () -> Void) {
        guard let currentUser = Auth.auth().currentUser else { completion(); return }

        let selectedContacts = offAppContacts.filter { selectedToInvite.contains($0.phoneHash) }
        guard !selectedContacts.isEmpty else { completion(); return }

        db.collection("users").document(currentUser.uid).getDocument { [weak self] snap, _ in
            guard let self else { completion(); return }

            let inviterHash   = snap?.data()?["phoneNumberHash"] as? String ?? ""
            let inviteeHashes = selectedContacts.map { $0.phoneHash }

            var allHashes = inviteeHashes
            if !inviterHash.isEmpty { allHashes.append(inviterHash) }

            let data: [String: Any] = [
                "memberHashes":          allHashes,
                "memberUserIds":         inviterHash.isEmpty ? [:] : [inviterHash: currentUser.uid],
                "pendingTransactionIds": [],   // no pending transactions — pure friendship invite
                "createdAt":             FieldValue.serverTimestamp()
            ]

            self.db.collection("invite_groups").document().setData(data) { error in
                if let error { print("writePendingInvites error: \(error.localizedDescription)") }
                completion()
            }
        }
    }

    // MARK: - Fetch friends from Firestore

    func fetchFriendsFromFirestore() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users").document(uid).collection("friends").getDocuments { [weak self] snap, _ in
            guard let self else { return }
            let ids = snap?.documents.map(\.documentID) ?? []
            self.currentUserFriends = Set(ids)
            guard !ids.isEmpty else { return }

            let chunks = stride(from: 0, to: ids.count, by: 30).map {
                Array(ids[$0..<min($0 + 30, ids.count)])
            }
            var fetched: [FriendContact] = []
            let group = DispatchGroup()

            for chunk in chunks {
                group.enter()
                self.db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments { snap, _ in
                        defer { group.leave() }
                        let batch = snap?.documents.compactMap { doc -> FriendContact? in
                            let data = doc.data()
                            guard let name = data["name"] as? String else { return nil }
                            return FriendContact(
                                id:                doc.documentID,
                                name:              name,
                                username:          data["username"] as? String ?? "",
                                profilePictureUrl: data["profilePictureUrl"] as? String
                            )
                        } ?? []
                        fetched.append(contentsOf: batch)
                    }
            }

            group.notify(queue: .main) {
                self.friends = fetched.sorted { $0.name < $1.name }
            }
        }
    }

    // MARK: - Fetch contacts + batch resolve

    private func fetchCurrentUserFriends() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("friends").getDocuments { [weak self] snap, _ in
            self?.currentUserFriends = Set(snap?.documents.compactMap { $0.documentID } ?? [])
        }
    }

    private func fetchAndResolveContacts() {
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async { self.isLoading = true }

            let store   = CNContactStore()
            let keys    = [
                CNContactGivenNameKey,
                CNContactFamilyNameKey,
                CNContactPhoneNumbersKey,
                CNContactThumbnailImageDataKey
            ] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)

            var seen = Set<String>()
            var raw: [(e164: String, hash: String, firstName: String, lastName: String, image: UIImage?)] = []

            do {
                try store.enumerateContacts(with: request) { contact, _ in
                    for phone in contact.phoneNumbers {
                        guard let e164 = self.formatE164(phone.value.stringValue) else { continue }
                        let hash = self.hashPhoneNumber(e164)
                        guard !seen.contains(hash) else { continue }
                        seen.insert(hash)
                        var image: UIImage? = nil
                        if let data = contact.thumbnailImageData { image = UIImage(data: data) }
                        raw.append((e164, hash, contact.givenName, contact.familyName, image))
                    }
                }
            } catch {
                print("fetchContacts error: \(error)")
                DispatchQueue.main.async { self.isLoading = false }
                return
            }

            let chunks         = stride(from: 0, to: raw.count, by: 10).map { Array(raw[$0..<min($0 + 10, raw.count)]) }
            let dispatchGroup  = DispatchGroup()
            var onApp:  [Contact] = []
            var offApp: [Contact] = []
            let lock = NSLock()

            for chunk in chunks {
                dispatchGroup.enter()
                let hashes = chunk.map { $0.hash }
                self.db.collection("users")
                    .whereField("phoneNumberHash", in: hashes)
                    .getDocuments { snap, _ in
                        defer { dispatchGroup.leave() }

                        var hashToDoc: [String: QueryDocumentSnapshot] = [:]
                        for doc in snap?.documents ?? [] {
                            if let h = doc.data()["phoneNumberHash"] as? String { hashToDoc[h] = doc }
                        }

                        for item in chunk {
                            if let doc = hashToDoc[item.hash],
                               !self.currentUserFriends.contains(doc.documentID),
                               doc.documentID != Auth.auth().currentUser?.uid {
                                let data = doc.data()
                                let contact = Contact(
                                    firstName:       item.firstName,
                                    lastName:        item.lastName,
                                    username:        data["username"] as? String ?? "",
                                    phoneNumber:     item.e164,
                                    phoneHash:       item.hash,
                                    userId:          doc.documentID,
                                    profileImageUrl: data["profilePictureUrl"] as? String,
                                    contactImage:    item.image,
                                    isAdded:         false,
                                    isOnApp:         true
                                )
                                lock.lock(); onApp.append(contact); lock.unlock()
                            } else if hashToDoc[item.hash] == nil {
                                let contact = Contact(
                                    firstName: item.firstName, lastName: item.lastName,
                                    username: "", phoneNumber: item.e164, phoneHash: item.hash,
                                    profileImageUrl: nil, contactImage: item.image,
                                    isAdded: false, isOnApp: false
                                )
                                lock.lock(); offApp.append(contact); lock.unlock()
                            }
                        }
                    }
            }

            dispatchGroup.notify(queue: .main) {
                self.onAppContacts  = onApp.sorted  { $0.fullName < $1.fullName }
                self.offAppContacts = offApp.sorted { $0.fullName < $1.fullName }
                self.isLoading = false
            }
        }
    }

    // MARK: - Helpers

    private func formatE164(_ raw: String) -> String? {
        try? phoneNumberKit.format(phoneNumberKit.parse(raw), toType: .e164)
    }

    private func hashPhoneNumber(_ e164: String) -> String {
        let digits = e164.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let hash   = SHA256.hash(data: Data((salt + digits).utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
