import Foundation

enum UsageCategory: String, Codable, Sendable, CaseIterable, Hashable {
    case social
    case entertainment
    case games
    case productivity
    case education
    case other

    var displayName: String {
        switch self {
        case .social:
            return "Social Media"
        case .entertainment:
            return "Entertainment"
        case .games:
            return "Games"
        case .productivity:
            return "Productivity"
        case .education:
            return "Education"
        case .other:
            return "Other"
        }
    }

    var sfSymbolIcon: String {
        switch self {
        case .social:
            return "person.2.fill"
        case .entertainment:
            return "tv.fill"
        case .games:
            return "gamecontroller.fill"
        case .productivity:
            return "briefcase.fill"
        case .education:
            return "book.fill"
        case .other:
            return "ellipsis.circle.fill"
        }
    }
}
