import UIKit

enum SnapError: Error {
    case snapchatNotInstalled
}

class SnapchatShare {
    static func openSnapchat() throws {
        guard let snapchatURL = URL(string: "snapchat://"), UIApplication.shared.canOpenURL(snapchatURL) else {
            throw SnapError.snapchatNotInstalled
        }
        
        UIApplication.shared.open(snapchatURL)
    }
}
