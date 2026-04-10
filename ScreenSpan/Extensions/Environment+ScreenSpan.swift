import SwiftUI

/// Environment key for app group identifier
struct AppGroupIdentifierKey: EnvironmentKey {
    static let defaultValue: String = SharedConstants.appGroupIdentifier
}

extension EnvironmentValues {
    var appGroupIdentifier: String {
        get { self[AppGroupIdentifierKey.self] }
        set { self[AppGroupIdentifierKey.self] = newValue }
    }
}
