import Foundation
import SwiftUI

@MainActor
class TopUpViewModel: ObservableObject {

    @Published var customAmount:   String  = ""
    @Published var isLoading               = false
    @Published var errorMessage:   String? = nil
    @Published var successMessage: String? = nil

    let quickAmounts:  [Double] = [5, 10, 20, 50]
    let minimumAmount: Double   = 1.00

    // ─────────────────────────────────────────────────────────
    // MARK: - Initiate top-up
    // ─────────────────────────────────────────────────────────

    func initiateTopUp(amount: Double) async {
        guard amount >= minimumAmount else {
            errorMessage = "Minimum top-up is $\(String(format: "%.2f", minimumAmount))"
            return
        }

        isLoading      = true
        errorMessage   = nil
        successMessage = nil

        Analytics.shared.track(
            event: AnalyticsEvent.topUpOpened,
            properties: [AnalyticsProperty.amount: amount]
        )

        let result = await PaymentClient.shared.topUp(amount: amount)

        switch result {
        case .success(let amount):
            Analytics.shared.track(
                event: AnalyticsEvent.topUpCompleted,
                properties: [AnalyticsProperty.amount: amount]
            )
            successMessage = "$\(String(format: "%.2f", amount)) added to your wallet!"
            customAmount   = ""

        case .cancelled:
            Analytics.shared.track(
                event: AnalyticsEvent.topUpCancelled,
                properties: [AnalyticsProperty.amount: amount]
            )
            // User cancelled — no message needed

        case .failure(let error):
            Analytics.shared.track(
                event: AnalyticsEvent.topUpFailed,
                properties: [
                    AnalyticsProperty.amount:       amount,
                    AnalyticsProperty.errorMessage: error.localizedDescription
                ]
            )
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────────────────────────

    var parsedCustomAmount: Double? {
        guard let value = Double(customAmount), value >= minimumAmount else { return nil }
        return value
    }

    var customAmountIsValid: Bool {
        parsedCustomAmount != nil
    }
}
