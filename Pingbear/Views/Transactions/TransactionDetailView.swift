import SwiftUI

// ─────────────────────────────────────────────────────────────
// MARK: - TransactionDetailView
//
// Routes to one of two completely different experiences:
//   .request → RequestDetailView   (accept/decline, record, view, rate)
//   .offer   → OfferDetailView     (blurred tease, countdown, reveal, rate)
// ─────────────────────────────────────────────────────────────

struct TransactionDetailView: View {

    let initialEnriched: EnrichedContentTransaction
    let onDismiss:        () -> Void

    var body: some View {
        switch initialEnriched.transaction.type {
        case .request:
            RequestDetailView(enriched: initialEnriched, onDismiss: onDismiss)
        case .offer:
            OfferDetailView(enriched: initialEnriched, onDismiss: onDismiss)
        }
    }
}
