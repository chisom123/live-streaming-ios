import SwiftUI
import StoreKit

struct PayView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: PayViewModel
    
    @State private var navigateToCompDetails = false
    @State private var selectedBoostIndex = 1 // Pre-select middle option
    @State private var showAnimation = false
    
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
                
                // Star visualization
                starBoostDemo
                    .padding(.top, 50)
                    .padding(.horizontal, 20)
                
                // Boost options with original styling
                boostOptionsOriginalStyle
                    .padding(.top, 50)
                    .padding(.horizontal, 20)
                
                Spacer()
                
                // CTA buttons
                ctaButtons
            }
            .background(Color(hex: "#10183C"))
            .fullScreenCover(isPresented: $navigateToCompDetails) {
                CompDetails(competition: competition) // Adjust according to your needs
            }
            .onChange(of: viewModel.purchaseCompleted) { completed in
                if completed {
                    navigateToCompDetails = true
                }
            }
            .onAppear {
                viewModel.competitionId = self.competitionId
                viewModel.entryDocId = self.entryDocId
                NotificationQueueManager.shared.processQueuedNotifications()
                Analytics.shared.trackScreen(name: "boost_paywall")
                withAnimation(.easeInOut) {
                    showAnimation = true
                }
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        ZStack {
            HStack {
                Spacer()
                Button(action: {
                    navigateToCompDetails = true
                    Analytics.shared.track(event: "boost_skipped")
                }) {
                    Image("x")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.white) // or any color you want
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Star Boost Demo
    private var starBoostDemo: some View {
        VStack(alignment: .leading) {
            Text("Boost Your Ratings")
                .font(.system(size: 27, weight: .bold, design: .default)) // Apply common styling here
                .lineLimit(1)
                .foregroundColor(Color(hex: "#FFF"))
                .padding(.bottom, 20)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "checkmark")
                        .foregroundColor(Color(hex: "#FF4081"))
                        .font(.system(size: 18, weight: .bold))
                    
                    Text("Get +1 star on every rating")
                        .font(.system(size: 17))
                        .foregroundColor(.white.opacity(0.9))
                        .fontWeight(.bold)
                        .lineSpacing(5)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "checkmark")
                        .foregroundColor(Color(hex: "#FF4081"))
                        .font(.system(size: 18, weight: .bold))
                    
                    Text("Applies to all photos shared during boost")
                        .font(.system(size: 17))
                        .foregroundColor(.white.opacity(0.9))
                        .fontWeight(.bold)
                        .lineSpacing(5)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "checkmark")
                        .foregroundColor(Color(hex: "#FF4081"))
                        .font(.system(size: 18, weight: .bold))
                    
                    Text("Boosted photos stay boosted forever")
                        .font(.system(size: 17))
                        .foregroundColor(.white.opacity(0.9))
                        .fontWeight(.bold)
                        .lineSpacing(5)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Boost Options with Original Styling
    private var boostOptionsOriginalStyle: some View {
        VStack {
            HStack {
                Text("Choose Boost Duration")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.bottom, 20)
                
                Spacer()
            }
            
            ScrollView {
                VStack(spacing: 0) {
                    // Hour Boost
                    if let hourBoost = viewModel.products.first(where: { $0.productIdentifier == "one_hour_boost" }) {
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
                                    Text(hourBoost.localizedTitle)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text(formattedPrice(for: hourBoost))
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(Color(hex: "#FFF").opacity(0.8))
                                }
                                
                                Spacer()
                            }
                            .padding(EdgeInsets(top: 30, leading: 30, bottom: 30, trailing: 30))
                        }
                        
                        Divider().background(Color.white.opacity(0.2))
                    }
                    
                    // Day Boost (Recommended)
                    if let dayBoost = viewModel.products.first(where: { $0.productIdentifier == "one_day_boost" }) {
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
                                        Text(dayBoost.localizedTitle)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        Text(formattedPrice(for: dayBoost))
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
                    
                    // Week Boost
                    if let weekBoost = viewModel.products.first(where: { $0.productIdentifier == "one_week_boost" }) {
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
                                    Text(weekBoost.localizedTitle)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text(formattedPrice(for: weekBoost))
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
                Text("Start Boost")
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
