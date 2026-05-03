import Foundation
import SwiftUI

@MainActor
class TopUpViewModel: ObservableObject {

    @Published var customAmount: String = ""
    @Published var isLoading             = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil

    let quickAmounts: [Double] = [5, 10, 20, 50]
    let minimumAmount: Double  = 1.00

    // ── Initiate top-up ───────────────────────────────────────
    // Mock provider: credits instantly via simulateTopUp.
    // Live provider: presents Apple Pay sheet, captures server-side.

    func initiateTopUp(amount: Double) async {
        guard amount >= minimumAmount else {
            errorMessage = "Minimum top-up is £\(String(format: "%.2f", minimumAmount))"
            return
        }

        isLoading      = true
        errorMessage   = nil
        successMessage = nil

        let result = await PaymentClient.shared.topUp(amount: amount)

        switch result {
        case .success(let amount):
            successMessage = "£\(String(format: "%.2f", amount)) added to your wallet!"
            customAmount   = ""
        case .cancelled:
            break // user cancelled, no message needed
        case .failure(let error):
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // ── Custom amount helpers ─────────────────────────────────

    var parsedCustomAmount: Double? {
        guard let value = Double(customAmount), value >= minimumAmount else { return nil }
        return value
    }

    var customAmountIsValid: Bool {
        parsedCustomAmount != nil
    }
}
