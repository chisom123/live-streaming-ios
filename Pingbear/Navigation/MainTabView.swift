import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int
    
    init(isNewUser: Bool = false) {
        // Start on GlobalLeaderboardView (tab 1) for new users, MyCompsView (tab 0) for existing users
        _selectedTab = State(initialValue: isNewUser ? 1 : 0)
    }
    
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
