import SwiftUI

// Theme or constants files
struct AppColors {
    static let background = Color(hex: "#FFF")
    static let primary = Color(hex: "#1199FF")
    static let white = Color(hex: "#fff")
    static let orange = Color(hex: "#FF7F50")
}

func openURL(_ urlString: String) {
    if let url = URL(string: urlString) {
        UIApplication.shared.open(url)
    }
}
