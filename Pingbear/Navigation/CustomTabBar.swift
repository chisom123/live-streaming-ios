import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
 
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(AppTheme.divider)
 
            HStack(spacing: 0) {
                TabBarButton(
                    icon: "house",
                    title: "Home",
                    isSelected: selectedTab == 0,
                    action: { selectedTab = 0 }
                )
 
                TabBarButton(
                    icon: "wallet",
                    title: "Wallet",
                    isSelected: selectedTab == 1,
                    action: { selectedTab = 1 }
                )
 
                TabBarButton(
                    icon: "settings",
                    title: "Settings",
                    isSelected: selectedTab == 2,
                    action: { selectedTab = 2 }
                )
            }
            .padding(.vertical, 12)
        }
    }
}
 
struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
 
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.secondaryText)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 25, height: 25)
 
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
