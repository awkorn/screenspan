import Foundation

/// Convenience extension for accessing the shared app group UserDefaults
extension UserDefaults {
    /// Shared UserDefaults backed by the app group container
    static let appGroup = UserDefaults(suiteName: SharedConstants.appGroupIdentifier)!
}
