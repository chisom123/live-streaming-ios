import SwiftUI

struct ContentView: View {
    var body: some View {
        CustomTabView()
    }
}

struct CustomTabView: View {
    @State private var selection = 0
    @State private var isPresentingNewCompetition = false
    
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
        
        // Apply the appearance for the selected state
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(selectedColor)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(selectedColor)]

        // Apply the appearance for the normal (unselected) state
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(unselectedColor)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(unselectedColor)]

        // Set the standard appearance to our customized appearance
        UITabBar.appearance().standardAppearance = appearance

        // Set the same appearance for the scrollEdgeAppearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selection) {
                MapView()
                    .tabItem {
                        Image(systemName: "house")
                        Text("Home")
                    }
                    .tag(0)

                SettingsView()
                    .tabItem {
                        Image(systemName: "slider.horizontal.3")
                        Text("Settings")
                    }
                    .tag(1)
            }
            .accentColor(selectedColor) // Apply the selected color to the tab items
        }
    }
}

