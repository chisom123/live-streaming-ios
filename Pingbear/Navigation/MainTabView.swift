import SwiftUI

struct MainTabView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                TabView(selection: $selectedTab) {
                    MyCompsView()
                        .tag(0)
                    
                    GlobalLeaderboardView(selectedTab: $selectedTab)
                        .tag(1)
                    
                    SettingsView()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .id(selectedTab)
                
                CustomTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom - 15, 0))
                    .background(Color(hex: "#10183C"))
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
        .background(Color(hex: "#10183C"))
    }
}
