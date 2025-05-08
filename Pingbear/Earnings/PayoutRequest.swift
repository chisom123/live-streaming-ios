import FirebaseFirestore

// Model for payout requests
struct PayoutRequest: Identifiable {
    let id: String
    let userId: String
    let competitionId: String  // Added competitionId
    let amount: Double
    let paypalEmail: String
    let requestDate: Date
    let status: PayoutStatus
    let processedDate: Date?
    
    // Status enum for payout requests
    enum PayoutStatus: String, CaseIterable {
        case pending = "pending"
        case processing = "processing"
        case completed = "completed"
        case rejected = "rejected"
        
        var displayName: String {
            switch self {
            case .pending:
                return "Pending"
            case .processing:
                return "Processing"
            case .completed:
                return "Completed"
            case .rejected:
                return "Rejected"
            }
        }
        
        var statusColor: String {
            switch self {
            case .pending:
                return "#FFC107" // Yellow
            case .processing:
                return "#2196F3" // Blue
            case .completed:
                return "#4CAF50" // Green
            case .rejected:
                return "#F44336" // Red
            }
        }
    }
    
    // Formatted date string
    var formattedRequestDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: requestDate)
    }
    
    // Formatted processed date string (if available)
    var formattedProcessedDate: String {
        guard let processedDate = processedDate else { return "N/A" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: processedDate)
    }
    
    // Format amount as USD
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.currencySymbol = "$" // Add this line
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
    
    // Initialize from Firestore data
    init?(id: String, data: [String: Any]) {
        guard let userId = data["userId"] as? String,
              let competitionId = data["competitionId"] as? String,
              let amount = data["amount"] as? Double,
              let paypalEmail = data["paypalEmail"] as? String,
              let requestDate = (data["requestDate"] as? Timestamp)?.dateValue(),
              let statusRaw = data["status"] as? String,
              let status = PayoutStatus(rawValue: statusRaw) else {
            return nil
        }
        
        self.id = id
        self.userId = userId
        self.competitionId = competitionId
        self.amount = amount
        self.paypalEmail = paypalEmail
        self.requestDate = requestDate
        self.status = status
        self.processedDate = (data["processedDate"] as? Timestamp)?.dateValue()
    }
    
    // Create dictionary for Firestore
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "userId": userId,
            "competitionId": competitionId,
            "amount": amount,
            "paypalEmail": paypalEmail,
            "requestDate": Timestamp(date: requestDate),
            "status": status.rawValue
        ]
        
        if let processedDate = processedDate {
            dict["processedDate"] = Timestamp(date: processedDate)
        }
        
        return dict
    }
}
