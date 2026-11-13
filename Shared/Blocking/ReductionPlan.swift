import FamilyControls
import Foundation

/// The user's plan to take back time from the few apps that take the most,
/// one week-long limit at a time. It holds the apps the user picked, as opaque
/// tokens, and their courses; like the rest of `BlockingConfiguration`, never usage.
struct ReductionPlan: Encodable, Equatable {
    var apps: [PlannedApp] = []
    /// How each day's limit is shared between morning, afternoon, and evening.
    var spread = DaySpread.evening
    /// A different spread chosen once limits are running. It starts at
    /// midnight, so it can't be used to open up more time today.
    var pendingSpread: PendingSpread?

    struct PendingSpread: Codable, Equatable {
        var spread: DaySpread
        var effective: Date
    }

    /// How long an early unlock lasts. iOS doesn't schedule anything shorter.
    static let unlockMinutes = 15
    /// How long the user waits for the first early unlock of a day, and for
    /// each one after it. The wait is the point: most urges pass inside it.
    static let unlockWaitSeconds = 60
    static let repeatUnlockWaitSeconds = 180

    /// The top two or three apps are usually most of the time; more is too
    /// many changes at once.
    static let maximumApps = 3

    var courses: [ReductionCourse] { apps.map(\.course) }

    /// Apps whose limits iOS should be watching at `date`.
    func enforcedApps(at date: Date = Date()) -> [PlannedApp] {
        apps.filter { $0.isEnforced(at: date) }
    }

    func spread(at date: Date = Date()) -> DaySpread {
        if let pendingSpread, date >= pendingSpread.effective { return pendingSpread.spread }
        return spread
    }

    /// The most of today's limit `app` can have used by `date`; nil before its first limit.
    func cap(for app: PlannedApp, at date: Date = Date(), calendar: Calendar = .current) -> Int? {
        app.course.limit(at: date, calendar: calendar).map { spread(at: date).cap(limit: $0, at: date, calendar: calendar) }
    }

    /// When `app` gets more time today after `date`; nil when that's midnight.
    func moreTime(for app: PlannedApp, after date: Date = Date(), calendar: Calendar = .current) -> Date? {
        app.course.limit(at: date, calendar: calendar).flatMap {
            spread(at: date).moreTime(limit: $0, after: date, calendar: calendar)
        }
    }

    /// When a block on `app` that is on at `date` lifts.
    func blockEnd(for app: PlannedApp, at date: Date = Date(), calendar: Calendar = .current) -> Date {
        moreTime(for: app, after: date, calendar: calendar) ?? BlockingConfiguration.nextMidnight(after: date, calendar: calendar)
    }
}

extension ReductionPlan: Decodable {
    /// Plans saved before day parts have only `apps`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apps = try container.decodeIfPresent([PlannedApp].self, forKey: .apps) ?? []
        spread = try container.decodeIfPresent(DaySpread.self, forKey: .spread) ?? .evening
        pendingSpread = try container.decodeIfPresent(PendingSpread.self, forKey: .pendingSpread)
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
    /// When a removal takes effect: the next midnight, so leaving the plan
    /// is never a way around a block that's on now.
    var removesAt: Date?
    /// The end of an early unlock, while one runs. Set by the app when the
    /// user asks for it; the limit is off until then.
    var unlockedUntil: Date?

    func isUnlocked(at date: Date = Date()) -> Bool {
        unlockedUntil.map { date < $0 } ?? false
    }

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
