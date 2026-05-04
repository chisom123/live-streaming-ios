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
                    
                    Text("Top Up")
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

                        // ── Enter Amount ─────────────────────────
                        VStack(spacing: 0) {
                            TextField("$0.00", text: $displayAmount)
                                .textFieldStyle(.plain)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .tint(.white)
                                .focused($isAmountFocused)
                                .frame(height: 80)
                                .padding(.horizontal, 20)
                                .onChange(of: displayAmount) { newValue in
                                    // If the field is just "$" or empty, clear everything
                                    if newValue.isEmpty || newValue == "$" {
                                        displayAmount = ""
                                        viewModel.customAmount = ""
                                        return
                                    }
                                    
                                    // Remove dollar sign if user pastes something with it
                                    var cleaned = newValue.replacingOccurrences(of: "$", with: "")
                                    
                                    // Filter out any non-numeric characters except decimal point
                                    cleaned = cleaned.filter { "0123456789.".contains($0) }
                                    
                                    // Ensure only one decimal point
                                    let components = cleaned.components(separatedBy: ".")
                                    if components.count > 2 {
                                        cleaned = components[0] + "." + components[1]
                                    }
                                    
                                    // If cleaning resulted in empty string, clear everything
                                    if cleaned.isEmpty {
                                        displayAmount = ""
                                        viewModel.customAmount = ""
                                        return
                                    }
                                    
                                    // Add dollar sign prefix if it doesn't have one
                                    if !newValue.hasPrefix("$") {
                                        displayAmount = "$\(cleaned)"
                                    } else if cleaned != newValue.replacingOccurrences(of: "$", with: "") {
                                        // Update if cleaning changed the value
                                        displayAmount = "$\(cleaned)"
                                    }
                                    
                                    // Update the view model with clean number
                                    viewModel.customAmount = cleaned
                                }
                        }
                        .background(Color(hex: "#1A2245"))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        
                        if !viewModel.customAmount.isEmpty && !viewModel.customAmountIsValid {
                            Text("Minimum top-up is $1.00")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.horizontal, 20)
                        }

                        // ── Quick tap amounts ─────────────────────
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
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color(hex: "#1A2245"))
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                }
                
                // ── Continue button (fixed at bottom) ───────────
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
                                ? Color(hex: "#4169E1")
                                : Color(hex: "#D3D3D3").opacity(0.2)
                        )
                        .foregroundColor(
                            viewModel.customAmountIsValid && !viewModel.isLoading
                                ? Color(hex: "#FFF")
                                : Color(hex: "#D3D3D3").opacity(0.2)
                        )
                        .cornerRadius(200)
                }
                .disabled(!viewModel.customAmountIsValid || viewModel.isLoading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(hex: "#10183C"))
            }
        }
        .onAppear {
            // Sync display amount with view model if needed
            if !viewModel.customAmount.isEmpty {
                displayAmount = "$\(viewModel.customAmount)"
            }
            // Auto-focus the amount field to open keyboard
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
