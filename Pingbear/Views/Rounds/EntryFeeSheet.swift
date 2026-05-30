import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// ─────────────────────────────────────────────────────────────
// MARK: - EntryFeeSheet
//
// Pure UI component. Knows nothing about rounds or Firestore.
// Responsibilities:
//   1. Show fee options
//   2. Upload the photo, show progress
//   3. Call onJoin(photoUrl, fee) on success
//   4. Own all error state for upload failures
//
// The parent (SessionView) owns the join logic.
// ─────────────────────────────────────────────────────────────

struct EntryFeeSheet: View {

    let image: UIImage
    let isFromCamera: Bool
    let sessionId: String
    let onJoin: (String, Double) -> Void   // (photoUrl, fee)
    let onCancel: () -> Void

    @State private var selectedFee: Double   = 0.00
    @State private var uploadProgress: Double = 0
    @State private var isUploading           = false
    @State private var uploadError: String?  = nil
    @State private var walletBalance: Double = 0
    @State private var isLoadingBalance      = true
    @State private var showingWallet         = false

    private let db          = Firestore.firestore()
    private let feeOptions: [Double] = [0.00, 0.20, 0.50, 1.00, 2.00, 5.00]

    private var hasEnoughBalance: Bool { selectedFee == 0 || walletBalance >= selectedFee }

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)

                VStack(spacing: 24) {
                    balancePill

                    feeGrid
                        .padding(.horizontal, 20)

                    if !hasEnoughBalance && !isLoadingBalance {
                        topUpPrompt
                    }

                    Spacer()

                    confirmButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hasEnoughBalance)
        .onAppear {
            Analytics.shared.trackScreen(name: "entry_fee_sheet")
            fetchBalance()
        }
        .alert("Upload Failed", isPresented: Binding(
            get: { uploadError != nil },
            set: { if !$0 { uploadError = nil } }
        )) {
            Button("OK") { uploadError = nil }
        } message: {
            Text(uploadError ?? "")
        }
        .fullScreenCover(isPresented: $showingWallet, onDismiss: fetchBalance) {
            WalletView(onDismiss: { showingWallet = false })
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Header
    // ─────────────────────────────────────────────────────────

    private var header: some View {
        HStack {
            Button(action: { if !isUploading { onCancel() } }) {
                Image(systemName: "arrow.left")
                    .resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .foregroundColor(isUploading ? AppTheme.disabledText : AppTheme.iconColor)
            }
            .disabled(isUploading)

            Spacer()
            Text("Add to Prize Pool")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.primaryText)
            Spacer()

            Color.clear.frame(width: 22, height: 22)
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Balance Pill
    // ─────────────────────────────────────────────────────────

    private var balancePill: some View {
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
        .padding(.top, 8)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Fee Grid
    // ─────────────────────────────────────────────────────────

    private var feeGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
            ForEach(feeOptions, id: \.self) { fee in
                let affordable = fee == 0 || walletBalance >= fee
                Button {
                    guard affordable && !isUploading else { return }
                    selectedFee = fee
                } label: {
                    Text(fee == 0 ? "Free" : "$\(String(format: "%.2f", fee))")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(
                            !affordable   ? AppTheme.disabledText :
                            selectedFee == fee ? .white :
                            AppTheme.primaryText
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            !affordable   ? AppTheme.disabledBackground :
                            selectedFee == fee ? AppTheme.accent :
                            AppTheme.cardBackground
                        )
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(!affordable || isUploading)
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Top Up Prompt
    // ─────────────────────────────────────────────────────────

    private var topUpPrompt: some View {
        Button { showingWallet = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.red)
                Text("Not enough balance — tap to top up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.red)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.red)
            }
        }
        .buttonStyle(.plain)
        .disabled(isUploading)
        .transition(.opacity)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Confirm Button
    // ─────────────────────────────────────────────────────────

    private var confirmButton: some View {
        Button(action: confirmTapped) {
            HStack(spacing: 8) {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.85)
                }
                Text(buttonLabel)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        AppTheme.disabledBackground
                        if isUploading {
                            AppTheme.accent
                                .frame(width: geo.size.width * uploadProgress)
                                .animation(.easeInOut, value: uploadProgress)
                        } else if hasEnoughBalance {
                            AppTheme.accent
                        }
                    }
                }
                .cornerRadius(200)
            )
            .cornerRadius(200)
        }
        .disabled(isUploading || !hasEnoughBalance)
    }

    private var buttonLabel: String {
        if isUploading  { return "Uploading \(Int(uploadProgress * 100))%..." }
        if !hasEnoughBalance { return "Insufficient Balance" }
        return selectedFee == 0 ? "Join Free" : "Add $\(String(format: "%.2f", selectedFee)) to Pot"
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - Actions
    // ─────────────────────────────────────────────────────────

    private func fetchBalance() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoadingBalance = false
            return
        }
        db.collection("users").document(userId).getDocument { snap, _ in
            DispatchQueue.main.async {
                self.walletBalance    = snap?.data()?["wallet_balance"] as? Double ?? 0
                self.isLoadingBalance = false
            }
        }
    }

    private func confirmTapped() {
        guard !isUploading, hasEnoughBalance else { return }

        // Snapshot the fee at tap time — can't change during upload
        let fee = selectedFee
        isUploading     = true
        uploadProgress  = 0

        Task {
            do {
                let url = try await RoundUploadManager.shared.upload(
                    image: image,
                    sessionId: sessionId,
                    onProgress: { progress in
                        // Already @MainActor thanks to the upload manager
                        self.uploadProgress = progress
                    }
                )
                // Upload done — hand off to parent. The sheet will be
                // dismissed by the parent changing phase.
                onJoin(url, fee)
                // Don't set isUploading = false here — we want the spinner
                // to stay visible until the sheet is actually dismissed.
                // If join fails, the parent will re-show the sheet.
            } catch {
                AppLogger.upload("[EntryFee] upload failed: \(error)")
                self.uploadError = error.localizedDescription
                self.isUploading = false
                self.uploadProgress = 0
            }
        }
    }
}
