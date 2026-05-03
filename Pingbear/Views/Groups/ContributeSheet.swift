import SwiftUI

struct ContributeSheet: View {

    let competitionId: String
    let raceId: String?
    let currentPot: Double
    let onContributed: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ContributeViewModel()
    @State private var customAmount = ""
    @State private var showContributors = false

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

    private var contributorSummary: String {
        let names = viewModel.contributors.prefix(2).map { $0.username }.joined(separator: ", ")
        let remaining = viewModel.contributors.count - 2
        return remaining > 0 ? "\(names) +\(remaining) contributed" : "\(names) contributed"
    }

    var body: some View {
        ZStack {
            Color(hex: "#10183C").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button(action: {
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

                        // ── Balance + pot display ─────────────────
                        HStack(spacing: 0) {

                            VStack(spacing: 4) {
                                Text("Your Balance")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))

                                if viewModel.isLoadingBalance {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                } else {
                                    Text("$\(String(format: "%.2f", viewModel.walletBalance))")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)

                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 1, height: 40)

                            VStack(spacing: 4) {
                                Text("Prize Pool")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                                Text("$\(String(format: "%.2f", currentPot))")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(Color(hex: "#00AA00"))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 20)
                        .background(Color(hex: "#1A2245"))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // ── Zero balance warning ──────────────────
                        if !viewModel.isLoadingBalance && viewModel.walletBalance <= 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 14))
                                Text("Your wallet is empty. Add funds in the Wallet tab first.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 20)
                        }

                        // ── Contributors ──────────────────────────
                        if !viewModel.contributors.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Button {
                                    showContributors.toggle()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "person.2.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.6))

                                        Text(contributorSummary)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.6))
                                            .lineLimit(1)

                                        Spacer()

                                        Image(systemName: showContributors ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(PlainButtonStyle())

                                if showContributors {
                                    VStack(spacing: 0) {
                                        ForEach(viewModel.contributors) { contributor in
                                            HStack {
                                                Text(contributor.username)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.white)
                                                Spacer()
                                                Text("$\(String(format: "%.2f", contributor.amount))")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(Color(hex: "#00AA00"))
                                            }
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                        }
                                    }
                                    .padding(.bottom, 8)
                                }
                            }
                            .background(Color(hex: "#1A2245"))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }

                        // ── Quick amounts ─────────────────────────
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Add")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 20)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(viewModel.quickAmounts, id: \.self) { amount in
                                    let affordable = viewModel.canAfford(amount)

                                    Button {
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
                                    } label: {
                                        VStack(spacing: 2) {
                                            Text("$\(Int(amount))")
                                                .font(.system(size: 17, weight: .bold))
                                                .foregroundColor(affordable ? .white : Color.white.opacity(0.3))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(affordable ? Color(hex: "#1A2245") : Color.white.opacity(0.05))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(
                                                    affordable
                                                        ? Color(hex: "#4169E1").opacity(0.4)
                                                        : Color.white.opacity(0.1),
                                                    lineWidth: 1
                                                )
                                        )
                                    }
                                    .disabled(!affordable || viewModel.isLoading || viewModel.isLoadingBalance)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // ── Custom amount ─────────────────────────
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Custom Amount")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 20)

                            HStack(spacing: 0) {
                                Text("$")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.leading, 16)

                                TextField("0.00", text: $customAmount)
                                    .textFieldStyle(.plain)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .tint(.white)
                                    .padding(.vertical, 16)
                                    .padding(.leading, 4)

                                if !viewModel.isLoadingBalance {
                                    Text("of $\(String(format: "%.2f", viewModel.walletBalance))")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.4))
                                        .padding(.trailing, 12)
                                }
                            }
                            .background(Color(hex: "#1A2245"))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)

                            if let error = customAmountError {
                                Text(error)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.red.opacity(0.8))
                                    .padding(.horizontal, 20)
                            }
                        }

                        // ── Add to pot button ─────────────────────
                        Button {
                            if let amount = parsedAmount {
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
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Add to Pot")
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

                        // ── Info ──────────────────────────────────
                        Text("Money is distributed proportionally based on stars earned at the end of the race.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            
            // Full-screen loading overlay
            if viewModel.isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                    
                    Text("Processing...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
        .onAppear {
            viewModel.startBalanceListener()
            if let raceId {
                viewModel.loadContributors(raceId: raceId)
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
