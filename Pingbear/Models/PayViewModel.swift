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
    
    // Product coin amounts mapping
    private let productCoins: [String: Int] = [
        "one_hour_boost": 100,      // Small bag
        "one_day_boost": 600,      // Medium bag
        "one_week_boost": 1500      // Large bag
    ]
    
    // Product prices mapping (fallback if StoreKit price unavailable)
    private let productPrices: [String: Double] = [
        "one_hour_boost": 4.99,
        "one_day_boost": 9.99,
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
            print("Validation failed - user not authenticated")
            Analytics.shared.trackError(
                message: "User not authenticated during purchase validation",
                properties: ["product_id": transaction.payment.productIdentifier]
            )
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }
        
        let productId = transaction.payment.productIdentifier
        
        // Get the coin amount for this product
        guard let coinAmount = productCoins[productId] else {
            print("Unknown product identifier: \(productId)")
            Analytics.shared.trackError(
                message: "Unknown product identifier",
                properties: ["product_id": productId]
            )
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }
        
        // Add coins to user's member document in the competition
        addCoinsToMember(userId: userID, coinAmount: coinAmount, productId: productId, transaction: transaction)
    }
    
    private func addCoinsToMember(userId: String, coinAmount: Int, productId: String, transaction: SKPaymentTransaction) {
        guard !competitionId.isEmpty else {
            print("Competition ID is required for member coin updates")
            Analytics.shared.trackError(
                message: "Competition ID missing for coin purchase",
                properties: ["product_id": productId]
            )
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }
        
        let db = Firestore.firestore()
        let memberRef = db.collection("competitions").document(competitionId).collection("members").document(userId)
        
        // Use a transaction to safely increment the coin count
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let memberDocument: DocumentSnapshot
            do {
                try memberDocument = transaction.getDocument(memberRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            // Check if member document exists
            if !memberDocument.exists {
                // Create member document with initial coin amount if it doesn't exist
                let memberData: [String: Any] = [
                    "coins": coinAmount,
                    "joinedAt": Timestamp(),
                    "userId": userId
                ]
                transaction.setData(memberData, forDocument: memberRef)
                return coinAmount
            } else {
                // Get current coin count or default to 0
                let currentCoins = memberDocument.data()?["coins"] as? Int ?? 0
                let newCoinTotal = currentCoins + coinAmount
                
                // Update the coin count
                transaction.updateData(["coins": newCoinTotal], forDocument: memberRef)
                return newCoinTotal
            }
        }) { [weak self] (result, error) in
            if let error = error {
                print("Error adding coins to member: \(error)")
                Analytics.shared.trackError(
                    message: "Member coin addition failed",
                    properties: ["error": error.localizedDescription, "product_id": productId]
                )
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
                return
            }
            
            guard let self = self else { return }
            
            // Log the successful purchase
            self.logPurchase(userId: userId, productId: productId, coinAmount: coinAmount)
            
            // Mark purchase as completed
            DispatchQueue.main.async {
                self.purchaseCompleted = true
                self.isLoading = false
                
                Analytics.shared.trackPurchase(
                    action: "completed",
                    productId: productId,
                    properties: [
                        "coins_added": coinAmount,
                        "new_total": result as? Int ?? 0,
                        "competition_id": self.competitionId
                    ]
                )
            }
        }
        
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    // Log purchase in Firestore purchases collection
    private func logPurchase(userId: String, productId: String, coinAmount: Int) {
        // Only log if we have a competition context
        guard !competitionId.isEmpty else {
            print("Skipping purchase log - no competition context")
            return
        }
        
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
            "hostShare": hostShare,
            "coinsAdded": coinAmount,
            "memberLevel": true  // Flag to indicate this was a member-level coin purchase
        ]
        
        purchaseRef.setData(purchaseData) { error in
            if let error = error {
                print("Error logging purchase: \(error)")
                Analytics.shared.trackError(
                    message: "Purchase logging failed",
                    properties: ["error": error.localizedDescription]
                )
            } else {
                print("Purchase successfully logged with \(coinAmount) coins added to member")
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
