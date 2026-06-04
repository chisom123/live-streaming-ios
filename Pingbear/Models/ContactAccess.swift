import Contacts
import FirebaseAuth
import FirebaseFirestore
import PhoneNumberKit
import CryptoKit
import UIKit

struct Contact: Identifiable {
    var id: String { phoneNumber }
    var firstName: String
    var lastName: String
    var username: String
    var phoneNumber: String        // raw E.164 for iMessage
    var phoneHash: String          // hashed for Firestore
    var profileImageUrl: String?   // in-app profile pic (on-app contacts)
    var contactImage: UIImage?     // device contacts photo (off-app contacts)
    var isAdded: Bool = false
    var isOnApp: Bool = false

    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

class ContactViewModel: ObservableObject {
    @Published var onAppContacts: [Contact]      = []
    @Published var offAppContacts: [Contact]     = []
    @Published var selectedToInvite: Set<String> = []
    @Published var searchText: String            = ""
    @Published var isLoading: Bool               = false
    @Published var permissionDenied: Bool         = false

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
        let store = CNContactStore()
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            Analytics.shared.track(event: "contacts_permission_already_granted")
            fetchAndResolveContacts()
        case .notDetermined:
            store.requestAccess(for: .contacts) { granted, _ in
                DispatchQueue.main.async {
                    if granted {
                        Analytics.shared.track(event: "contacts_permission_granted")
                        self.fetchAndResolveContacts()
                    } else {
                        Analytics.shared.track(event: "contacts_permission_denied")
                        self.permissionDenied = true
                    }
                }
            }
        case .denied:
            Analytics.shared.track(event: "contacts_permission_previously_denied")
            DispatchQueue.main.async { self.permissionDenied = true }
        case .restricted:
            Analytics.shared.track(event: "contacts_permission_restricted")
            DispatchQueue.main.async { self.permissionDenied = true }
        @unknown default:
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

    /// Write a single invite_groups doc containing all selected contacts + the inviter.
    func writePendingInvites(completion: @escaping () -> Void) {
        guard let currentUser = Auth.auth().currentUser else { completion(); return }

        let selectedContacts = offAppContacts.filter { selectedToInvite.contains($0.phoneHash) }
        guard !selectedContacts.isEmpty else { completion(); return }

        db.collection("users").document(currentUser.uid).getDocument { [weak self] snap, _ in
            guard let self = self else { completion(); return }

            let inviterHash   = snap?.data()?["phoneNumberHash"] as? String ?? ""
            let inviteeHashes = selectedContacts.map { $0.phoneHash }

            var allHashes = inviteeHashes
            if !inviterHash.isEmpty { allHashes.append(inviterHash) }

            let docRef = self.db.collection("invite_groups").document()
            docRef.setData([
                "memberHashes":  allHashes,
                "memberUserIds": [inviterHash: currentUser.uid],
                "createdAt":     FieldValue.serverTimestamp()
            ]) { error in
                if let error = error {
                    print("writePendingInvites error: \(error.localizedDescription)")
                }
                completion()
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
            // Fetch name, phone, and thumbnail image from device contacts
            let keys    = [
                CNContactGivenNameKey,
                CNContactFamilyNameKey,
                CNContactPhoneNumbersKey,
                CNContactThumbnailImageDataKey
            ] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)

            // Collect all contacts with valid E.164 numbers, deduped by hash
            var seen   = Set<String>()
            var raw: [(e164: String, hash: String, firstName: String, lastName: String, image: UIImage?)] = []

            do {
                try store.enumerateContacts(with: request) { contact, _ in
                    for phone in contact.phoneNumbers {
                        guard let e164 = self.formatE164(phone.value.stringValue) else { continue }
                        let hash = self.hashPhoneNumber(e164)
                        guard !seen.contains(hash) else { continue }
                        seen.insert(hash)

                        var image: UIImage? = nil
                        if let data = contact.thumbnailImageData {
                            image = UIImage(data: data)
                        }

                        raw.append((e164, hash, contact.givenName, contact.familyName, image))
                    }
                }
            } catch {
                print("fetchContacts error: \(error)")
                DispatchQueue.main.async { self.isLoading = false }
                return
            }

            // Batch Firestore lookups in chunks of 10 (Firestore `in` query limit)
            let chunks = stride(from: 0, to: raw.count, by: 10).map {
                Array(raw[$0..<min($0 + 10, raw.count)])
            }

            let dispatchGroup = DispatchGroup()
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

                        // Build a hash → Firestore doc map for this chunk
                        var hashToDoc: [String: QueryDocumentSnapshot] = [:]
                        for doc in snap?.documents ?? [] {
                            if let h = doc.data()["phoneNumberHash"] as? String {
                                hashToDoc[h] = doc
                            }
                        }

                        for item in chunk {
                            if let doc = hashToDoc[item.hash],
                               !self.currentUserFriends.contains(doc.documentID),
                               doc.documentID != Auth.auth().currentUser?.uid {
                                // On the app
                                let data    = doc.data()
                                let contact = Contact(
                                    firstName: item.firstName, lastName: item.lastName,
                                    username: data["username"] as? String ?? "",
                                    phoneNumber: item.e164, phoneHash: item.hash,
                                    profileImageUrl: data["profilePictureUrl"] as? String,
                                    contactImage: item.image,
                                    isAdded: false, isOnApp: true
                                )
                                lock.lock(); onApp.append(contact); lock.unlock()
                            } else if hashToDoc[item.hash] == nil {
                                // Not on the app
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
                // Sort alphabetically
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
