import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// ─────────────────────────────────────────────────────────────
// MARK: - Entry Fee Sheet
//
// Receives a UIImage (not a URL). On confirm it uploads the
// photo then calls joinRound — upload and join are atomic so
// no orphaned photos can exist in Storage.
// ─────────────────────────────────────────────────────────────

struct EntryFeeSheet: View {
    @Binding var entryFee: Double
    let image: UIImage
    let isFromCamera: Bool
    let competition: Competition
    let themeName: String
    let onSuccess: (String) -> Void
    let onCancel: () -> Void

    @StateObject private var uploadManager = RoundUploadManager.shared
    @State private var isJoining = false
    @State private var showingError = false
    @State private var errorMessage: String? = nil
    @State private var walletBalance: Double = 0.0
    @State private var isLoadingBalance = true
    @State private var showingWallet = false

    private let db = Firestore.firestore()
    private let feeOptions: [Double] = [0.00, 0.20, 0.50, 1.00, 2.00, 5.00]

    var isBusy: Bool { uploadManager.isUploading || isJoining }

    private var hasEnoughBalance: Bool {
        entryFee == 0 || walletBalance >= entryFee
    }

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────
                HStack {
                    Button(action: {
                        if !isBusy {
                            Analytics.shared.trackTap(
                                elementId: "entry_fee_cancel",
                                screenName: "entry_fee_sheet"
                            )
                            onCancel()
                        }
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(isBusy ? AppTheme.disabledText : AppTheme.iconColor)
                    }
                    .disabled(isBusy)

                    Spacer()

                    Text("Add to Prize Pool")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)

                    Spacer()

                    Color.clear.frame(width: 27, height: 27)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(AppTheme.pageBackground)

                VStack(spacing: 24) {

                    // ── Balance pill ──────────────────────────────
                    HStack(spacing: 6) {
                        if isLoadingBalance {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(AppTheme.secondaryText)
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

                    // ── Fee options ───────────────────────────────
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(feeOptions, id: \.self) { fee in
                            let affordable = fee == 0 || walletBalance >= fee
                            Button(action: {
                                if affordable {
                                    Analytics.shared.trackTap(
                                        elementId: "entry_fee_select",
                                        screenName: "entry_fee_sheet",
                                        properties: [
                                            AnalyticsProperty.competitionId: competition.id,
                                            "fee_amount": fee
                                        ]
                                    )
                                    entryFee = fee
                                }
                            }) {
                                Text(fee == 0 ? "Free" : "$\(String(format: "%.2f", fee))")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(
                                        !affordable ? AppTheme.disabledText
                                        : entryFee == fee ? .white
                                        : AppTheme.primaryText
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        !affordable ? AppTheme.disabledBackground
                                        : entryFee == fee ? AppTheme.accent
                                        : AppTheme.cardBackground
                                    )
                                    .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(!affordable || isBusy)
                        }
                    }
                    .padding(.horizontal, 20)

                    // ── Insufficient balance warning ───────────────
                    if !hasEnoughBalance && !isLoadingBalance {
                        Button(action: {
                            Analytics.shared.trackTap(
                                elementId: "entry_fee_top_up",
                                screenName: "entry_fee_sheet",
                                properties: [AnalyticsProperty.competitionId: competition.id]
                            )
                            showingWallet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.red)
                                Text("Not enough balance — Tap to top up")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.red)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.red)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isBusy)
                        .transition(.opacity)
                    }

                    Spacer()

                    Button(action: confirmJoin) {
                        HStack(spacing: 8) {
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

                                    if uploadManager.isUploading {
                                        AppTheme.accent
                                            .frame(width: geo.size.width * uploadManager.uploadProgress)
                                            .animation(.easeInOut, value: uploadManager.uploadProgress)
                                    } else if !isBusy && hasEnoughBalance {
                                        AppTheme.accent
                                    }
                                }
                            }
                            .cornerRadius(200)
                        )
                        .cornerRadius(200)
                    }
                    .disabled(isBusy || !hasEnoughBalance)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hasEnoughBalance)
        .onAppear {
            Analytics.shared.trackScreen(
                name: "entry_fee_sheet",
                properties: [
                    AnalyticsProperty.competitionId: competition.id,
                    "theme_name": themeName,
                    "image_source": isFromCamera ? "camera" : "library"
                ]
            )
            fetchBalance()
        }
        .alert("Upload Failed", isPresented: $showingError) {
            Button("Try Again", role: .cancel) {
                uploadManager.isUploading = false
                isJoining = false
            }
        } message: {
            Text(errorMessage ?? "Something went wrong. Please try again.")
        }
        .fullScreenCover(isPresented: $showingWallet, onDismiss: fetchBalance) {
            WalletView(onDismiss: { showingWallet = false })
        }
    }

    private var buttonLabel: String {
        if uploadManager.isUploading { return "Uploading..." }
        if isJoining               { return "Joining..." }
        if !hasEnoughBalance       { return "Insufficient Balance" }
        return entryFee == 0 ? "Join Free" : "Add $\(String(format: "%.2f", entryFee)) to Pot"
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Fetch Balance
    // ─────────────────────────────────────────────────────────────

    private func fetchBalance() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoadingBalance = false
            return
        }
        db.collection("users").document(userId).getDocument { snapshot, _ in
            DispatchQueue.main.async {
                walletBalance   = snapshot?.data()?["wallet_balance"] as? Double ?? 0.0
                isLoadingBalance = false
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Confirm Join
    // ─────────────────────────────────────────────────────────────

    private func confirmJoin() {
        Analytics.shared.trackTap(
            elementId: "entry_fee_confirm",
            screenName: "entry_fee_sheet",
            properties: [
                AnalyticsProperty.competitionId: competition.id,
                "fee_amount": entryFee,
                "image_source": isFromCamera ? "camera" : "library"
            ]
        )

        RoundUploadManager.shared.uploadRoundPhoto(
            image: image,
            competitionId: competition.id,
            themeId: nil,
            themeName: themeName,
            isFromCamera: isFromCamera,
            onProgress: { _ in },
            onSuccess: { photoUrl in
                isJoining = false
                onSuccess(photoUrl)
            },
            onFailure: { error in
                isJoining = false
                errorMessage = error.localizedDescription
                showingError = true
                Analytics.shared.trackError(
                    message: "Round photo upload failed: \(error.localizedDescription)",
                    properties: [
                        AnalyticsProperty.competitionId: competition.id,
                        "fee_amount": entryFee
                    ]
                )
            }
        )
    }
}
