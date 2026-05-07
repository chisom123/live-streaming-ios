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

    @State private var unclaimedRakeback: Int = 0
    @State private var totalRakebackEarned: Int = 0
    @State private var isClaimingRakeback = false
    @State private var showRakebackSuccess = false

    var competition: Competition
    var competitionId: String
    var entryDocId: String

    private var shouldShowWebPurchase: Bool {
        return Locale.current.region?.identifier == "US"
    }

    var body: some View {
        if viewModel.isLoading || isGeneratingToken {
            ProgressView()
                .padding()
                .tint(AppTheme.primaryText)
                .scaleEffect(1.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.pageBackground)
        } else {
            VStack(spacing: 0) {
                headerView

                ScrollView {
                    VStack(spacing: 20) {
                        if unclaimedRakeback > 0 { rakebackSection }

                        HStack {
                            Text("Get Coins")
                                .font(.system(size: 25, weight: .bold))
                                .foregroundColor(AppTheme.primaryText)
                                .padding(.top, unclaimedRakeback > 0 ? 0 : 40)
                                .padding(.leading, unclaimedRakeback > 0 ? 20 : 0)
                            if unclaimedRakeback > 0 { Spacer() }
                        }

                        if shouldShowWebPurchase {
                            customCoinInputView.padding(.horizontal, 20)
                        } else {
                            coinPackagesView.padding(.horizontal, 20)
                        }
                    }
                }

                privacyAndTerms
            }
            .background(AppTheme.pageBackground)
            .onAppear {
                viewModel.competitionId = self.competitionId
                viewModel.entryDocId = self.entryDocId
                fetchUserCoinsAndRakeback()
                NotificationQueueManager.shared.processQueuedNotifications()
                Analytics.shared.trackScreen(name: "coins_view")
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                handleReturnFromWeb()
            }
            .overlay(Group { if showRakebackSuccess { rakebackSuccessOverlay } })
        }
    }

    private var rakebackSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Bonus Available")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
                Spacer()
            }

            HStack(spacing: 12) {
                Image("coin").resizable().aspectRatio(contentMode: .fit).frame(width: 40, height: 40)
                Text("\(unclaimedRakeback)").font(.system(size: 36, weight: .bold)).foregroundColor(AppTheme.primaryText)
                Spacer()
            }

            Button(action: { claimRakeback() }) {
                HStack {
                    if isClaimingRakeback {
                        ProgressView().scaleEffect(0.8).progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Claim Bonus").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(AppTheme.green)
                .cornerRadius(200)
            }
            .disabled(isClaimingRakeback)

            if totalRakebackEarned > 0 {
                HStack {
                    Text("Bonus grows as you place predictions")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.secondaryText)
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.cardBackground))
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var rakebackSuccessOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(AppTheme.green)
                Text("Bonus Claimed")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
            }
            .padding(40)
            .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.cardBackground))
            .padding(.horizontal, 40)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showRakebackSuccess = false }
            }
        }
    }

    private var headerView: some View {
        ZStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image("x")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(AppTheme.primaryText)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                }

                Spacer()

                Text("Balance")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.secondaryText)
                    .padding(.trailing, 5)

                HStack(spacing: 5) {
                    Image("coin").resizable().aspectRatio(contentMode: .fit).frame(width: 19, height: 19)
                    if isLoadingCoins {
                        ProgressView().scaleEffect(0.8).progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("\(userCoins)").font(.system(size: 16, weight: .bold)).foregroundColor(AppTheme.primaryText).lineLimit(1)
                    }
                }
                .padding(.horizontal, 15)
                .frame(height: 40)
                .background(AppTheme.cardHighlight)
                .cornerRadius(200)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(AppTheme.cardBackground)
    }

    private var customCoinInputView: some View {
        VStack(spacing: 0) {
            CoinPackageCell(coinAmount: "100", image: "coin-2", price: "$0.99", popular: false, isLoading: selectedPackage == 100 && isGeneratingToken, iapAction: { selectedPackage = 100; openWebPurchase(coinAmount: 100) })
            Divider().background(AppTheme.divider)
            CoinPackageCell(coinAmount: "600", image: "coin-3", price: "$4.99", popular: true, isLoading: selectedPackage == 600 && isGeneratingToken, iapAction: { selectedPackage = 600; openWebPurchase(coinAmount: 600) })
            Divider().background(AppTheme.divider)
            CoinPackageCell(coinAmount: "1,500", image: "coin-bag", price: "$9.99", popular: false, isLoading: selectedPackage == 1500 && isGeneratingToken, iapAction: { selectedPackage = 1500; openWebPurchase(coinAmount: 1500) })
        }
        .cornerRadius(10)
        .disabled(isGeneratingToken)
    }

    private var coinPackagesView: some View {
        VStack(spacing: 0) {
            if let hourUnlock = viewModel.products.first(where: { $0.productIdentifier == "one_hour_boost" }) {
                CoinPackageCell(coinAmount: "100", image: "coin-2", price: formattedPrice(for: hourUnlock), popular: false, isLoading: false, iapAction: { viewModel.purchase(product: hourUnlock) })
            }
            Divider().background(AppTheme.divider)
            if let dayUnlock = viewModel.products.first(where: { $0.productIdentifier == "one_day_boost" }) {
                CoinPackageCell(coinAmount: "600", image: "coin-3", price: formattedPrice(for: dayUnlock), popular: true, isLoading: false, iapAction: { viewModel.purchase(product: dayUnlock) })
            }
            Divider().background(AppTheme.divider)
            if let weekUnlock = viewModel.products.first(where: { $0.productIdentifier == "one_week_boost" }) {
                CoinPackageCell(coinAmount: "1,500", image: "coin-bag", price: formattedPrice(for: weekUnlock), popular: false, isLoading: false, iapAction: { viewModel.purchase(product: weekUnlock) })
            }
        }
        .cornerRadius(10)
    }

    private var privacyAndTerms: some View {
        HStack(spacing: 5) {
            Text("Privacy Policy").onTapGesture { openURL("https://www.notion.so/Privacy-Policy-2aaae3bec80380838551eb321015a92f") }
            Text("•").font(.system(size: 14, weight: .bold, design: .default))
            Text("Terms of Use").onTapGesture { openURL("https://www.notion.so/Terms-of-Use-2aaae3bec803804b83c4fa30721168d8") }
        }
        .font(.system(size: 14, weight: .semibold, design: .default))
        .foregroundColor(AppTheme.primaryText)
        .padding(.vertical, 20)
    }

    private func claimRakeback() {
        guard unclaimedRakeback > 0 && !isClaimingRakeback else { return }
        isClaimingRakeback = true
        guard let userId = Auth.auth().currentUser?.uid else { isClaimingRakeback = false; return }
        let db = Firestore.firestore()
        let memberRef = db.collection("competitions").document(competitionId).collection("members").document(userId)
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let memberDoc: DocumentSnapshot
            do { try memberDoc = transaction.getDocument(memberRef) } catch let fetchError as NSError { errorPointer?.pointee = fetchError; return nil }
            guard let data = memberDoc.data() else { errorPointer?.pointee = NSError(domain: "AppErrorDomain", code: -1); return nil }
            let newCoins = (data["coins"] as? Int ?? 0) + (data["unclaimedRakeback"] as? Int ?? 0)
            transaction.updateData(["coins": newCoins, "unclaimedRakeback": 0, "lastRakebackClaim": FieldValue.serverTimestamp()], forDocument: memberRef)
            return data["unclaimedRakeback"] as? Int ?? 0
        }) { (claimedAmount, error) in
            DispatchQueue.main.async {
                self.isClaimingRakeback = false
                if error != nil { return }
                if let claimed = claimedAmount as? Int {
                    self.userCoins += claimed
                    self.unclaimedRakeback = 0
                    withAnimation { self.showRakebackSuccess = true }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    Analytics.shared.track(event: "rakeback_claimed", properties: ["amount": claimed, "competition_id": self.competitionId])
                }
            }
        }
    }

    private func fetchUserCoinsAndRakeback() {
        guard let currentUser = Auth.auth().currentUser else { isLoadingCoins = false; return }
        Firestore.firestore().collection("competitions").document(competitionId).collection("members").document(currentUser.uid).getDocument { document, error in
            DispatchQueue.main.async {
                self.isLoadingCoins = false
                guard let data = document?.data() else { return }
                self.userCoins = data["coins"] as? Int ?? 0
                self.unclaimedRakeback = data["unclaimedRakeback"] as? Int ?? 0
                self.totalRakebackEarned = data["totalRakebackEarned"] as? Int ?? 0
            }
        }
    }

    private func openWebPurchase(coinAmount: Int) {
        guard !isGeneratingToken else { return }
        isGeneratingToken = true
        Functions.functions().httpsCallable("createPurchaseToken").call(["competitionId": competitionId, "coinAmount": coinAmount]) { result, error in
            DispatchQueue.main.async {
                self.isGeneratingToken = false
                self.selectedPackage = nil
                guard let data = result?.data as? [String: Any], let token = data["token"] as? String, let sessionId = data["sessionId"] as? String else { return }
                let urlString = "https://coins.socialstarapp.com?token=\(token)&sessionId=\(sessionId)"
                if let url = URL(string: urlString) {
                    let config = SFSafariViewController.Configuration()
                    config.entersReaderIfAvailable = false
                    let safariVC = SFSafariViewController(url: url, configuration: config)
                    safariVC.preferredBarTintColor = UIColor(AppTheme.pageBackground)
                    safariVC.preferredControlTintColor = UIColor.white
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootViewController = window.rootViewController {
                        var topController = rootViewController
                        while let presented = topController.presentedViewController { topController = presented }
                        topController.present(safariVC, animated: true)
                    }
                    Analytics.shared.track(event: "web_purchase_opened", properties: ["coin_amount": coinAmount, "competition_id": competitionId])
                }
            }
        }
    }

    private func handleReturnFromWeb() {
        fetchUserCoinsAndRakeback()
        Functions.functions().httpsCallable("checkPurchaseStatus").call(["competitionId": competitionId]) { result, error in
            DispatchQueue.main.async {
                if let data = result?.data as? [String: Any], let coins = data["coins"] as? Int, coins != self.userCoins {
                    self.userCoins = coins
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
    }

    private func formattedPrice(for product: SKProduct) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price) ?? "$0.00"
    }

    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) { UIApplication.shared.open(url) }
    }
}

// MARK: - Coin Package Cell
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
                Image(image).resizable().aspectRatio(contentMode: .fit).frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 10) {
                    Text("\(coinAmount)").font(.system(size: 24, weight: .bold)).foregroundColor(AppTheme.primaryText)
                    if popular {
                        Text("MOST POPULAR")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.accent)
                            .cornerRadius(6)
                    }
                }

                Spacer()

                if isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                } else {
                    Text(price)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .background(AppTheme.accent)
                        .cornerRadius(200)
                }
            }
            .padding(20)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 0).fill(AppTheme.cardBackground))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
    }
}

extension Notification.Name {
    static let dismissCameraFlow = Notification.Name("dismissCameraFlow")
}
