import SwiftUI
import StoreKit

struct PayView: View {
    @ObservedObject var viewModel: PayViewModel
    @State private var selectedBoostIndex = 1 // Pre-select middle option
    @State private var shouldDismissCameraFlow = false
    
    var competition: Competition
    var competitionId: String
    var entryDocId: String
    
    var body: some View {
        if viewModel.isLoading {
            ProgressView()
                .padding()
                .tint(.white)
                .scaleEffect(1.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#10183C"))
        } else {
            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.top, 20)
                
                // Star unlock demonstration
                starUnlockDemo
                    .padding(.top, 50)
                    .padding(.horizontal, 20)
                
                // Unlock options
                unlockOptionsStyle
                    .padding(.top, 50)
                    .padding(.horizontal, 20)
                
                Spacer()
                
                // CTA buttons
                ctaButtons
            }
            .background(Color(hex: "#10183C"))
            .onChange(of: viewModel.purchaseCompleted) { completed in
                if completed {
                    // ✅ FIXED: Trigger dismissal of entire camera flow
                    shouldDismissCameraFlow = true
                }
            }
            .onChange(of: shouldDismissCameraFlow) { shouldDismiss in
                if shouldDismiss {
                    // Post notification to dismiss entire camera flow
                    NotificationCenter.default.post(name: .dismissCameraFlow, object: nil)
                }
            }
            .onAppear {
                viewModel.competitionId = self.competitionId
                viewModel.entryDocId = self.entryDocId
                NotificationQueueManager.shared.processQueuedNotifications()
                Analytics.shared.trackScreen(name: "unlock_paywall")
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        ZStack {
            HStack {
                Spacer()
                Button(action: {
                    shouldDismissCameraFlow = true
                    Analytics.shared.track(event: "unlock_skipped")
                }) {
                    Image("x")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.white)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Star Unlock Demo with Animation
    private var starUnlockDemo: some View {
        VStack(alignment: .center, spacing: 20) {
            Text("Unlock 5-Star Ratings")
                .font(.system(size: 27, weight: .bold, design: .default))
                .lineLimit(1)
                .foregroundColor(Color(hex: "#FFF"))
                .padding(.bottom, 20)
            
            // Single animated rating bar
            ZStack {
                RoundedRectangle(cornerRadius: 200)
                    .fill(Color(hex: "#1A2245"))
                    .frame(height: 80)
                
                HStack(alignment: .center, spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        if star == 5 {
                            // 5th star - locked with nosign overlay and scaled up
                            ZStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(Color.white)
                                    .font(.system(size: 34))
                                
                                Image(systemName: "nosign")
                                    .foregroundColor(Color(hex: "#B22222"))
                                    .font(.system(size: 41, weight: .bold))
                            }
                            .scaleEffect(1.2)
                        } else {
                            Image(systemName: "star.fill")
                                .foregroundColor(Color.white)
                                .font(.system(size: 34))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
            }
        }
    }
    
    // MARK: - Unlock Options
    private var unlockOptionsStyle: some View {
        VStack {
            HStack {
                Text("Choose Unlock Duration")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.bottom, 20)
                
                Spacer()
            }
            
            ScrollView {
                VStack(spacing: 0) {
                    // Hour Unlock
                    if let hourUnlock = viewModel.products.first(where: { $0.productIdentifier == "one_hour_boost" }) {
                        Button(action: {
                            withAnimation(.spring()) {
                                selectedBoostIndex = 0
                            }
                        }) {
                            HStack {
                                // Radio button
                                ZStack {
                                    Circle()
                                        .stroke(selectedBoostIndex == 0 ? Color(hex: "#FF4081") : Color.white.opacity(0.3), lineWidth: 2)
                                        .frame(width: 20, height: 20)
                                    
                                    if selectedBoostIndex == 0 {
                                        Circle()
                                            .fill(Color(hex: "#FF4081"))
                                            .frame(width: 12, height: 12)
                                    }
                                }
                                .padding(.trailing, 10)
                                
                                HStack {
                                    Text(hourUnlock.localizedTitle)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text(formattedPrice(for: hourUnlock))
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(Color(hex: "#FFF").opacity(0.8))
                                }
                                
                                Spacer()
                            }
                            .padding(EdgeInsets(top: 30, leading: 30, bottom: 30, trailing: 30))
                        }
                        
                        Divider().background(Color.white.opacity(0.2))
                    }
                    
                    // Day Unlock (Recommended)
                    if let dayUnlock = viewModel.products.first(where: { $0.productIdentifier == "one_day_boost" }) {
                        Button(action: {
                            withAnimation(.spring()) {
                                selectedBoostIndex = 1
                            }
                        }) {
                            HStack {
                                // Radio button
                                ZStack {
                                    Circle()
                                        .stroke(selectedBoostIndex == 1 ? Color(hex: "#FF4081") : Color.white.opacity(0.3), lineWidth: 2)
                                        .frame(width: 20, height: 20)
                                    
                                    if selectedBoostIndex == 1 {
                                        Circle()
                                            .fill(Color(hex: "#FF4081"))
                                            .frame(width: 12, height: 12)
                                    }
                                }
                                .padding(.trailing, 10)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(dayUnlock.localizedTitle)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        Text(formattedPrice(for: dayUnlock))
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(Color(hex: "#FFF").opacity(0.8))
                                    }
                                    .padding(.bottom, 6)
                                    
                                    Text("MOST POPULAR")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(hex: "#FF4081"))
                                        .cornerRadius(6)
                                }
                                
                                Spacer()
                            }
                            .padding(EdgeInsets(top: 30, leading: 30, bottom: 30, trailing: 30))
                        }
                        
                        Divider().background(Color.white.opacity(0.2))
                    }
                    
                    // Week Unlock
                    if let weekUnlock = viewModel.products.first(where: { $0.productIdentifier == "one_week_boost" }) {
                        Button(action: {
                            withAnimation(.spring()) {
                                selectedBoostIndex = 2
                            }
                        }) {
                            HStack {
                                // Radio button
                                ZStack {
                                    Circle()
                                        .stroke(selectedBoostIndex == 2 ? Color(hex: "#FF4081") : Color.white.opacity(0.3), lineWidth: 2)
                                        .frame(width: 20, height: 20)
                                    
                                    if selectedBoostIndex == 2 {
                                        Circle()
                                            .fill(Color(hex: "#FF4081"))
                                            .frame(width: 12, height: 12)
                                    }
                                }
                                .padding(.trailing, 10)
                                
                                HStack {
                                    Text(weekUnlock.localizedTitle)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text(formattedPrice(for: weekUnlock))
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(Color(hex: "#FFF").opacity(0.8))
                                }
                                
                                Spacer()
                            }
                            .padding(EdgeInsets(top: 30, leading: 30, bottom: 30, trailing: 30))
                        }
                    }
                }
                .background(Color(hex: "#1A2245"))
                .cornerRadius(5)
            }
        }
    }
    
    // MARK: - CTA Buttons
    private var ctaButtons: some View {
        VStack {
            Button(action: {
                if let product = getSelectedProduct() {
                    viewModel.purchase(product: product)
                }
            }) {
                Text("Unlock")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color(hex: "#FF4081"))
                    .cornerRadius(200)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            HStack(spacing: 5) {
                Text("Privacy Policy")
                    .onTapGesture {
                        openURL("https://chay-b6172c.webflow.io/privacy-policy")
                    }
                
                Text("•")
                    .font(.system(size: 14, weight: .bold, design: .default))
                
                Text("Terms of Use")
                    .onTapGesture {
                        openURL("https://chay-b6172c.webflow.io")
                    }
            }
            .font(.system(size: 14, weight: .semibold, design: .default))
            .foregroundColor(.white.opacity(0.9))
            .padding(.vertical, 20)
        }
    }
    
    // MARK: - Helper Functions
    private func getSelectedProduct() -> SKProduct? {
        let identifiers = ["one_hour_boost", "one_day_boost", "one_week_boost"]
        guard selectedBoostIndex < identifiers.count else { return nil }
        return viewModel.products.first { $0.productIdentifier == identifiers[selectedBoostIndex] }
    }
}

extension Notification.Name {
    static let dismissCameraFlow = Notification.Name("dismissCameraFlow")
}
