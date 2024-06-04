import SwiftUI
import StoreKit
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Combine
import PostHog

class PayViewModel: NSObject, ObservableObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    @Published var products: [SKProduct] = []
    @Published var purchaseCompleted: Bool = false
    @Published var isLoading: Bool = false
    
    var competitionId: String = "" // Add this line
    var entryDocId: String = "" // Add this line
    
    private var productIdentifiers: Set<String> = ["one_day_boost", "one_month_boost", "one_week_boost"]

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
            PostHogSDK.shared.capture("Purchase Attempt", properties: ["productID": product.productIdentifier])
        }
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

    private func handleCompletedPayment(transaction: SKPaymentTransaction) {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("Validation failed")
            PostHogSDK.shared.capture("Validation Failed", properties: ["productID": transaction.payment.productIdentifier])
            return
        }
        
        let userDocRef = Firestore.firestore().collection("users").document(userID)
        
        let currentDate = Date()
        var expirationDate = currentDate

        switch transaction.payment.productIdentifier {
        case "one_day_boost":
            expirationDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        case "one_week_boost":
            expirationDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentDate)!
        case "one_month_boost":
            expirationDate = Calendar.current.date(byAdding: .month, value: 1, to: currentDate)!
        default:
            print("Unknown or unsupported product identifier")
            PostHogSDK.shared.capture("Unsupported Product Identifier", properties: ["productID": transaction.payment.productIdentifier])
            return
        }
        
        // Updating Firestore with the expiration timestamp for the boost
        userDocRef.updateData(["boost": expirationDate]) { [weak self] error in
            if let error = error {
                print("Error updating user boost data: \(error)")
                PostHogSDK.shared.capture("Boost Data Update Failed", properties: ["error": error.localizedDescription])
                return
            }

            // Assume `self.competitionId` and `self.entryDocId` are valid IDs you have access to.
            let entriesDocRef = Firestore.firestore()
                                            .collection("competitions")
                                            .document(self?.competitionId ?? "")
                                            .collection("entries")
                                            .document(self?.entryDocId ?? "")

            // Check if the entry is already a superstar, if not, update it.
            entriesDocRef.getDocument { (document, error) in
                if let document = document, document.exists {
                    if let data = document.data(), data["superstar"] as? Bool == true {
                        print("Already a superstar, no need to update.")
                        return
                    }
                }

                // Update the superstar status in the entries document
                entriesDocRef.updateData(["superstar": true]) { error in
                    if let error = error {
                        print("Error updating entry to superstar: \(error)")
                        PostHogSDK.shared.capture("Superstar Status Update Failed", properties: ["error": error.localizedDescription])
                        return
                    }
                    
                    guard let self = self else { return }
                    self.purchaseCompleted = true
                    PostHogSDK.shared.capture("\(transaction.payment.productIdentifier) Purchased", properties: ["status": "Superstar set"])
                    
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
            PostHogSDK.shared.capture("Products Fetched", properties: ["productIDs": self.products.map { $0.productIdentifier }])
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
                    PostHogSDK.shared.capture("Purchase Failed", properties: ["productID": transaction.payment.productIdentifier, "error": transaction.error?.localizedDescription ?? "No error information"])
                }
                SKPaymentQueue.default().finishTransaction(transaction)
            case .restored:
                // Handle restored transaction if your app supports it
                DispatchQueue.main.async {
                    self.isLoading = false
                    PostHogSDK.shared.capture("Purchase Restored", properties: ["productID": transaction.payment.productIdentifier])
                }
                SKPaymentQueue.default().finishTransaction(transaction)
            default:
                break
            }
        }
    }
}
