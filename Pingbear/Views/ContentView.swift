import SwiftUI

struct ContentView: View {
    var body: some View {
        CustomTabView()
    }
}
struct CustomTabView: View {
    @State private var selection = 0
    @State private var isPresentingNewCompetition = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selection) {
                MapView()
                    .tabItem {
                        Image(systemName: "house")
                        Text("Home")
                    }
                    .tag(0)

                Text("")
                    .tabItem {
                        Image(systemName: "plus.circle") // Just a placeholder, the actual button is created below
                        Text("Votes")
                    }
                    .tag(1)

                Text("")
                    .tabItem {
                        Image(systemName: "plus.circle") // Just a placeholder, the actual button is created below
                        Text("Leaderboard")
                    }
                    .tag(2)

                Text("")
                    .tabItem {
                        Image(systemName: "plus.circle") // Just a placeholder, the actual button is created below
                        Text("Settings")
                    }
                    .tag(3)
            }
            
        }
    }
}
