import SwiftUI

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
        guard let amount = parsedAmount else {
            return "Minimum contribution is $0.50"
        }
        if !viewModel.canAfford(amount) {
            return "Insufficient balance. You have $\(String(format: "%.2f", viewModel.walletBalance))"
        }
        return nil
    }
    
    // Smart quick-fill amount that adapts to user's balance
    private var smartQuickFillAmount: (label: String, amount: Double)? {
        let balance = viewModel.walletBalance
        
        // Must have at least $0.50 to contribute
        guard balance >= 0.50 else { return nil }
        
        // If balance is $20 or under, suggest full balance
        if balance <= 20 {
            return ("$\(String(format: "%.2f", balance))", balance)
        }
        
        // For balances over $20, use tiered suggestions
        if balance >= 100 {
            // High rollers: $20 is meaningful but not too much
            let amount = min(20.0, round(balance * 0.2 * 100) / 100)
            return ("$\(String(format: "%.0f", amount))", amount)
        } else if balance >= 50 {
            // Mid-high: $10 feels right
            let amount = min(10.0, round(balance * 0.2 * 100) / 100)
            return ("$\(String(format: "%.0f", amount))", amount)
        } else if balance >= 25 {
            // Medium balance: $5 is a solid contribution
            return ("$5", 5.0)
        } else {
            // Between $20-25: $3 or 1/3 of balance
            let amount = min(3.0, round(balance / 3 * 100) / 100)
            return ("$\(String(format: "%.2f", amount))", amount)
        }
    }

    var body: some View {
        ZStack {
            Color(hex: "#10183C").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button(action: {
                        Analytics.shared.trackTap(
                            elementId: "back_button",
                            screenName: "contribute_sheet"
                        )
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Add to Prize Pool")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .onAppear {
                            Analytics.shared.trackScreen(name: "contribute_sheet")
                        }
                    
                    Spacer()
                    
                    // Invisible placeholder for balance
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(Color(hex: "#1A2245"))
                
                // Content
                ScrollView {
                    VStack(spacing: 28) {

                        // ── Custom amount ─────────────────────────
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 0) {
                                // Amount field
                                Text("$")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.leading, 16)

                                TextField("0.00", text: $customAmount)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .tint(.white)
                                    .focused($isAmountFocused)
                                    .padding([.top, .bottom, .trailing])
                                    .padding(.leading, 2)
                                    .frame(height: 60)
                                
                                // Balance
                                if !viewModel.isLoadingBalance {
                                    Text("Balance $\(String(format: "%.2f", viewModel.walletBalance))")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(.vertical, 16)
                                        .padding(.leading, 16)
                                        .padding(.trailing, 16)
                                }
                            }
                            .background(Color(hex: "#1A2245"))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)

                            // Smart Quick Fill Button
                            if let quickFill = smartQuickFillAmount {
                                Button {
                                    customAmount = String(format: "%.2f", quickFill.amount)
                                    isAmountFocused = false
                                    
                                    Analytics.shared.trackTap(
                                        elementId: "smart_quick_fill",
                                        screenName: "contribute_sheet"
                                    )
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "bolt.fill")
                                            .font(.system(size: 12))
                                        Text("Quick Add \(quickFill.label)")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "#4169E1").opacity(0.3))
                                    .cornerRadius(20)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                            }
                            
                            if let error = customAmountError {
                                Text(error)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.red.opacity(0.8))
                                    .padding(.horizontal, 20)
                                    .padding(.top, 12)
                            }
                        }
                        .padding(.top, 24)

                        // ── Contributors Horizontal Scroll ────────
                        if !viewModel.contributors.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Contributors")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 20)
                                
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
                
                // ── Add button (pinned to bottom) ──────
                VStack {
                    Button {
                        if let amount = parsedAmount, customAmountIsValid {
                            // Track analytics only when button is valid and tapped
                            Analytics.shared.track(
                                event: "added_money_to_prize_pool",
                                properties: [
                                    "amount_added": String(format: "%.2f", amount),
                                    "screen_name": "contribute_sheet"
                                ]
                            )
                            
                            Task {
                                let success = await viewModel.contribute(
                                    competitionId: competitionId,
                                    amount: amount
                                )
                                if success {
                                    onContributed()
                                    dismiss()
                                }
                            }
                        }
                    } label: {
                        Group {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Add")
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(
                            customAmountIsValid && !viewModel.isLoading
                                ? Color(hex: "#4169E1")
                                : Color(hex: "#D3D3D3").opacity(0.2)
                        )
                        .foregroundColor(
                            customAmountIsValid && !viewModel.isLoading
                                ? Color(hex: "#FFF")
                                : Color(hex: "#D3D3D3").opacity(0.2)
                        )
                        .cornerRadius(200)
                    }
                    .disabled(!customAmountIsValid || viewModel.isLoading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .background(Color(hex: "#10183C"))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
        .onAppear {
            viewModel.startBalanceListener()
            if let raceId {
                viewModel.loadContributors(raceId: raceId)
            }
            // Auto-focus the amount field to open keyboard
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isAmountFocused = true
            }
        }
        .onDisappear { viewModel.stopBalanceListener() }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Contributor Card View
struct ContributorCard: View {
    let contributor: RaceContributor
    
    var body: some View {
        VStack(spacing: 8) {
            // Profile Picture
            ProfilePictureView(url: contributor.profilePictureUrl, size: 42)
            
            // Name
            Text(contributor.username)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 70)
            
            // Amount
            Text("$\(String(format: "%.2f", contributor.amount))")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(hex: "#00AA00"))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(width: 90)
        .background(Color(hex: "#1A2245"))
        .cornerRadius(12)
    }
}
