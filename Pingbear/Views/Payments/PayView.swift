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
    @State private var selectedPackage: Int? = nil
    
    // NEW: Rakeback state
    @State private var unclaimedRakeback: Int = 0
    @State private var totalRakebackEarned: Int = 0
    @State private var isClaimingRakeback = false
    @State private var showRakebackSuccess = false
    
    var competition: Competition
    var competitionId: String
    var entryDocId: String
    
    // Check if user is in GB region (for showing web option)
    private var shouldShowWebPurchase: Bool {
        return Locale.current.region?.identifier == "US"
    }
    
    var body: some View {
        // Show loading for both IAP and web purchases
        if viewModel.isLoading || isGeneratingToken {
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
                
                ScrollView {
                    VStack(spacing: 20) {
                        // NEW: Rakeback Section (at top)
                        if unclaimedRakeback > 0 {
                            rakebackSection
                        }
                        
                        HStack {
                            // Title
                            Text("Get Coins")
                                .font(.system(size: 25, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.top, unclaimedRakeback > 0 ? 0 : 40)
                                .padding(.leading, unclaimedRakeback > 0 ? 20 : 0)
                            
                            if unclaimedRakeback > 0 {
                                Spacer()
                            }
                        }
                        
                        // Main Content Area
                        if shouldShowWebPurchase {
                            // Show only custom input for web purchase users
                            customCoinInputView
                                .padding(.horizontal, 20)
                        } else {
                            // Show standard packages for non-web purchase users
                            coinPackagesView
                                .padding(.horizontal, 20)
                        }
                    }
                }
                
                // Privacy and Terms
                privacyAndTerms
            }
            .background(Color(hex: "#10183C"))
            .onAppear {
                viewModel.competitionId = self.competitionId
                viewModel.entryDocId = self.entryDocId
                fetchUserCoinsAndRakeback()
                NotificationQueueManager.shared.processQueuedNotifications()
                Analytics.shared.trackScreen(name: "coins_view")
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Refresh when user returns to app (possibly from web purchase)
                handleReturnFromWeb()
            }
            .overlay(
                // Success animation overlay
                Group {
                    if showRakebackSuccess {
                        rakebackSuccessOverlay
                    }
                }
            )
        }
    }
    
    // MARK: - NEW: Rakeback Section
    
    private var rakebackSection: some View {
        VStack(spacing: 16) {
            // Header with icon
            HStack {
                
                Text("Bonus Available")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            // Rakeback Amount Display
            HStack(spacing: 12) {
                Image("coin")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                
                Text("\(unclaimedRakeback)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            // Claim Button
            Button(action: {
                claimRakeback()
            }) {
                HStack {
                    if isClaimingRakeback {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Claim Bonus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color(hex: "#008000"))
                .cornerRadius(200)
            }
            .disabled(isClaimingRakeback)
            
            // Lifetime Stats
            if totalRakebackEarned > 0 {
                HStack {
                    Text("Bonus grows as you place predictions")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "#1A2245"))
        )
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    // MARK: - NEW: Rakeback Success Overlay
    
    private var rakebackSuccessOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(Color(hex: "#FFF"))
                
                // Success message
                Text("Bonus Claimed")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "#1A2245"))
            )
            .padding(.horizontal, 40)
        }
        .onAppear {
            // Auto-dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showRakebackSuccess = false
                }
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
                        .frame(width: 19, height: 19)
                    
                    if isLoadingCoins {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("\(userCoins)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 15)
                .frame(height: 40)
                .background(Color(hex: "#2A3255"))
                .cornerRadius(200)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color(hex: "#1A2245"))
    }
    
    // MARK: - Custom Coin View (only for web purchase users)
    private var customCoinInputView: some View {
        VStack(spacing: 0) {
            // Small Package - 100 coins for $0.99
            CoinPackageCell(
                coinAmount: "100",
                image: "coin-2",
                price: "$0.99",
                popular: false,
                isLoading: selectedPackage == 100 && isGeneratingToken,
                iapAction: {
                    selectedPackage = 100
                    openWebPurchase(coinAmount: 100)
                }
            )
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Medium Package (Most Popular) - 600 coins for $4.99
            CoinPackageCell(
                coinAmount: "600",
                image: "coin-3",
                price: "$4.99",
                popular: true,
                isLoading: selectedPackage == 600 && isGeneratingToken,
                iapAction: {
                    selectedPackage = 600
                    openWebPurchase(coinAmount: 600)
                }
            )
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Large Package - 1,500 coins for $9.99
            CoinPackageCell(
                coinAmount: "1,500",
                image: "coin-bag",
                price: "$9.99",
                popular: false,
                isLoading: selectedPackage == 1500 && isGeneratingToken,
                iapAction: {
                    selectedPackage = 1500
                    openWebPurchase(coinAmount: 1500)
                }
            )
        }
        .cornerRadius(10)
        .disabled(isGeneratingToken)
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
                    isLoading: false, // IAP loading is handled by viewModel.isLoading
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
                    isLoading: false,
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
                    isLoading: false,
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
                    openURL("https://www.notion.so/Privacy-Policy-2aaae3bec80380838551eb321015a92f")
                }
            
            Text("•")
                .font(.system(size: 14, weight: .bold, design: .default))
            
            Text("Terms of Use")
                .onTapGesture {
                    openURL("https://www.notion.so/Terms-of-Use-2aaae3bec803804b83c4fa30721168d8")
                }
        }
        .font(.system(size: 14, weight: .semibold, design: .default))
        .foregroundColor(.white.opacity(0.9))
        .padding(.vertical, 20)
    }
    
    // MARK: - NEW: Rakeback Functions
    
    private func claimRakeback() {
        guard unclaimedRakeback > 0 && !isClaimingRakeback else { return }
        
        isClaimingRakeback = true
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No authenticated user")
            isClaimingRakeback = false
            return
        }
        
        let db = Firestore.firestore()
        let memberRef = db.collection("competitions")
            .document(competitionId)
            .collection("members")
            .document(userId)
        
        // Use transaction to atomically move rakeback to coins
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let memberDoc: DocumentSnapshot
            do {
                try memberDoc = transaction.getDocument(memberRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let data = memberDoc.data() else {
                let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Member document does not exist"])
                errorPointer?.pointee = error
                return nil
            }
            
            let currentCoins = data["coins"] as? Int ?? 0
            let currentUnclaimed = data["unclaimedRakeback"] as? Int ?? 0
            
            // Move unclaimed rakeback to coins
            let newCoins = currentCoins + currentUnclaimed
            
            transaction.updateData([
                "coins": newCoins,
                "unclaimedRakeback": 0,
                "lastRakebackClaim": FieldValue.serverTimestamp()
            ], forDocument: memberRef)
            
            return currentUnclaimed
        }) { (claimedAmount, error) in
            DispatchQueue.main.async {
                self.isClaimingRakeback = false
                
                if let error = error {
                    print("Error claiming rakeback: \(error)")
                    Analytics.shared.trackError(
                        message: "Rakeback claim failed",
                        properties: ["error": error.localizedDescription]
                    )
                    return
                }
                
                if let claimed = claimedAmount as? Int {
                    // Update local state
                    let previousUnclaimed = self.unclaimedRakeback
                    self.userCoins += claimed
                    self.unclaimedRakeback = 0
                    
                    // Show success animation
                    withAnimation {
                        self.showRakebackSuccess = true
                    }
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    // Track analytics
                    Analytics.shared.track(
                        event: "rakeback_claimed",
                        properties: [
                            "amount": claimed,
                            "competition_id": self.competitionId,
                            "total_lifetime": self.totalRakebackEarned
                        ]
                    )
                    
                    print("💰 Successfully claimed \(claimed) coins rakeback")
                }
            }
        }
    }
    
    private func fetchUserCoinsAndRakeback() {
        guard let currentUser = Auth.auth().currentUser else {
            print("No authenticated user found")
            isLoadingCoins = false
            return
        }
        
        let db = Firestore.firestore()
        
        // Fetch coins AND rakeback from the member document
        db.collection("competitions").document(competitionId).collection("members").document(currentUser.uid).getDocument { document, error in
            DispatchQueue.main.async {
                isLoadingCoins = false
                
                if let error = error {
                    print("Error fetching member data: \(error.localizedDescription)")
                    return
                }
                
                guard let document = document, document.exists else {
                    print("Member document does not exist")
                    return
                }
                
                let data = document.data() ?? [:]
                
                // Update coins
                if let coins = data["coins"] as? Int {
                    self.userCoins = coins
                } else {
                    print("Coins field not found, defaulting to 0")
                    self.userCoins = 0
                }
                
                // NEW: Update rakeback
                if let unclaimed = data["unclaimedRakeback"] as? Int {
                    self.unclaimedRakeback = unclaimed
                } else {
                    self.unclaimedRakeback = 0
                }
                
                if let total = data["totalRakebackEarned"] as? Int {
                    self.totalRakebackEarned = total
                } else {
                    self.totalRakebackEarned = 0
                }
                
                print("Fetched coins: \(self.userCoins), unclaimed rakeback: \(self.unclaimedRakeback)")
            }
        }
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
                selectedPackage = nil // Reset selected package
                
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
                }
            }
        }
    }
    
    private func handleReturnFromWeb() {
        // Refresh coin balance and rakeback when user returns from web
        fetchUserCoinsAndRakeback()
        
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
        // Redirect to the new function that fetches both
        fetchUserCoinsAndRakeback()
    }
}

// MARK: - Coin Package Cell Component
struct CoinPackageCell: View {
    let coinAmount: String
    let image: String
    let price: String
    let popular: Bool
    let isLoading: Bool
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
                
                if isLoading {
                    // Show progress indicator instead of price
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    // Price
                    Text(price)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#FFF"))
                        .background(Color(hex: "#4169E1"))
                        .cornerRadius(200)
                }
            }
            .padding(20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color(hex: "#1A2245"))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
    }
}

extension Notification.Name {
    static let dismissCameraFlow = Notification.Name("dismissCameraFlow")
}
