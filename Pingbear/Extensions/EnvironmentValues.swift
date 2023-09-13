import SwiftUI
import Combine

extension EnvironmentValues {
    var didLogOut: PassthroughSubject<Void, Never> {
        get { self[DidLogOutKey.self] }
        set { self[DidLogOutKey.self] = newValue }
    }
}

private struct DidLogOutKey: EnvironmentKey {
    static var defaultValue: PassthroughSubject<Void, Never> {
        PassthroughSubject<Void, Never>()
    }
}
