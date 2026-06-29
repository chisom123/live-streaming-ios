import SwiftUI
import StoreKit

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

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct CustomSpinner: View {
    var lineWidth: CGFloat = 8  // default matches existing usage
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(Color.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}
