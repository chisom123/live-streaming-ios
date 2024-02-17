import Foundation
import PayPalCheckout
import PayPalNativePayments
import CardPayments
import CorePayments
import FirebaseFirestore

class PaymentViewModel: ObservableObject, CardDelegate {
    
    private let coreConfig: CoreConfig
    private let cardClient: CardClient
    
    // Add published properties to communicate with your SwiftUI view
    @Published var paymentSuccess: Bool = false
    @Published var paymentError: String? = nil
    
    init(clientID: String) {
        self.coreConfig = CoreConfig(clientID: clientID, environment: .sandbox)
        self.cardClient = CardClient(config: self.coreConfig)
        self.cardClient.delegate = self // Set the delegate
    }

    func processPayment(cardNumber: String, expiryDate: String, cvv: String) {
        // Firestore database reference
        let db = Firestore.firestore()

        // Pre-generate document reference for a new order
        let newOrderRef = db.collection("orders").document()
        let orderID = newOrderRef.documentID // Capture the ID for later use

        // Order details
        let orderDetails: [String: Any] = [
            "value": 5.00, // Specify the amount
            "currency_code": "GBP",
            "status": "pending",
            "created": FieldValue.serverTimestamp(), // Capture the creation time
        ]

        // Use the pre-generated document reference to add the new order
        newOrderRef.setData(orderDetails) { [weak self] error in
            if let error = error {
                // Handle the error, for instance, by updating a state variable
                print("Error adding document: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.paymentError = error.localizedDescription
                }
                return
            }

            // Extract expiry month and year from expiryDate
            let expiryComponents = expiryDate.components(separatedBy: "/")
            guard expiryComponents.count == 2,
                  let expiryMonth = expiryComponents.first,
                  let expiryYearSuffix = expiryComponents.last else {
                DispatchQueue.main.async {
                    self?.paymentError = "Invalid expiry date format"
                }
                return
            }

            let expiryYear = expiryYearSuffix

            // Create a Card object using the provided details
            let card = Card(number: cardNumber, expirationMonth: expiryMonth, expirationYear: expiryYear, securityCode: cvv)
            
            // Create a CardRequest with the pre-generated orderID
            let cardRequest = CardRequest(orderID: orderID, card: card)
            
            // Proceed to use the order ID for the payment process
            self?.cardClient.approveOrder(request: cardRequest)

        }
    }
    
    // MARK: - CardDelegate Methods
    func card(_ cardClient: CardClient, didFinishWithResult result: CardResult) {
        DispatchQueue.main.async {
            // Handle the success case, update your published properties as needed
            self.paymentSuccess = true
        }
    }
    
    func card(_ cardClient: CardClient, didFinishWithError error: CoreSDKError) {
        DispatchQueue.main.async {
            // Handle the error case
            self.paymentError = error.localizedDescription
        }
    }
    
    func cardDidCancel(_ cardClient: CardClient) {
        // Optionally handle user cancellation
    }
    
    func cardThreeDSecureWillLaunch(_ cardClient: CardClient) {
        // Handle 3D Secure launch if needed
    }
    
    func cardThreeDSecureDidFinish(_ cardClient: CardClient) {
        // Handle 3D Secure completion if needed
    }
}
