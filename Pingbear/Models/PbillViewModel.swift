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
        guard let userID = Auth.auth().currentUser?.uid, !self.competitionId.isEmpty, !self.entryDocId.isEmpty else {
            print("Validation failed!")
            return
        }

        let entriesDocRef = Firestore.firestore()
                                    .collection("competitions")
                                    .document(self.competitionId)
                                    .collection("entries")
                                    .document(self.entryDocId)
        
        entriesDocRef.getDocument { (document, error) in
            if let document = document, document.exists {
                let data = document.data() as? [String: Bool] ?? [:]
                if data["superstar"] == true {
                    print("Already a superstar, no need to update.")
                    return
                }
            }

            entriesDocRef.updateData(["superstar": true]) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    print("Error updating entry data: \(error)")
                } else {
                    self.purchaseCompleted = true
                    PostHogSDK.shared.capture("Superstar Purchased!")
                    
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }
            }
        }
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
