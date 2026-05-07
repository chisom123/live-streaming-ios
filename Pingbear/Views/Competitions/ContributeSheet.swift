import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ContributeSheet: View {
    let competitionId: String
    let raceId: String?
    let currentPot: Double
    let onContributed: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ContributeViewModel()
    @State private var customAmount = ""
    @FocusState private var isAmountFocused: Bool

    private var parsedAmount: Double? {
        guard let v = Double(customAmount), v >= 0.50 else { return nil }
        return v
    }
    private var customAmountIsValid: Bool {
        guard let amount = parsedAmount else { return false }
        return viewModel.canAfford(amount)
    }
    private var customAmountError: String? {
        guard !customAmount.isEmpty else { return nil }
        guard let amount = parsedAmount else { return "Minimum contribution is $0.50" }
        if !viewModel.canAfford(amount) { return "Insufficient balance. You have $\(String(format: "%.2f", viewModel.walletBalance))" }
        return nil
    }
    private var smartQuickFillAmount: (label: String, amount: Double)? {
        let balance = viewModel.walletBalance
        guard balance >= 0.50 else { return nil }
        if balance <= 20 { return ("$\(String(format: "%.2f", balance))", balance) }
        if balance >= 100 { let amount = min(20.0, round(balance * 0.2 * 100) / 100); return ("$\(String(format: "%.0f", amount))", amount) }
        else if balance >= 50 { let amount = min(10.0, round(balance * 0.2 * 100) / 100); return ("$\(String(format: "%.0f", amount))", amount) }
        else if balance >= 25 { return ("$5", 5.0) }
        else { let amount = min(3.0, round(balance / 3 * 100) / 100); return ("$\(String(format: "%.2f", amount))", amount) }
    }

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button(action: { Analytics.shared.trackTap(elementId: "back_button", screenName: "contribute_sheet"); dismiss() }) {
                        Image(systemName: "arrow.left").resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27).foregroundColor(AppTheme.iconColor)
                    }
                    Spacer()
                    Text("Add to Prize Pool").font(.system(size: 18, weight: .bold)).foregroundColor(AppTheme.primaryText)
                        .onAppear { Analytics.shared.trackScreen(name: "contribute_sheet") }
                    Spacer()
                    Image(systemName: "arrow.left").resizable().aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27).foregroundColor(.clear)
                }
                .padding(.horizontal, 20).padding(.vertical, 20)
                .background(AppTheme.cardBackground)

                ScrollView {
                    VStack(spacing: 28) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 0) {
                                Text("$").font(.system(size: 20, weight: .bold)).foregroundColor(AppTheme.primaryText).padding(.leading, 16)
                                TextField("0.00", text: $customAmount)
                                    .keyboardType(.decimalPad).font(.system(size: 20, weight: .bold))
                                    .foregroundColor(AppTheme.primaryText).tint(AppTheme.accent)
                                    .focused($isAmountFocused).padding([.top, .bottom, .trailing]).padding(.leading, 2).frame(height: 60)
                                if !viewModel.isLoadingBalance {
                                    Text("Balance $\(String(format: "%.2f", viewModel.walletBalance))")
                                        .font(.system(size: 14, weight: .semibold)).foregroundColor(AppTheme.secondaryText)
                                        .padding(.vertical, 16).padding(.horizontal, 16)
                                }
                            }
                            .background(AppTheme.cardBackground).cornerRadius(12).padding(.horizontal, 20)

                            if let quickFill = smartQuickFillAmount {
                                Button {
                                    customAmount = String(format: "%.2f", quickFill.amount)
                                    isAmountFocused = false
                                    Analytics.shared.trackTap(elementId: "smart_quick_fill", screenName: "contribute_sheet")
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "bolt.fill").font(.system(size: 12))
                                        Text("Quick Add \(quickFill.label)").font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(.white).padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(AppTheme.accent).cornerRadius(20)
                                }
                                .padding(.horizontal, 20).padding(.top, 12)
                            }
                            if let error = customAmountError {
                                Text(error).font(.system(size: 15, weight: .bold)).foregroundColor(.red.opacity(0.8))
                                    .padding(.horizontal, 20).padding(.top, 12)
                            }
                        }
                        .padding(.top, 24)

                        if !viewModel.contributors.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Contributors").font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.secondaryText).padding(.horizontal, 20)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(viewModel.contributors) { contributor in
                                            ContributorCard(contributor: contributor)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }

                VStack {
                    Button {
                        if let amount = parsedAmount, customAmountIsValid {
                            Analytics.shared.track(event: "added_money_to_prize_pool", properties: ["amount_added": String(format: "%.2f", amount), "screen_name": "contribute_sheet"])
                            Task {
                                let success = await viewModel.contribute(competitionId: competitionId, amount: amount)
                                if success { onContributed(); dismiss() }
                            }
                        }
                    } label: {
                        Group {
                            if viewModel.isLoading { ProgressView().tint(.white) }
                            else { Text("Add") }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(customAmountIsValid && !viewModel.isLoading ? AppTheme.green : AppTheme.disabledBackground)
                        .foregroundColor(customAmountIsValid && !viewModel.isLoading ? .white : AppTheme.disabledText)
                        .cornerRadius(200)
                    }
                    .disabled(!customAmountIsValid || viewModel.isLoading)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                }
                .background(AppTheme.pageBackground)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
        .onAppear {
            viewModel.startBalanceListener()
            if let raceId { viewModel.loadContributors(raceId: raceId) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isAmountFocused = true }
        }
        .onDisappear { viewModel.stopBalanceListener() }
        .alert("Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
    }
}

struct ContributorCard: View {
    let contributor: RaceContributor
    var body: some View {
        VStack(spacing: 8) {
            ProfilePictureView(url: contributor.profilePictureUrl, size: 42)
            Text(contributor.username).font(.system(size: 12, weight: .bold)).foregroundColor(AppTheme.primaryText).lineLimit(1).frame(width: 70)
            Text("$\(String(format: "%.2f", contributor.amount))").font(.system(size: 13, weight: .bold)).foregroundColor(AppTheme.green)
        }
        .padding(.vertical, 12).padding(.horizontal, 8).frame(width: 90)
        .background(AppTheme.cardBackground).cornerRadius(12)
    }
}
