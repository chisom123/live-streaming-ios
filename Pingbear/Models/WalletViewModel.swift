import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
class WalletViewModel: ObservableObject {
    @Published var balance: Double = 0.0
    @Published var withdrawals: [Withdrawal] = []
    @Published var isLoading = false
    @Published var showCashOutSheet = false
    
    private let db = Firestore.firestore()
    
    func loadWalletData() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        Task {
            do {
                // Load balance
                let userDoc = try await db.collection("users").document(userId).getDocument()
                self.balance = userDoc.data()?["wallet_balance"] as? Double ?? 0.0
                
                // Load withdrawals
                await loadWithdrawals(userId: userId)
                
                isLoading = false
            } catch {
                print("Error loading wallet: \(error)")
                isLoading = false
            }
        }
    }
    
    private func loadWithdrawals(userId: String) async {
        do {
            let snapshot = try await db.collection("withdrawals")
                .whereField("user_id", isEqualTo: userId)
                .order(by: "requested_at", descending: true)
                .getDocuments()
            
            self.withdrawals = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let amount = data["amount"] as? Double,
                      let status = data["status"] as? String,
                      let requestedAt = data["requested_at"] as? Timestamp else {
                    return nil
                }
                
                return Withdrawal(
                    id: doc.documentID,
                    amount: amount,
                    status: status,
                    requestedAt: requestedAt.dateValue(),
                    processedAt: (data["processed_at"] as? Timestamp)?.dateValue(),
                    rejectionReason: data["rejection_reason"] as? String
                )
            }
        } catch {
            print("Error loading withdrawals: \(error)")
        }
    }
    
    func processCashOut(paymentMethod: String, details: [String: String]) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            do {
                // Create withdrawal request
                let withdrawalRef = db.collection("withdrawals").document()
                
                try await withdrawalRef.setData([
                    "user_id": userId,
                    "amount": balance,
                    "payment_method": paymentMethod,
                    "paypal_email": details["email"] ?? "",
                    "status": "pending",
                    "requested_at": FieldValue.serverTimestamp()
                ])
                
                // Deduct from wallet
                try await db.collection("users").document(userId).updateData([
                    "wallet_balance": 0
                ])
                
                // Update local state
                balance = 0.0
                showCashOutSheet = false
                
                // Reload to show new withdrawal
                await loadWalletData()
                
            } catch {
                print("Error processing cash out: \(error)")
            }
        }
    }
}

// Models
struct Withdrawal: Identifiable {
    let id: String
    let amount: Double
    let status: String // "pending", "completed", "rejected"
    let requestedAt: Date
    let processedAt: Date?
    let rejectionReason: String?
}
