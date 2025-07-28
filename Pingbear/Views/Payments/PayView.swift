import SwiftUI
import StoreKit
import FirebaseFirestore
import FirebaseAuth

struct PayView: View {
    @ObservedObject var viewModel: PayViewModel
    @State private var selectedBoostIndex = 1 // Pre-select middle option
    @Environment(\.dismiss) private var dismiss
    @State private var userCoins: Int = 0
    @State private var isLoadingCoins = true
    
    var competition: Competition
    var competitionId: String
    var entryDocId: String
    
    var body: some View {
        if viewModel.isLoading {
            ProgressView()
                .padding()
                .tint(.white)
                .scaleEffect(1.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#10183C"))
        } else {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Title
                Text("Get Coins")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 40)
                
                // Coin packages
                coinPackages
                    .padding(.top, 40)
                    .padding(.horizontal, 20)
                
                Spacer()
                
                // Privacy and Terms
                privacyAndTerms
            }
            .background(Color(hex: "#10183C"))
            .onAppear {
                viewModel.competitionId = self.competitionId
                viewModel.entryDocId = self.entryDocId
                fetchUserCoins()
                NotificationQueueManager.shared.processQueuedNotifications()
                Analytics.shared.trackScreen(name: "coins_view")
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        ZStack {
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
                
                Text("Balance")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.trailing, 5)
                
                // Current coin balance on the left
                HStack(spacing: 5) {
                    Image("coin")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                    
                    if isLoadingCoins {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("\(userCoins)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(hex: "#2A3255"))
                .cornerRadius(200)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color(hex: "#1A2245"))
    }
    
    // MARK: - Coin Packages
    private var coinPackages: some View {
        VStack(spacing: 0) {
            // Small Package
            if let hourUnlock = viewModel.products.first(where: { $0.productIdentifier == "one_hour_boost" }) {
                CoinPackageCell(
                    coinAmount: "100",
                    image: "coin-2",
                    price: formattedPrice(for: hourUnlock),
                    popular: false
                ) {
                    withAnimation(.spring()) {
                        selectedBoostIndex = 0
                    }
                    viewModel.purchase(product: hourUnlock)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Medium Package (Most Popular)
            if let dayUnlock = viewModel.products.first(where: { $0.productIdentifier == "one_day_boost" }) {
                CoinPackageCell(
                    coinAmount: "600",
                    image: "coin-3",
                    price: formattedPrice(for: dayUnlock),
                    popular: true
                ) {
                    withAnimation(.spring()) {
                        selectedBoostIndex = 1
                    }
                    viewModel.purchase(product: dayUnlock)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Large Package
            if let weekUnlock = viewModel.products.first(where: { $0.productIdentifier == "one_week_boost" }) {
                CoinPackageCell(
                    coinAmount: "1,500",
                    image: "coin-bag",
                    price: formattedPrice(for: weekUnlock),
                    popular: false
                ) {
                    withAnimation(.spring()) {
                        selectedBoostIndex = 2
                    }
                    viewModel.purchase(product: weekUnlock)
                }
            }
        }
        .cornerRadius(10)
    }
    
    // MARK: - Privacy and Terms
    private var privacyAndTerms: some View {
        HStack(spacing: 5) {
            Text("Privacy Policy")
                .onTapGesture {
                    openURL("https://chay-b6172c.webflow.io/privacy-policy")
                }
            
            Text("•")
                .font(.system(size: 14, weight: .bold, design: .default))
            
            Text("Terms of Use")
                .onTapGesture {
                    openURL("https://chay-b6172c.webflow.io")
                }
        }
        .font(.system(size: 14, weight: .semibold, design: .default))
        .foregroundColor(.white.opacity(0.9))
        .padding(.vertical, 20)
    }
    
    // MARK: - Helper Functions
    private func formattedPrice(for product: SKProduct) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price) ?? "$0.00"
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func fetchUserCoins() {
        guard let currentUser = Auth.auth().currentUser else {
            print("No authenticated user found")
            isLoadingCoins = false
            return
        }
        
        let db = Firestore.firestore()
        
        // Fetch coins from the member document in the competition
        db.collection("competitions").document(competitionId).collection("members").document(currentUser.uid).getDocument { document, error in
            DispatchQueue.main.async {
                isLoadingCoins = false
                
                if let error = error {
                    print("Error fetching member coins: \(error.localizedDescription)")
                    return
                }
                
                guard let document = document, document.exists else {
                    print("Member document does not exist")
                    return
                }
                
                if let coins = document.data()?["coins"] as? Int {
                    self.userCoins = coins
                } else {
                    print("Coins field not found or invalid type, defaulting to 0")
                    self.userCoins = 0
                }
            }
        }
    }
}

// MARK: - Coin Package Cell Component
struct CoinPackageCell: View {
    let coinAmount: String
    let image: String
    let price: String
    let popular: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                
                Image(image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(coinAmount)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    if popular {
                        Text("MOST POPULAR")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#4169E1"))
                            .cornerRadius(6)
                    }
                }
                
                Spacer()
                
                // Price
                Text(price)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "#FFF"))
                    .background(Color(hex: "#4169E1"))
                    .cornerRadius(200)
            }
            .padding(20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color(hex: "#1A2245"))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension Notification.Name {
    static let dismissCameraFlow = Notification.Name("dismissCameraFlow")
}
