import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct HowItWorksSheet: View {
    var onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var prizePoolAmount: Double = 50.0

    private let db = Firestore.firestore()

    var body: some View {
        ZStack {
            Color(hex: "#10183C")
                .ignoresSafeArea()

            VStack(spacing: 30) {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image("x")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(.white)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                    }
                    Spacer()
                    Text("New Competition")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    // Invisible view to balance the close button and keep title centred
                    Color.clear
                        .frame(width: 30, height: 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                Image("gem")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 70, height: 70)

                Text("Win prize points playing with friends")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Text("$\(Int(ceil(prizePoolAmount))) Prize Pool")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Spacer()

                Button(action: {
                    Analytics.shared.trackTap(
                        elementId: "new_competition_button",
                        screenName: "how_it_works"
                    )
                    dismiss()
                    onConfirm()
                }) {
                    Text("New Competition")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color(hex: "#4169E1"))
                        .cornerRadius(200)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "how_it_works")
            loadPrizePool()
        }
    }

    // MARK: - Prize Pool Loading

    private func loadPrizePool() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        db.collection("users").document(userId).getDocument { document, _ in
            if let potId = document?.data()?["active_pot_id"] as? String {
                self.db.collection("global_pots").document(potId).getDocument { potDoc, _ in
                    if let potData = potDoc?.data() {
                        let firstPlace = potData["first_place_prize"] as? Double ?? 100.0
                        let maxParts = potData["max_participants"] as? Int ?? 99
                        let decay = potData["decay_rate"] as? Double ?? 0.91
                        let minPay = potData["min_payout"] as? Double ?? 0.01

                        let maxPool = self.calculateMaxPrizePool(
                            firstPlace: firstPlace,
                            decayRate: decay,
                            minPayout: minPay,
                            maxParticipants: maxParts
                        )

                        DispatchQueue.main.async {
                            self.prizePoolAmount = maxPool
                        }
                    }
                }
            } else {
                self.db.collection("app_config").document("global_leaderboard")
                    .getDocument { configDoc, _ in
                        if let data = configDoc?.data() {
                            let firstPlace = data["first_place_prize"] as? Double ?? 100.0
                            let decayRate = data["decay_rate"] as? Double ?? 0.91
                            let minPayout = data["min_payout"] as? Double ?? 0.01
                            let maxParticipants = data["pot_max_participants"] as? Int ?? 99

                            let maxPool = self.calculateMaxPrizePool(
                                firstPlace: firstPlace,
                                decayRate: decayRate,
                                minPayout: minPayout,
                                maxParticipants: maxParticipants
                            )

                            DispatchQueue.main.async {
                                self.prizePoolAmount = maxPool
                            }
                        }
                    }
            }
        }
    }

    private func calculateMaxPrizePool(firstPlace: Double, decayRate: Double, minPayout: Double, maxParticipants: Int) -> Double {
        var totalCents = 0

        for rank in 1...maxParticipants {
            let prizeCents = Int(floor(firstPlace * 100 * pow(decayRate, Double(rank - 1))))
            if prizeCents < Int(minPayout * 100) {
                break
            }
            totalCents += prizeCents
        }

        return Double(totalCents) / 100.0
    }
}
