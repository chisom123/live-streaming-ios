import StoreKit
import FirebaseAuth
import FirebaseFirestore

class PayViewModel: NSObject, ObservableObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    @Published var products: [SKProduct] = []
    @Published var purchaseCompleted: Bool = false
    @Published var isLoading: Bool = false
    
    var competitionId: String = ""
    var entryDocId: String = ""
    
    private var productIdentifiers: Set<String> = ["one_day_boost", "one_hour_boost", "one_week_boost"]

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
            Analytics.shared.trackPurchase(
                action: "initiate",
                productId: product.productIdentifier
            )
        }
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

    private func handleCompletedPayment(transaction: SKPaymentTransaction) {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("Validation failed")
            Analytics.shared.trackError(
                message: "User not authenticated during purchase validation",
                properties: ["product_id": transaction.payment.productIdentifier]
            )
            return
        }
        
        let currentDate = Date()
        var expirationDate = currentDate

        switch transaction.payment.productIdentifier {
        case "one_day_boost":
            expirationDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        case "one_week_boost":
            expirationDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentDate)!
        case "one_hour_boost":
            expirationDate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        default:
            print("Unknown or unsupported product identifier")
            Analytics.shared.trackError(
                message: "Unsupported product identifier",
                properties: ["product_id": transaction.payment.productIdentifier]
            )
            return
        }
        
        // Get reference to the member document in the competition
        let memberRef = Firestore.firestore()
            .collection("competitions")
            .document(competitionId)
            .collection("members")
            .document(userID)
        
        // Update the member document with the boost expiration date
        memberRef.updateData(["boostExpiration": expirationDate]) { [weak self] error in
            if let error = error {
                print("Error updating user boost data: \(error)")
                Analytics.shared.trackError(
                    message: "Boost data update failed",
                    properties: ["error": error.localizedDescription]
                )
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
                        Analytics.shared.trackError(
                            message: "Superstar status update failed",
                            properties: ["error": error.localizedDescription]
                        )
                        return
                    }
                    
                    guard let self = self else { return }
                    self.purchaseCompleted = true
                    Analytics.shared.trackPurchase(
                        action: "completed",
                        productId: transaction.payment.productIdentifier,
                        properties: ["status": "superstar_set"]
                    )
                    
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
            Analytics.shared.track(
                event: "products_fetched",
                properties: ["product_ids": self.products.map { $0.productIdentifier }]
            )
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
                    Analytics.shared.trackPurchase(
                        action: "failed",
                        productId: transaction.payment.productIdentifier,
                        properties: ["error": transaction.error?.localizedDescription ?? "No error information"]
                    )
                }
                SKPaymentQueue.default().finishTransaction(transaction)
            case .restored:
                // Handle restored transaction if your app supports it
                DispatchQueue.main.async {
                    self.isLoading = false
                    Analytics.shared.trackPurchase(
                        action: "restored",
                        productId: transaction.payment.productIdentifier
                    )
                }
                SKPaymentQueue.default().finishTransaction(transaction)
            default:
                break
            }
        }
    }
}
