import SwiftUI
import StoreKit

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

func isValidUsername(_ username: String) -> (isValid: Bool, error: String?) {
    // Trim the username to remove leading and trailing whitespace
    let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

    // Check if the username is empty after trimming
    if trimmedUsername.isEmpty {
        return (false, "Please enter a username")
    }

    let allowedCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
    let endingCharacterSet = CharacterSet.alphanumerics

    // Check length constraints
    if trimmedUsername.count < 3 || trimmedUsername.count > 15 {
        return (false, "Username must be between 3 and 15 characters")
    }
    
    // Check for allowed characters
    if trimmedUsername.rangeOfCharacter(from: allowedCharacterSet.inverted) != nil {
        return (false, "Username can only contain letters, numbers, '-', '_', or '.'")
    }
    
    // Ensure username ends in a letter or number
    if let last = trimmedUsername.last, !endingCharacterSet.contains(last.unicodeScalars.first!) {
        return (false, "Username must end with a letter or number")
    }
    
    return (true, nil)
}

func formattedPrice(for product: SKProduct) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = product.priceLocale
    return formatter.string(from: product.price) ?? "\(product.price)"
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
