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
    
    // Product prices mapping
    private let productPrices: [String: Double] = [
        "one_day_boost": 9.99,
        "one_hour_boost": 4.99,
        "one_week_boost": 19.99
    ]
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
        let productId = transaction.payment.productIdentifier
        switch productId {
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
                properties: ["product_id": productId]
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
        
        // Log the purchase in the purchases subcollection
        self.logPurchase(userId: userID, productId: productId)
    }
    
    // New function to log purchases in Firestore
    private func logPurchase(userId: String, productId: String) {
        // Get the actual price from the product
        let price = self.products.first(where: { $0.productIdentifier == productId })?.price.doubleValue
                   ?? self.productPrices[productId] ?? 0.0
        
        // Calculate host's share (50% after Apple's 30% cut)
        // Apple takes 30%, leaving 70%. Host gets 50% of that 70%
        let hostShare = price * 0.70 * 0.50
        
        let db = Firestore.firestore()
        let purchaseRef = db.collection("competitions")
                             .document(competitionId)
                             .collection("purchases")
                             .document()
        
        let purchaseData: [String: Any] = [
            "userId": userId,
            "productId": productId,
            "timestamp": Timestamp(),
            "price": price,
            "hostShare": hostShare
        ]
        
        purchaseRef.setData(purchaseData) { error in
            if let error = error {
                print("Error logging purchase: \(error)")
                Analytics.shared.trackError(
                    message: "Purchase logging failed",
                    properties: ["error": error.localizedDescription]
                )
            } else {
                print("Purchase successfully logged")
            }
        }
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
