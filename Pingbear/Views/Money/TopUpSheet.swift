import SwiftUI

// ─────────────────────────────────────────────────────────────
// MARK: - TopUpSheet
// ─────────────────────────────────────────────────────────────

struct TopUpSheet: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TopUpViewModel()
    @State private var displayAmount: String = ""
    @FocusState private var isAmountFocused: Bool

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ────────────────────────────────────
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(AppTheme.iconColor)
                    }

                    Spacer()

                    Text("Top Up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                        .onAppear {
                            Analytics.shared.trackScreen(name: "top_up_sheet")
                        }

                    Spacer()

                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(AppTheme.cardBackground)

                // ── Content ───────────────────────────────────
                ScrollView {
                    VStack(spacing: 28) {

                        // ── Enter Amount ─────────────────────
                        VStack(spacing: 0) {
                            TextField("$0.00", text: $displayAmount)
                                .textFieldStyle(.plain)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(AppTheme.primaryText)
                                .multilineTextAlignment(.center)
                                .tint(AppTheme.accent)
                                .focused($isAmountFocused)
                                .frame(height: 80)
                                .padding(.horizontal, 20)
                                .onChange(of: displayAmount) { newValue in
                                    if newValue.isEmpty || newValue == "$" {
                                        displayAmount = ""
                                        viewModel.customAmount = ""
                                        return
                                    }

                                    var cleaned = newValue.replacingOccurrences(of: "$", with: "")
                                    cleaned = cleaned.filter { "0123456789.".contains($0) }

                                    let components = cleaned.components(separatedBy: ".")
                                    if components.count > 2 {
                                        cleaned = components[0] + "." + components[1]
                                    }

                                    // NEW: cap decimal places at 2
                                    let parts = cleaned.components(separatedBy: ".")
                                    if parts.count == 2, parts[1].count > 2 {
                                        cleaned = parts[0] + "." + String(parts[1].prefix(2))
                                    }

                                    if cleaned.isEmpty {
                                        displayAmount = ""
                                        viewModel.customAmount = ""
                                        return
                                    }

                                    if !newValue.hasPrefix("$") {
                                        displayAmount = "$\(cleaned)"
                                    } else if cleaned != newValue.replacingOccurrences(of: "$", with: "") {
                                        displayAmount = "$\(cleaned)"
                                    }

                                    viewModel.customAmount = cleaned
                                }
                        }
                        .background(AppTheme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)

                        if !viewModel.customAmount.isEmpty && !viewModel.customAmountIsValid {
                            Text("Minimum top-up is $\(String(format: "%.2f", viewModel.minimumAmount))")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.horizontal, 20)
                        }

                        // ── Quick tap amounts ─────────────────
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 10) {
                            ForEach(viewModel.quickAmounts, id: \.self) { amount in
                                Button {
                                    let wholeAmount = Int(amount)
                                    displayAmount = "$\(wholeAmount)"
                                    viewModel.customAmount = "\(wholeAmount)"
                                } label: {
                                    Text("$\(Int(amount))")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(AppTheme.primaryText)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(AppTheme.cardBackground)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                }

                // ── Continue button ───────────────────────────
                Button {
                    if let amount = viewModel.parsedCustomAmount {
                        Task {
                            await viewModel.initiateTopUp(amount: amount)
                        }
                    }
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(
                            viewModel.customAmountIsValid && !viewModel.isLoading
                                ? AppTheme.accent
                                : AppTheme.disabledBackground
                        )
                        .foregroundColor(
                            viewModel.customAmountIsValid && !viewModel.isLoading
                                ? .white
                                : AppTheme.disabledText
                        )
                        .cornerRadius(200)
                }
                .disabled(!viewModel.customAmountIsValid || viewModel.isLoading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(AppTheme.pageBackground)
            }
        }
        .onAppear {
            if !viewModel.customAmount.isEmpty {
                displayAmount = "$\(viewModel.customAmount)"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isAmountFocused = true
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Success", isPresented: Binding(
            get: { viewModel.successMessage != nil },
            set: { if !$0 { viewModel.successMessage = nil } }
        )) {
            Button("OK") {
                viewModel.successMessage = nil
                dismiss()
            }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
    }
}
