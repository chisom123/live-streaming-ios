import Foundation
import FirebaseFirestore
import UIKit

// ─────────────────────────────────────────────────────────────
// MARK: - Friend
// ─────────────────────────────────────────────────────────────

struct Friend: Identifiable {
    let id: String
    let name: String
    let username: String
    let profilePictureUrl: String?
}

// ─────────────────────────────────────────────────────────────
// MARK: - UserProfile
// ─────────────────────────────────────────────────────────────

struct UserProfile: Identifiable {
    let id:                String
    let name:              String
    let username:          String
    let profilePictureUrl: String?
    let totalEarned:       Double
}
