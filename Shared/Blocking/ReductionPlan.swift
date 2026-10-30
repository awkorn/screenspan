import FamilyControls
import Foundation

/// The user's plan to take back time from the few apps that take the most,
/// one week-long step at a time. It holds the apps the user picked, as opaque
/// tokens, and their courses; like the rest of `BlockingConfiguration`, never usage.
struct ReductionPlan: Codable, Equatable {
    var apps: [PlannedApp] = []

    /// The top two or three apps are usually most of the time; more is too
    /// many changes at once.
    static let maximumApps = 3

    var courses: [ReductionCourse] { apps.map(\.course) }
    var isComplete: Bool { !apps.isEmpty && apps.allSatisfy(\.course.isAtTarget) }

    /// Apps whose limits iOS should be watching at `date`.
    func enforcedApps(at date: Date = Date()) -> [PlannedApp] {
        apps.filter { $0.isEnforced(at: date) }
    }

    /// Apps due a check-in at `date`.
    func appsReadyForNextStep(at date: Date = Date(), calendar: Calendar = .current) -> [PlannedApp] {
        apps.filter { $0.isEnforced(at: date) && $0.course.isReadyForNextStep(at: date, calendar: calendar) }
    }
}

/// One app in the plan, with its own daily limit.
struct PlannedApp: Codable, Identifiable, Equatable {
    var id = UUID()
    /// Usually one app the user picked while the report showed their top apps.
    var selection: FamilyActivitySelection
    var course: ReductionCourse
    /// When strict mode lets a removal take effect: the next midnight.
    var removesAt: Date?

    func isEnforced(at date: Date) -> Bool {
        removesAt.map { date < $0 } ?? true
    }
}
