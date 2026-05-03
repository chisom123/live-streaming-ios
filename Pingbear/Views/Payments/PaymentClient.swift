import Foundation
import PassKit
import FirebaseFunctions
import FirebaseAuth

// ─────────────────────────────────────────────────────────────
// MARK: - PaymentResult
// ─────────────────────────────────────────────────────────────

enum PaymentResult {
    case success(amount: Double)
    case cancelled
    case failure(Error)
}

// ─────────────────────────────────────────────────────────────
// MARK: - PaymentClient
// ─────────────────────────────────────────────────────────────

@MainActor
class PaymentClient: NSObject, ObservableObject {

    static let shared = PaymentClient()

    private let merchantID      = "merchant.com.pordio.Chay"
    private let currencyCode    = "USD"
    private let countryCode     = "GB"
    private let useMockProvider = false

    func topUp(amount: Double) async -> PaymentResult {
        if useMockProvider {
            return await simulateTopUp(amount: amount)
        }
        return await stripeTopUp(amount: amount)
    }

    // ── Stripe Apple Pay flow ─────────────────────────────────

    private func stripeTopUp(amount: Double) async -> PaymentResult {

        guard PKPaymentAuthorizationController.canMakePayments(
            usingNetworks: [.visa, .masterCard, .amex]
        ) else {
            return .failure(PaymentError.applePayUnavailable)
        }

        // 1. Create PaymentIntent on backend before showing sheet
        let clientSecret: String
        let paymentIntentId: String
        do {
            clientSecret    = try await createPaymentIntent(amount: amount)
            paymentIntentId = clientSecret.components(separatedBy: "_secret_").first ?? ""
        } catch {
            return .failure(error)
        }

        // 2. Build Apple Pay request
        let paymentRequest                  = PKPaymentRequest()
        paymentRequest.merchantIdentifier   = merchantID
        paymentRequest.supportedNetworks    = [.visa, .masterCard, .amex]
        paymentRequest.merchantCapabilities = .capability3DS
        paymentRequest.countryCode          = countryCode
        paymentRequest.currencyCode         = currencyCode
        paymentRequest.paymentSummaryItems  = [
            PKPaymentSummaryItem(
                label:  "SocialStar",
                amount: NSDecimalNumber(value: amount)
            )
        ]

        // 3. Present Apple Pay sheet and get PKPayment token
        let pkPayment: PKPayment
        do {
            pkPayment = try await presentApplePaySheet(request: paymentRequest)
        } catch {
            if (error as? PaymentError) == .userCancelled {
                return .cancelled
            }
            return .failure(error)
        }

        // 4. Confirm via server — server handles all Stripe API calls
        //    This avoids GTMSessionFetcher intercepting direct Stripe calls
        do {
            try await confirmViaServer(
                payment:         pkPayment,
                paymentIntentId: paymentIntentId,
                clientSecret:    clientSecret
            )
        } catch {
            return .failure(error)
        }

        // 5. Wallet credited automatically via Stripe webhook
        //    Firestore real-time listener picks up balance change
        return .success(amount: amount)
    }

    // ── Present Apple Pay sheet ───────────────────────────────

    private func presentApplePaySheet(request: PKPaymentRequest) async throws -> PKPayment {
        return try await withCheckedThrowingContinuation { continuation in
            let controller = PKPaymentAuthorizationController(paymentRequest: request)
            let delegate   = ApplePayDelegate(continuation: continuation)
            controller.delegate = delegate

            // Keep delegate alive for duration of sheet
            objc_setAssociatedObject(
                controller,
                "delegate",
                delegate,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

            controller.present { presented in
                if !presented {
                    continuation.resume(throwing: PaymentError.applePayUnavailable)
                }
            }
        }
    }

    // ── Confirm via server ────────────────────────────────────
    // Sends Apple Pay token data to Firebase Function.
    // Server tokenizes with Stripe and confirms PaymentIntent.
    // No direct Stripe API calls from app — bypasses GTMSessionFetcher.

    private func confirmViaServer(
        payment:         PKPayment,
        paymentIntentId: String,
        clientSecret:    String
    ) async throws {
        // Force auth token refresh after Apple Pay sheet
        if let user = Auth.auth().currentUser {
            _ = try await user.getIDTokenResult(forcingRefresh: true)
        }

        let tokenData = payment.token.paymentData.base64EncodedString()
        let callable  = Functions.functions().httpsCallable("confirmTopUpIntent")
        callable.timeoutInterval = 30

        _ = try await callable.call([
            "paymentIntentId":   paymentIntentId,
            "clientSecret":      clientSecret,
            "applePayTokenData": tokenData,
            "transactionId":     payment.token.transactionIdentifier
        ])
    }

    // ── Create PaymentIntent on backend ───────────────────────

    private func createPaymentIntent(amount: Double) async throws -> String {
        let amountInPence = Int(amount * 100)
        let callable      = Functions.functions().httpsCallable("createTopUpIntent")
        callable.timeoutInterval = 30
        let result = try await callable.call([
            "amount":   amountInPence,
            "currency": "usd"
        ])

        guard
            let data         = result.data as? [String: Any],
            let clientSecret = data["clientSecret"] as? String
        else { throw PaymentError.invalidResponse }

        return clientSecret
    }

    // ── Mock flow ─────────────────────────────────────────────

    private func simulateTopUp(amount: Double) async -> PaymentResult {
        do {
            let result = try await Functions.functions()
                .httpsCallable("simulateTopUp")
                .call(["amount": amount])

            if let data    = result.data as? [String: Any],
               let success = data["success"] as? Bool, success {
                return .success(amount: amount)
            }
            return .failure(PaymentError.invalidResponse)
        } catch {
            return .failure(error)
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - ApplePayDelegate
//
// Handles PKPaymentAuthorizationController callbacks.
// Returns PKPayment to our async continuation.
// ─────────────────────────────────────────────────────────────

class ApplePayDelegate: NSObject, PKPaymentAuthorizationControllerDelegate {

    private let continuation: CheckedContinuation<PKPayment, Error>
    private var completed = false

    init(continuation: CheckedContinuation<PKPayment, Error>) {
        self.continuation = continuation
    }

    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        completed = true
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
        continuation.resume(returning: payment)
    }

    func paymentAuthorizationControllerDidFinish(
        _ controller: PKPaymentAuthorizationController
    ) {
        controller.dismiss(completion: nil)
        if !completed {
            continuation.resume(throwing: PaymentError.userCancelled)
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Errors
// ─────────────────────────────────────────────────────────────

enum PaymentError: LocalizedError, Equatable {
    case notImplemented
    case applePayUnavailable
    case invalidResponse
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .notImplemented:      return "Payment provider not configured."
        case .applePayUnavailable: return "Apple Pay is not available on this device."
        case .invalidResponse:     return "Payment failed. Please try again."
        case .userCancelled:       return "Payment cancelled."
        }
    }
}
