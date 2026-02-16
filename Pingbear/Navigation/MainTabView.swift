import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0  // Default start on tab 0 (home)
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Content
                TabView(selection: $selectedTab) {
                    MyCompsView()
                        .tag(0)
                    
                    GlobalLeaderboardView(selectedTab: $selectedTab)
                        .tag(1)
                    
                    SettingsView()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .id(selectedTab) // Force TabView to update when selectedTab changes
                
                // Custom Tab Bar
                CustomTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom - 15, 0))
                    .background(Color(hex: "#10183C"))
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
        .background(Color(hex: "#10183C"))
    }
}
