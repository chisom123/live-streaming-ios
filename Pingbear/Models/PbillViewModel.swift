import SwiftUI
import StoreKit
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Combine
import Flurry_iOS_SDK

class PbillViewModel: NSObject, ObservableObject {
    @Published var products: [SKProduct] = []
    @Published var purchaseCompleted: Bool = false
    @Published var isLoading: Bool = false

    private var productIdentifiers: Set<String> = ["Bill1", "Bill2", "Bill3", "Bill4", "sup1"]

    override init() {
        super.init()
        fetchProducts()
        SKPaymentQueue.default().add(self)  // Start observing the payment queue
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

    // Handle completed payment
    private func handleCompletedPayment(transaction: SKPaymentTransaction) {
        
        // Get the current user's ID from Firebase Authentication
        guard let userID = Auth.auth().currentUser?.uid else {
            print("No logged-in user found!")
            return
        }
        
        // Access the user's document in the "users" collection using the userID
        let userDocRef = Firestore.firestore().collection("users").document(userID)
        
        // Update the user's P-Bills in Firestore
        userDocRef.updateData([
            "subscribed": true  // Directly assigning the boolean value true
        ]) { error in
            DispatchQueue.main.async {
                self.isLoading = false // Set isLoading to false here
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

    private func amountForProductIdentifier(_ identifier: String) -> Int {
        switch identifier {
        case "Bill1": return 900
        case "Bill2": return 2300
        case "Bill3": return 4000
        case "Bill4": return 11000
        default: return 0
        }
    }
}

extension PbillViewModel: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            self.products = response.products.sorted(by: {
                self.amountForProductIdentifier($0.productIdentifier) < self.amountForProductIdentifier($1.productIdentifier)
            })
        }
    }
}

extension PbillViewModel: SKPaymentTransactionObserver {
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
