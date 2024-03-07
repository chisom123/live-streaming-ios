import SwiftUI
import StoreKit
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Combine
import PostHog

class PbillViewModel: NSObject, ObservableObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    @Published var products: [SKProduct] = []
    @Published var purchaseCompleted: Bool = false
    @Published var isLoading: Bool = false

    var competitionId: String = "" // Add this line
    var entryDocId: String = "" // Add this line
    
    private var productIdentifiers: Set<String> = ["superstar"]

    override init() {
        super.init()
        fetchProducts()
        SKPaymentQueue.default().add(self)
    }

    private func fetchProducts() {
        let request = SKProductsRequest(productIdentifiers: productIdentifiers)
        request.delegate = self
        request.start()
    }

    func purchase(product: SKProduct) {
        DispatchQueue.main.async {
            self.isLoading = true
        }
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

    private func handleCompletedPayment(transaction: SKPaymentTransaction) {
        // Check if the user is logged in before attempting to update Firestore.
        guard let userID = Auth.auth().currentUser?.uid else {
            print("No logged-in user found!")
            return
        }
        
        // Check if competitionId and entryDocId have been set properly.
        guard !self.competitionId.isEmpty, !self.entryDocId.isEmpty else {
            print("Competition ID or Entry Document ID is not set.")
            return
        }

        // Reference to the specific Firestore document.
        let entriesDocRef = Firestore.firestore()
                                    .collection("competitions")
                                    .document(self.competitionId)
                                    .collection("entries")
                                    .document(self.entryDocId)
        
        // Update the document in Firestore.
        entriesDocRef.updateData(["superstar": true]) { [weak self] error in
            guard let self = self else { return } // Check for self capture to avoid memory leaks
            
            DispatchQueue.main.async {
                self.isLoading = false // Stop loading irrespective of error
            }

            if let error = error {
                print("Error updating entry data: \(error)")
            } else {
                print("Entry data successfully updated to set superstar true!")
                // Only set purchaseCompleted to true if the update was successful.
                self.purchaseCompleted = true
                PostHogSDK.shared.capture("Superstar Purchased!")
            }
        }
        
        // Finish the transaction after all updates are attempted.
        SKPaymentQueue.default().finishTransaction(transaction)
    }

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            self.products = response.products
        }
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                handleCompletedPayment(transaction: transaction)
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                SKPaymentQueue.default().finishTransaction(transaction)
            case .failed:
                // Handle failed transaction
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                SKPaymentQueue.default().finishTransaction(transaction)
            case .restored:
                // Handle restored transaction if your app supports it
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                SKPaymentQueue.default().finishTransaction(transaction)
            default:
                break
            }
        }
    }
}
