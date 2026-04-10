import Foundation

enum SubscriptionStatus: String, Codable, Sendable, CaseIterable, Hashable {
    case free
    case trial
    case premium

    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .trial:
            return "Trial"
        case .premium:
            return "Premium"
        }
    }

    var isPremium: Bool {
        switch self {
        case .free:
            return false
        case .trial, .premium:
            return true
        }
    }
}
