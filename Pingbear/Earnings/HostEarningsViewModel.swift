import FirebaseAuth
import FirebaseFirestore

class HostEarningsViewModel: ObservableObject {
    @Published var totalEarnings: Double = 0.0
    @Published var availableEarnings: Double = 0.0
    @Published var paidOutEarnings: Double = 0.0
    @Published var pendingPayoutEarnings: Double = 0.0
    @Published var purchases: [PurchaseRecord] = []
    @Published var payoutRequests: [PayoutRequest] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingPayouts: Bool = false
    @Published var isHost: Bool = false
    @Published var requestingPayout: Bool = false
    
    private var db = Firestore.firestore()
    private var competitionId: String? = nil
    
    // Fetch earnings for a specific competition
    func fetchEarnings(for competitionId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        self.competitionId = competitionId
        isLoading = true
        
        // First check if the current user is the host
        db.collection("competitions").document(competitionId).getDocument { [weak self] document, error in
            guard let self = self, let document = document, document.exists else {
                self?.isLoading = false
                return
            }
            
            if let data = document.data(), let hostId = data["hostId"] as? String {
                self.isHost = (hostId == currentUserId)
                
                // Only proceed to fetch earnings if the user is the host
                if self.isHost {
                    self.fetchPurchases(for: competitionId)
                    self.fetchPayoutRequests(for: currentUserId, competitionId: competitionId)
                } else {
                    self.isLoading = false
                }
            } else {
                self.isLoading = false
            }
        }
    }
    
    private func fetchPurchases(for competitionId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("competitions")
            .document(competitionId)
            .collection("purchases")
            .getDocuments { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching purchases: \(error)")
                    self.isLoading = false
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    self.isLoading = false
                    return
                }
                
                // Process the purchases, filtering out the host's purchases
                self.purchases = documents.compactMap { document in
                    let data = document.data()
                    
                    guard let userId = data["userId"] as? String,
                          let productId = data["productId"] as? String,
                          let timestamp = data["timestamp"] as? Timestamp,
                          let hostShare = data["hostShare"] as? Double else {
                        return nil
                    }
                    
                    // Filter out purchases made by the current user (the host)
                    if userId != currentUserId {
                        return PurchaseRecord(
                            id: document.documentID,
                            userId: userId,
                            productId: productId,
                            timestamp: timestamp.dateValue(),
                            hostShare: hostShare
                        )
                    }
                    
                    return nil
                }
                
                // Sort purchases by date (newest first)
                self.purchases.sort { $0.timestamp > $1.timestamp }
                
                // Once we have purchases, fetch payouts to calculate proper totals
                if let userId = Auth.auth().currentUser?.uid {
                    self.fetchPayoutRequests(for: userId, competitionId: competitionId)
                } else {
                    self.calculateTotals()
                    self.isLoading = false
                }
            }
    }
    
    // Fetch payout requests for the current user and current competition
    func fetchPayoutRequests(for userId: String, competitionId: String) {
        isLoadingPayouts = true
        
        db.collection("payoutRequests")
            .whereField("userId", isEqualTo: userId)
            .whereField("competitionId", isEqualTo: competitionId)
            .order(by: "requestDate", descending: true)
            .getDocuments { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching payout requests: \(error)")
                    self.isLoadingPayouts = false
                    self.isLoading = false
                    return
                }
                
                self.payoutRequests = querySnapshot?.documents.compactMap { document in
                    PayoutRequest(id: document.documentID, data: document.data())
                } ?? []
                
                // Now calculate totals with both purchases and payout requests
                self.calculateTotals()
                
                self.isLoadingPayouts = false
                self.isLoading = false
            }
    }
    
    // Refresh earnings data
    func refreshData() {
        if let competitionId = competitionId, isHost, let userId = Auth.auth().currentUser?.uid {
            isLoading = true
            fetchPurchases(for: competitionId)
        }
    }
    
    private func calculateTotals() {
        // Calculate total earnings from all purchases
        let totalPurchaseAmount = purchases.reduce(0) { $0 + $1.hostShare }
        
        // Group payout requests by status
        var completedPayouts: Double = 0
        var pendingPayouts: Double = 0
        
        for payout in payoutRequests {
            switch payout.status {
            case .completed:
                completedPayouts += payout.amount
            case .pending, .processing:
                pendingPayouts += payout.amount
            case .rejected:
                // Rejected payouts go back to available
                break
            }
        }
        
        // Calculate available earnings (total - (completed + pending))
        let availableAmount = max(0, totalPurchaseAmount - completedPayouts - pendingPayouts)
        
        // Ensure we're not showing negative or very small amounts due to floating point errors
        self.totalEarnings = max(0, totalPurchaseAmount.rounded(to: 2))
        self.availableEarnings = availableAmount.rounded(to: 2)
        self.paidOutEarnings = completedPayouts.rounded(to: 2)
        self.pendingPayoutEarnings = pendingPayouts.rounded(to: 2)
    }
    
    // Create a payout request
    func requestPayout(paypalEmail: String, completion: @escaping (Bool, String?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid, let competitionId = competitionId else {
            completion(false, "User not authenticated")
            return
        }
        
        if availableEarnings <= 0 {
            completion(false, "No funds available for payout")
            return
        }
        
        requestingPayout = true
        
        // Create payout request document
        let payoutRequestRef = db.collection("payoutRequests").document()
        let payoutRequest = [
            "userId": userId,
            "competitionId": competitionId,
            "amount": availableEarnings,
            "paypalEmail": paypalEmail,
            "requestDate": Timestamp(date: Date()),
            "status": PayoutRequest.PayoutStatus.pending.rawValue
        ] as [String: Any]
        
        payoutRequestRef.setData(payoutRequest) { [weak self] error in
            guard let self = self else { return }
            
            self.requestingPayout = false
            
            if let error = error {
                print("Error requesting payout: \(error)")
                completion(false, "Failed to submit payout request: \(error.localizedDescription)")
                return
            }
            
            // Refresh data after successful payout request
            self.refreshData()
            completion(true, nil)
        }
    }
}

// Extension for rounding Double to specified decimal places
extension Double {
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

// Model for purchase records - removed 'paid' field
struct PurchaseRecord: Identifiable {
    let id: String
    let userId: String
    let productId: String
    let timestamp: Date
    let hostShare: Double
    
    // Computed property for formatted product name
    var formattedProductName: String {
        switch productId {
        case "one_day_boost":
            return "1 Day Boost"
        case "one_week_boost":
            return "1 Week Boost"
        case "one_hour_boost":
            return "1 Hour Boost"
        default:
            return productId
        }
    }
    
    // Computed property for formatted date
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
