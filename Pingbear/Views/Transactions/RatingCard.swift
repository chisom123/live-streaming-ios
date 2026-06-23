import SwiftUI
import FirebaseFunctions

// ─────────────────────────────────────────────────────────────
// MARK: - RatingCard
// Shared 1–5 star rating UI used by both the request and offer
// flows. Submits via the rateTransaction Firebase function.
// ─────────────────────────────────────────────────────────────

struct RatingCard: View {

    let transactionId: String
    let onRated:       () -> Void

    @State private var selectedRating:  Int     = 0
    @State private var tappedStar:      Int     = 0
    @State private var isSubmitted:     Bool    = false
    @State private var errorMessage:    String? = nil

    private let functions = Functions.functions()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: "star.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .scaleEffect(tappedStar == star ? 1.3 : 1.0)
                        .onTapGesture {
                            guard !isSubmitted else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedRating = star
                            withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                                tappedStar = star
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                    tappedStar = 0
                                }
                                withAnimation(.easeOut(duration: 0.2)) {
                                    isSubmitted = true
                                }
                                Task { await submitRating() }
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.black)
            .ignoresSafeArea(edges: .bottom)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.bottom, 8)
                    .background(Color.black)
            }
        }
    }

    private func submitRating() async {
        do {
            try await functions.httpsCallable("rateTransaction").call([
                "transactionId": transactionId,
                "rating":        selectedRating
            ])
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Analytics.shared.track(
                event: AnalyticsEvent.contentRated,
                properties: [
                    AnalyticsProperty.transactionId: transactionId,
                    AnalyticsProperty.rating: selectedRating
                ]
            )
            await MainActor.run { onRated() }
        } catch {
            await MainActor.run {
                isSubmitted    = false
                selectedRating = 0
                errorMessage   = error.localizedDescription
            }
        }
    }
}
