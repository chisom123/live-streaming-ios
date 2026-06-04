import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct DemoEntryFeeView: View {

    @ObservedObject var coordinator: DemoFlowCoordinator
    let image: UIImage

    @State private var selectedFee:      Double  = 1.00
    @State private var walletBalance:    Double  = 0
    @State private var isLoadingBalance          = true

    private let feeOptions: [Double] = [0.20, 0.50, 1.00, 2.00]
    private let db = Firestore.firestore()

    private var hasEnoughBalance: Bool { walletBalance >= selectedFee }

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Spacer()

                // ── 2x2 fee grid ──────────────────────────────
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        feeCell(fee: feeOptions[0])
                        feeCell(fee: feeOptions[1])
                    }
                    HStack(spacing: 12) {
                        feeCell(fee: feeOptions[2])
                        feeCell(fee: feeOptions[3])
                    }
                }
                .padding(.horizontal, 40)

                // ── Balance + prize pool ──────────────────────
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        if isLoadingBalance {
                            ProgressView().scaleEffect(0.7).tint(AppTheme.secondaryText)
                        } else {
                            Text("Balance")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.secondaryText)
                            Text("$\(String(format: "%.2f", walletBalance))")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.primaryText)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.cardBackground)
                    .cornerRadius(200)

                    Text("$\(String(format: "%.2f", selectedFee + 1.00)) prize pool")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.green)
                        .cornerRadius(200)
                }
                .padding(.top, 28)

                Spacer()

                // ── Balance + CTA ─────────────────────────────
                VStack(spacing: 16) {
                if coordinator.isLoading {
                        uploadProgressView
                            .padding(.horizontal, 20)
                    } else {
                        Button(action: confirmTapped) {
                            Text(hasEnoughBalance
                                 ? "Add $\(String(format: "%.2f", selectedFee)) to Prize Pool"
                                 : "Insufficient Balance")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                                .background(hasEnoughBalance ? AppTheme.accent : AppTheme.disabledBackground)
                                .cornerRadius(200)
                        }
                        .disabled(!hasEnoughBalance)
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "demo_entry_fee")
            fetchBalance()
        }
        .alert("Something went wrong", isPresented: Binding(
            get:  { coordinator.errorMessage != nil },
            set:  { if !$0 { coordinator.errorMessage = nil } }
        )) {
            Button("OK") { coordinator.errorMessage = nil }
        } message: {
            Text(coordinator.errorMessage ?? "")
        }
    }

    private func feeCell(fee: Double) -> some View {
        let isSelected = selectedFee == fee
        let affordable = walletBalance >= fee

        return Button(action: {
            guard affordable else { return }
            selectedFee = fee
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Analytics.shared.track(event: "demo_entry_fee_selected", properties: [
                "fee":            fee,
                "wallet_balance": walletBalance
            ])
        }) {
            Text("$\(String(format: "%.2f", fee))")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(
                    !affordable ? AppTheme.disabledText :
                    isSelected  ? .white :
                    AppTheme.primaryText
                )
                .frame(maxWidth: .infinity)
                .frame(height: 72)
                .background(isSelected ? AppTheme.accent : Color.clear)
                .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .disabled(!affordable)
    }

    // ── Header ────────────────────────────────────────────────

    private var header: some View {
        HStack {
            Button(action: {
                guard !coordinator.isLoading else { return }
                Analytics.shared.trackTap(elementId: "demo_entry_fee_back", screenName: "demo_entry_fee")
                coordinator.step = .lobby
            }) {
                Image(systemName: "arrow.left")
                    .resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 27, height: 27)
                    .foregroundColor(coordinator.isLoading ? AppTheme.disabledText : AppTheme.iconColor)
            }
            .disabled(coordinator.isLoading)

            Spacer()
            Text("Add to Prize Pool")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.primaryText)
            Spacer()
            Color.clear.frame(width: 27, height: 27)
        }
        .padding(.horizontal, 20).padding(.vertical, 20)
    }

    // ── Upload progress ───────────────────────────────────────

    private var uploadProgressView: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                AppTheme.disabledBackground
                AppTheme.accent
                    .frame(width: geo.size.width * coordinator.uploadProgress)
                    .animation(.easeInOut, value: coordinator.uploadProgress)
            }
            .cornerRadius(200)
            .frame(height: 55)
            .overlay(
                Text("Uploading \(Int(coordinator.uploadProgress * 100))%...")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            )
        }
        .frame(height: 55)
    }

    // ── Actions ───────────────────────────────────────────────

    private func confirmTapped() {
        guard hasEnoughBalance, !coordinator.isLoading else { return }
        Analytics.shared.trackTap(
            elementId: "demo_entry_fee_confirm",
            screenName: "demo_entry_fee",
            properties: ["fee": selectedFee, "wallet_balance": walletBalance]
        )
        coordinator.createDemoRound(image: image, entryFee: selectedFee)
    }

    private func fetchBalance() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoadingBalance = false; return
        }
        db.collection("users").document(userId).getDocument { snap, _ in
            DispatchQueue.main.async {
                self.walletBalance    = snap?.data()?["wallet_balance"] as? Double ?? 0
                self.isLoadingBalance = false
            }
        }
    }
}
