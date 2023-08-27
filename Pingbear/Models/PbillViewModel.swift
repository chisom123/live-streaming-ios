import SwiftUI
import StoreKit
import Firebase
import FirebaseAuth
import FirebaseFirestore

class PbillViewModel: NSObject, ObservableObject {
    @Published var products: [SKProduct] = []
    private var productIdentifiers: Set<String> = ["Bill1", "Bill2", "Bill3", "Bill4"]

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

    func imageName(for product: SKProduct) -> String {
        switch product.productIdentifier {
            case "Bill1": return "Stack1"
            case "Bill2": return "Stack2"
            case "Bill3": return "Stack3"
            case "Bill4": return "Stack4"
            default: return "Stack1"
        }
    }

    func purchase(product: SKProduct) {
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

    // Handle completed payment
    private func handleCompletedPayment(transaction: SKPaymentTransaction) {
        let pbillAmount = amountForProductIdentifier(transaction.payment.productIdentifier)
        
        // Get the current user's ID from Firebase Authentication
        guard let userID = Auth.auth().currentUser?.uid else {
            print("No logged-in user found!")
            return
        }
        
        // Access the user's document in the "users" collection using the userID
        let userDocRef = Firestore.firestore().collection("users").document(userID)
        
        // Update the user's P-Bills in Firestore
        userDocRef.updateData([
            "pBills": FieldValue.increment(Int64(pbillAmount))
        ]) { error in
            if let error = error {
                print("Error updating P-Bills: \(error)")
            } else {
                print("P-Bills successfully updated!")
            }
        }
    }

    private func amountForProductIdentifier(_ identifier: String) -> Int {
        switch identifier {
        case "Bill1": return 100
        case "Bill2": return 200
        case "Bill3": return 300
        case "Bill4": return 400
        default: return 0
        }
    }
}

extension PbillViewModel: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            self.products = response.products
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
            case .failed:
                // Handle failed transaction
                SKPaymentQueue.default().finishTransaction(transaction)
            case .restored:
                // Handle restored transaction if your app supports it
                SKPaymentQueue.default().finishTransaction(transaction)
            default:
                break
            }
        }
    }
}
