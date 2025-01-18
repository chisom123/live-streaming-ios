import SwiftUI

struct ContentView: View {
    var initialTab: Int?
    
    var body: some View {
        CustomTabView()
    }
}

struct CustomTabView: View {
    @State private var selection = 0
    
    // Define the colors for the selected and unselected tab items
    let selectedColor = Color(hex: "#1199FF")
    let unselectedColor = Color(hex: "#808080")
    
    init() {
        
        // Use UITabBarAppearance for customizing the tab bar's appearance
        let appearance = UITabBarAppearance()
        
        appearance.backgroundColor = UIColor.white
        
        // Remove the border by setting these properties to an empty image
        appearance.shadowColor = nil
        appearance.shadowImage = UIImage()
        appearance.backgroundImage = UIImage()
        
        let fontSize: CGFloat = 11
        
        // Apply the appearance for the selected state
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(selectedColor)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(selectedColor),
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold)
        ]
        
        appearance.stackedLayoutAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 2)

        // Apply the appearance for the normal (unselected) state
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(unselectedColor)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(unselectedColor),
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold )
        ]
        
        appearance.stackedLayoutAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 2)
        
        // Make badge smaller
        appearance.stackedLayoutAppearance.normal.badgeBackgroundColor = UIColor(Color(hex: "#FF0000"))
        
        // Reduce badge text size (this affects the overall badge size)
        appearance.stackedLayoutAppearance.normal.badgeTextAttributes = [
            .font: UIFont.systemFont(ofSize: 13, weight: .bold)
        ]
        
        appearance.stackedLayoutAppearance.normal.badgePositionAdjustment = UIOffset(horizontal: 3, vertical: 0)

        // Set the standard appearance to our customized appearance
        UITabBar.appearance().standardAppearance = appearance

        // Set the same appearance for the scrollEdgeAppearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selection) {
                MyCompsView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                    .tag(0)
                    .padding([.top, .bottom], 10)
                

                SettingsView()
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                        Text("Settings")
                    }
                    .tag(1)
                    .padding([.top, .bottom], 10)
            }
            .accentColor(selectedColor) // Apply the selected color to the tab items
        }
    }
}

