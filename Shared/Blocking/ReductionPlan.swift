import FamilyControls
import Foundation

/// The user's plan to take back time from the few apps that take the most,
/// one week-long limit at a time. It holds the apps the user picked, as opaque
/// tokens, and their courses; like the rest of `BlockingConfiguration`, never usage.
struct ReductionPlan: Codable, Equatable {
    var apps: [PlannedApp] = []

    /// The top two or three apps are usually most of the time; more is too
    /// many changes at once.
    static let maximumApps = 3

    var courses: [ReductionCourse] { apps.map(\.course) }

    /// Apps whose limits iOS should be watching at `date`.
    func enforcedApps(at date: Date = Date()) -> [PlannedApp] {
        apps.filter { $0.isEnforced(at: date) }
    }
}

/// One app in the plan, with its own daily limit.
struct PlannedApp: Codable, Identifiable, Equatable {
    var id = UUID()
    /// Usually one app the user picked while the report showed their top apps.
    var selection: FamilyActivitySelection
    var course: ReductionCourse
    /// What the user calls the app. iOS shows extensions only the app's
    /// token, so notifications can name it only if the user typed this.
    var name: String?
    /// When strict mode lets a removal take effect: the next midnight.
    var removesAt: Date?

    /// `name`, trimmed; nil when blank.
    var displayName: String? { PlannedApp.cleaned(name) }

    static func cleaned(_ name: String?) -> String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maximumNameLength))
    }

    static let maximumNameLength = 30

    func isEnforced(at date: Date) -> Bool {
        removesAt.map { date < $0 } ?? true
    }
}
