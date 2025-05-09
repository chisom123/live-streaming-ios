import SwiftUI

struct HostEarningsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = HostEarningsViewModel()
    @State private var showingPayoutRequestModal = false
    @State private var showInfoAlert = false
    @State private var selectedTab = 0
    
    enum TabType: String, CaseIterable {
        case transactions = "Transactions"
        case payouts = "Payouts"
    }
    
    let competition: Competition
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "#10183C").edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .leading, spacing: 0) {
                // Top navigation bar
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                        Analytics.shared.trackTap(
                            elementId: "back_button",
                            screenName: "host_earnings"
                        )
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Competition Earnings")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Info button that shows earnings explanation
                    Button(action: {
                        showInfoAlert = true
                        Analytics.shared.trackTap(
                            elementId: "earnings_info_button",
                            screenName: "host_earnings"
                        )
                    }) {
                        Image(systemName: "info.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                // Loading state
                if viewModel.isLoading {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Spacer()
                    }
                    Spacer()
                } else if !viewModel.isHost {
                    // Not host message
                    Spacer()
                    VStack {
                        Text("You are not the host of this competition")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    // Earnings summary - 2x2 grid layout
                    VStack(spacing: 0) {
                        // Top row - two cards
                        HStack(spacing: 15) {
                            // Total earnings card
                            EarningsCardView(
                                title: "Total Earnings",
                                amount: viewModel.totalEarnings,
                                color: Color(hex: "#1A2245"),
                                iconName: "dollarsign.circle.fill"
                            )
                            
                            // Available earnings card
                            EarningsCardView(
                                title: "Available",
                                amount: viewModel.availableEarnings,
                                color: Color(hex: "#2A3255"),
                                iconName: "arrow.down.circle.fill"
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // Bottom row - two cards
                        HStack(spacing: 15) {
                            // Paid out earnings card
                            EarningsCardView(
                                title: "Paid Out",
                                amount: viewModel.paidOutEarnings,
                                color: Color(hex: "#2A3255"),
                                iconName: "checkmark.circle.fill"
                            )
                            
                            // Pending payout earnings card
                            EarningsCardView(
                                title: "Pending Payout",
                                amount: viewModel.pendingPayoutEarnings,
                                color: Color(hex: "#2A3255"),
                                iconName: "clock.fill"
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 15)
                        
                        // Payout button
                        Button(action: {
                            showingPayoutRequestModal = true
                            Analytics.shared.trackTap(
                                elementId: "request_payout_button",
                                screenName: "host_earnings",
                                properties: [
                                    "competition_id": competition.id,
                                    "available_amount": viewModel.availableEarnings,
                                    "enabled": viewModel.availableEarnings > 0
                                ]
                            )
                        }) {
                            Text("Request Payout")
                                .font(.system(size: 17, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(viewModel.availableEarnings > 0 ? Color(hex: "#FF4081") : Color(hex: "#D3D3D3").opacity(0.2))
                                .foregroundColor(viewModel.availableEarnings > 0 ? Color(hex: "#FFF") : Color(hex: "#D3D3D3").opacity(0.2))
                                .cornerRadius(200)
                        }
                        .disabled(viewModel.availableEarnings <= 0)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    }
                    
                    // Tab selector
                    HStack(spacing: 0) {
                        ForEach(0..<TabType.allCases.count, id: \.self) { index in
                            let tabType = TabType.allCases[index]
                            Button(action: {
                                withAnimation {
                                    selectedTab = index
                                }
                                Analytics.shared.trackTap(
                                    elementId: "tab_\(tabType.rawValue.lowercased())",
                                    screenName: "host_earnings",
                                    properties: ["competition_id": competition.id]
                                )
                            }) {
                                VStack(spacing: 10) {
                                    Text(tabType.rawValue)
                                        .font(.system(size: 16, weight: selectedTab == index ? .bold : .medium))
                                        .foregroundColor(.white)
                                    
                                    // Indicator line
                                    Rectangle()
                                        .frame(height: 3)
                                        .foregroundColor(selectedTab == index ? Color(hex: "#FF4081") : Color.clear)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 15)
                    
                    // Content based on selected tab
                    if selectedTab == 0 {
                        // Transactions Tab
                        if viewModel.purchases.isEmpty {
                            Spacer()
                            Text("No transactions yet")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                            Spacer()
                        } else {
                            // Purchase list
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(viewModel.purchases) { purchase in
                                        PurchaseRowView (
                                            purchase: purchase
                                        )
                                        
                                        if purchase.id != viewModel.purchases.last?.id {
                                            Divider()
                                                .background(Color.white.opacity(0.2))
                                        }
                                    }
                                }
                                .background(Color(hex: "#1A2245"))
                                .cornerRadius(10)
                                .padding(.horizontal, 20)
                                .padding(.top, 15)
                            }
                        }
                    } else {
                        // Payouts Tab
                        if viewModel.isLoadingPayouts {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                            Spacer()
                        } else if viewModel.payoutRequests.isEmpty {
                            Spacer()
                            Text("No payout requests yet")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                            Spacer()
                        } else {
                            // Payouts list
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(viewModel.payoutRequests) { payout in
                                        PayoutRequestRowView(
                                            payoutRequest: payout
                                        )
                                        
                                        if payout.id != viewModel.payoutRequests.last?.id {
                                            Divider()
                                                .background(Color.white.opacity(0.2))
                                        }
                                    }
                                }
                                .background(Color(hex: "#1A2245"))
                                .cornerRadius(10)
                                .padding(.horizontal, 20)
                                .padding(.top, 15)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.fetchEarnings(for: competition.id)
            Analytics.shared.trackScreen(
                name: "host_earnings",
                properties: [
                    "competition_id": competition.id,
                    "competition_name": competition.description
                ]
            )
        }
        .sheet(isPresented: $showingPayoutRequestModal) {
            PayoutRequestView(viewModel: viewModel)
        }
        .alert(isPresented: $showInfoAlert) {
            Alert(
                title: Text("How Earnings Work"),
                message: Text("As the competition host, you earn 50% of every Boost purchase made in this competition (after Apple's 30% fee)"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct EarningsCardView: View {
    var title: String
    var amount: Double
    var color: Color
    var iconName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.85))
            }
            
            Text(formattedAmount)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 5)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(color)
        .cornerRadius(15)
    }
    
    // Format the amount as USD
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.currencySymbol = "$" // Force just the dollar sign
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
}

func formatUSD(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    formatter.currencySymbol = "$" // Add this line
    return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
}

struct PurchaseRowView: View {
    var purchase: PurchaseRecord
    
    var body: some View {
        HStack {
            // Purchase details
            VStack(alignment: .leading, spacing: 6) {
                Text(purchase.formattedProductName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(purchase.formattedDate)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 2)
            }
            
            Spacer()
            
            // Amount with USD formatting
            Text(formatUSD(purchase.hostShare))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .contentShape(Rectangle())
    }
}

struct PayoutRequestRowView: View {
    var payoutRequest: PayoutRequest
    
    var body: some View {
        HStack {
            // Payout details
            VStack(alignment: .leading, spacing: 6) {
                Text(payoutRequest.status.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(payoutRequest.formattedRequestDate)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 2)
                
                if payoutRequest.status == .completed, let processedDate = payoutRequest.processedDate {
                    Text("Processed: \(payoutRequest.formattedProcessedDate)")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // Status indicator and amount with USD formatting
            HStack {
                // Status color indicator
                Circle()
                    .fill(Color(hex: payoutRequest.status.statusColor))
                    .frame(width: 10, height: 10)
                
                // Amount
                Text(formatUSD(payoutRequest.amount))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .contentShape(Rectangle())
    }
}
