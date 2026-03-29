import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import SafariServices

struct PrizePoolInfoView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var prizePoolAmount: Double = 50.0

    private let db = Firestore.firestore()
    
    private let rulesURL = "https://www.notion.so/Prize-Pool-Rules-31fae3bec80380d080b3fa6d054e9d06"

    var body: some View {
        ZStack {
            Color(hex: "#10183C")
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header
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
                    
                    Text("Learn More")
                        .font(.system(size: 17, weight: .bold, design: .default))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Color.clear
                        .frame(width: 30, height: 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                Image("gem")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color(hex: "#FFF"))
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 70, height: 70)

                Text("Win points in photo competitions")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Text("$\(Int(ceil(prizePoolAmount))) Prize Pool")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Spacer()

                // Prize Pool Rules link
                Button(action: {
                    openURL(rulesURL)
                    Analytics.shared.trackTap(
                        elementId: "prize_pool_rules",
                        screenName: "prize_pool_info"
                    )
                }) {
                    Text("Prize Pool Rules")
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundColor(.white.opacity(0.9))
                }

                // Apple disclaimer
                Text("Apple is not a sponsor of or participant in this prize pool. Prize pools are operated solely by SocialStar Technology Ltd.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
            }
        }
        .onAppear {
            loadPrizePool()
        }
    }

    // MARK: - Helper

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let safariVC = SFSafariViewController(url: url, configuration: config)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            var topController = rootViewController
            while let presented = topController.presentedViewController {
                topController = presented
            }
            topController.present(safariVC, animated: true)
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
