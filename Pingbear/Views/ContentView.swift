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

                // Just an empty view for the center tab item
                // The actual button will be floating above the tab bar
                Text("")
                    .tabItem {
                        Image(systemName: "plus.circle") // Just a placeholder, the actual button is created below
                    }
                    .tag(2)
            }

            // The "Create Contest" button
            Button(action: {
                isPresentingNewCompetition = true  // <- This line changes the state, triggering the modal presentation
            }) {
                Image(systemName: "plus.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60) // adjust the size as required
                    .foregroundColor(Color.blue) // your desired color
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(radius: 5)
            }
            .offset(y: -40) // This lifts the button up above the tab bar
            .padding(.bottom, -40) // Adjust this value as necessary to fine-tune the button's position
            .fullScreenCover(isPresented: $isPresentingNewCompetition) {
                NewCompetition() // This is the view that will be presented full screen
            }
        }
    }
}
