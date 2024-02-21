import SwiftUI
import StoreKit
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Combine
import Flurry_iOS_SDK

class PbillViewModel: NSObject, ObservableObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    @Published var products: [SKProduct] = []
    @Published var purchaseCompleted: Bool = false
    @Published var isLoading: Bool = false

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
        guard let userID = Auth.auth().currentUser?.uid else {
            print("No logged-in user found!")
            return
        }
        let userDocRef = Firestore.firestore().collection("users").document(userID)
        userDocRef.updateData(["subscribed": true]) { error in
            DispatchQueue.main.async {
                self.isLoading = false
            }
            if let error = error {
                print("Error updating user data: \(error)")
            } else {
                print("User data successfully updated!")
                self.purchaseCompleted = true
                Flurry.log(eventName: "Subscription-Purchased")
            }
        }
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
                SKPaymentQueue.default().finishTransaction(transaction)
                DispatchQueue.main.async {
                    self.isLoading = false
                }
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
