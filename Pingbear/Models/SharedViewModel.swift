import SwiftUI

class SharedViewModel: ObservableObject {
    @Published var shouldNavigateToCompetitionsView: Bool = false
}
