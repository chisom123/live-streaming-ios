import Foundation

struct Withdrawal: Identifiable {
    let id: String
    let amount: Double
    let status: String          // "pending" | "completed" | "rejected"
    let requestedAt: Date
    let processedAt: Date?
    let rejectionReason: String?
    let paypalEmail: String
}
