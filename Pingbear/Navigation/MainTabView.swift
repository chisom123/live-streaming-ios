import SwiftUI

struct MainTabView: View {
    @Binding var selectedTab: Int

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                TabView(selection: $selectedTab) {
                    HomeFeedView()
                        .tag(0)

                    WalletView()
                        .tag(1)

                    SettingsView()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .id(selectedTab)

                CustomTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom - 15, 0))
                    .background(AppTheme.pageBackground)
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
        .background(AppTheme.pageBackground)
    }
}
