import SwiftUI
import StoreKit
import FirebaseFirestore
import FirebaseAuth
import SafariServices
import FirebaseFunctions

struct PayView: View {
    @ObservedObject var viewModel: PayViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var userCoins: Int = 0
    @State private var isLoadingCoins = true
    @State private var isGeneratingToken = false
    @State private var customCoinAmount: String = ""
    @FocusState private var isInputFocused: Bool
    
    var competition: Competition
    var competitionId: String
    var entryDocId: String
    
    // Check if user is in GB region (for showing web option)
    private var shouldShowWebPurchase: Bool {
        return Locale.current.region?.identifier == "GB"
    }
    
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
                
                // Main Content Area
                if shouldShowWebPurchase {
                    // Show only custom input for web purchase users
                    customCoinInputView
                        .padding(.horizontal, 20)
                        .padding(.top, 40)
                } else {
                    // Show standard packages for non-web purchase users
                    coinPackagesView
                        .padding(.top, 40)
                        .padding(.horizontal, 20)
                }
                
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
                
                // Focus the input field automatically for web purchases
                if shouldShowWebPurchase {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isInputFocused = true
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Refresh when user returns to app (possibly from web purchase)
                handleReturnFromWeb()
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
                
                // Current coin balance
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
    
    // MARK: - Custom Coin Input View (only for web purchase users)
    private var customCoinInputView: some View {
        VStack(spacing: 0) {
            // Text field with coin icon
            HStack {
                Image("coin")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .padding(.leading, 15)
                
                TextField("Enter Amount", text: $customCoinAmount)
                    .padding(.vertical)
                    .padding(.leading, 5)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .bold, design: .default))
                    .accentColor(.white)
                    .keyboardType(.numberPad)
                    .focused($isInputFocused)
                    .onChange(of: customCoinAmount) { newValue in
                        // Filter non-numeric characters
                        let filtered = newValue.filter { "0123456789".contains($0) }
                        if filtered != newValue {
                            customCoinAmount = filtered
                        }
                    }
            }
            .frame(height: 60)
            .background(
                Color(hex: "#3B4374")
                    .clipShape(
                        RoundedCorner(
                            radius: 10,
                            corners: [.topLeft, .topRight]
                        )
                    )
            )
            
            // Dollar amount conversion
            if !customCoinAmount.isEmpty, let coins = Int(customCoinAmount), coins > 0 {
                let dollars = Double(coins) * 0.01
                Text("$\(String(format: "%.2f", dollars))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#3B4374"))
            }
            
            // Error message for invalid range
            if !customCoinAmount.isEmpty, let coins = Int(customCoinAmount), (coins < 100 || coins > 10000) {
                let errorMessage = coins < 100 ? "100 coins minimum" : "10,000 coins maximum"
                Text(errorMessage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#FFF"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#DC143C"))
            }
            
            // Purchase button
            Button(action: {
                if let amount = Int(customCoinAmount), amount >= 100 && amount <= 10000 {
                    openWebPurchase(coinAmount: amount)
                }
            }) {
                HStack {
                    if isGeneratingToken {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    
                    Text("Purchase")
                        .font(.system(size: 18, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundColor((isValidCoinAmount && !isGeneratingToken) ? .white : .white.opacity(0.5))
                .background(
                    Color(hex: (isValidCoinAmount && !isGeneratingToken) ? "#4169E1" : "#323862")
                        .clipShape(
                            RoundedCorner(
                                radius: 10,
                                corners: [.bottomLeft, .bottomRight]
                            )
                        )
                )
            }
            .disabled(!isValidCoinAmount || isGeneratingToken)
        }
        .cornerRadius(10)
    }

    // Helper computed property to check if coin amount is valid
    private var isValidCoinAmount: Bool {
        guard !customCoinAmount.isEmpty,
              let coins = Int(customCoinAmount) else {
            return false
        }
        return coins >= 100 && coins <= 10000
    }
    
    // MARK: - Coin Packages (only for non-web purchase users)
    private var coinPackagesView: some View {
        VStack(spacing: 0) {
            // Small Package
            if let hourUnlock = viewModel.products.first(where: { $0.productIdentifier == "one_hour_boost" }) {
                CoinPackageCell(
                    coinAmount: "100",
                    image: "coin-2",
                    price: formattedPrice(for: hourUnlock),
                    popular: false,
                    iapAction: {
                        viewModel.purchase(product: hourUnlock)
                    }
                )
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Medium Package (Most Popular)
            if let dayUnlock = viewModel.products.first(where: { $0.productIdentifier == "one_day_boost" }) {
                CoinPackageCell(
                    coinAmount: "600",
                    image: "coin-3",
                    price: formattedPrice(for: dayUnlock),
                    popular: true,
                    iapAction: {
                        viewModel.purchase(product: dayUnlock)
                    }
                )
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Large Package
            if let weekUnlock = viewModel.products.first(where: { $0.productIdentifier == "one_week_boost" }) {
                CoinPackageCell(
                    coinAmount: "1,500",
                    image: "coin-bag",
                    price: formattedPrice(for: weekUnlock),
                    popular: false,
                    iapAction: {
                        viewModel.purchase(product: weekUnlock)
                    }
                )
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
    
    // MARK: - Web Purchase Function
    private func openWebPurchase(coinAmount: Int) {
        guard !isGeneratingToken else { return }
        
        isGeneratingToken = true
        
        // Call Firebase Function to generate secure token
        Functions.functions().httpsCallable("createPurchaseToken").call([
            "competitionId": competitionId,
            "coinAmount": coinAmount
        ]) { result, error in
            DispatchQueue.main.async {
                isGeneratingToken = false
                
                if let error = error {
                    print("Error generating purchase token: \(error)")
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let token = data["token"] as? String,
                      let sessionId = data["sessionId"] as? String else {
                    print("Invalid token response")
                    return
                }
                
                // Open web purchase page with token and sessionId
                let urlString = "https://coins.socialstarapp.com?token=\(token)&sessionId=\(sessionId)"
                
                if let url = URL(string: urlString) {
                    let config = SFSafariViewController.Configuration()
                    config.entersReaderIfAvailable = false
                    
                    let safariVC = SFSafariViewController(url: url, configuration: config)
                    safariVC.preferredBarTintColor = UIColor(Color(hex: "#10183C"))
                    safariVC.preferredControlTintColor = UIColor.white
                    
                    // Present Safari and keep PayView open
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootViewController = window.rootViewController {
                        
                        // Find the topmost view controller
                        var topController = rootViewController
                        while let presentedController = topController.presentedViewController {
                            topController = presentedController
                        }
                        
                        // Present Safari - DON'T dismiss PayView
                        topController.present(safariVC, animated: true)
                    }
                    
                    // Track analytics
                    Analytics.shared.track(event: "web_purchase_opened", properties: [
                        "coin_amount": coinAmount,
                        "competition_id": competitionId
                    ])
                    
                    customCoinAmount = ""
                }
            }
        }
    }
    
    private func handleReturnFromWeb() {
        // Refresh coin balance when user returns from web
        fetchUserCoins()
        
        // Check for recent purchases
        Functions.functions().httpsCallable("checkPurchaseStatus").call([
            "competitionId": competitionId
        ]) { result, error in
            DispatchQueue.main.async {
                if let data = result?.data as? [String: Any],
                   let coins = data["coins"] as? Int {
                    
                    // Update UI if coins changed
                    if coins != userCoins {
                        userCoins = coins
                        
                        // Show success feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                }
            }
        }
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
    let iapAction: () -> Void
    
    var body: some View {
        Button(action: iapAction) {
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
