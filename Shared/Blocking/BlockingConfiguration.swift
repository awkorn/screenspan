import FamilyControls
import Foundation

/// Everything the user set up for blocking. Stored in the App Group so the
/// monitor and shield extensions can act on it. It holds only the user's
/// choices and opaque Screen Time tokens, never usage.
struct BlockingConfiguration: Codable, Equatable {
    /// Apps, categories, and sites blocked by focus blocks and schedules.
    var blockList = FamilyActivitySelection()
    var session: FocusSession?
    var schedules: [BlockSchedule] = []
    var limits: [AppLimit] = []
    /// Focus blocks can't end early, running schedules can't be turned off,
    /// and loosening a daily limit waits until the next midnight.
    var strictMode = false
    /// When strict mode turns itself off. Set when the user turns it off while
    /// daily limits run, so that can't be used to undo a limit early.
    var strictModeEndsAt: Date?

    /// DeviceActivity monitors at most 20 activities per app; one is the focus block.
    static let maximumSchedules = 8
    static let maximumLimits = 8

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blockList = try container.decodeIfPresent(FamilyActivitySelection.self, forKey: .blockList) ?? FamilyActivitySelection()
        session = try container.decodeIfPresent(FocusSession.self, forKey: .session)
        schedules = try container.decodeIfPresent([BlockSchedule].self, forKey: .schedules) ?? []
        limits = try container.decodeIfPresent([AppLimit].self, forKey: .limits) ?? []
        strictMode = try container.decodeIfPresent(Bool.self, forKey: .strictMode) ?? false
        strictModeEndsAt = try container.decodeIfPresent(Date.self, forKey: .strictModeEndsAt)
    }

    /// Strict mode as it applies at `date`, counting a scheduled switch-off.
    func isStrict(at date: Date = Date()) -> Bool {
        strictMode && (strictModeEndsAt.map { date < $0 } ?? true)
    }

    /// When changes held back by strict mode apply.
    static func nextMidnight(after date: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date.addingTimeInterval(24 * 60 * 60)
    }

    static func load(from defaults: UserDefaults = .appGroup) -> BlockingConfiguration {
        guard let data = defaults.data(forKey: SharedConstants.UserDefaultsKey.blockingConfiguration.rawValue),
              let configuration = try? JSONDecoder().decode(BlockingConfiguration.self, from: data)
        else { return BlockingConfiguration() }
        return configuration
    }

    func save(to defaults: UserDefaults = .appGroup) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: SharedConstants.UserDefaultsKey.blockingConfiguration.rawValue)
    }

    func activeSession(at date: Date = Date()) -> FocusSession? {
        guard let session, session.isActive(at: date) else { return nil }
        return session
    }

    func activeSchedules(at date: Date = Date()) -> [BlockSchedule] {
        schedules.filter { $0.isEnabled && $0.isActive(at: date) }
    }
}

/// A one-off block of the distraction list, started from the app.
struct FocusSession: Codable, Equatable {
    var start: Date
    var end: Date

    func isActive(at date: Date = Date()) -> Bool { date >= start && date < end }
}

/// A daily allowance: once the selected apps reach it together, they are
/// blocked until midnight.
struct AppLimit: Codable, Identifiable, Equatable {
    var id = UUID()
    var selection = FamilyActivitySelection()
    var dailyMinutes = 30
    var isEnabled = true
    /// A loosening change made under strict mode, held until `effective`.
    var pending: PendingChange?

    struct PendingChange: Codable, Equatable {
        var selection: FamilyActivitySelection
        var dailyMinutes: Int
        var isEnabled: Bool
        var removes = false
        var effective: Date
    }

    /// The limit as it applies at `date`, or nil once a scheduled removal is due.
    func applying(at date: Date = Date()) -> AppLimit? {
        guard let pending, date >= pending.effective else { return self }
        guard !pending.removes else { return nil }
        var applied = self
        applied.selection = pending.selection
        applied.dailyMinutes = pending.dailyMinutes
        applied.isEnabled = pending.isEnabled
        applied.pending = nil
        return applied
    }

    /// Whether `proposed` allows more than this limit: more time, fewer
    /// apps, or switched off. A limit that's already off can't be loosened.
    func isLoosened(by proposed: AppLimit) -> Bool {
        guard isEnabled else { return false }
        return !proposed.isEnabled || proposed.dailyMinutes > dailyMinutes || !proposed.selection.contains(selection)
    }
}

extension FamilyActivitySelection {
    var isEmpty: Bool {
        applicationTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty
    }

    /// Whether this selection includes everything in `other`.
    func contains(_ other: FamilyActivitySelection) -> Bool {
        applicationTokens.isSuperset(of: other.applicationTokens)
            && categoryTokens.isSuperset(of: other.categoryTokens)
            && webDomainTokens.isSuperset(of: other.webDomainTokens)
    }

    /// "3 apps, 1 category" — for rows and accessibility labels.
    var summary: String {
        let parts = [
            Self.count(applicationTokens.count, "app", "apps"),
            Self.count(categoryTokens.count, "category", "categories"),
            Self.count(webDomainTokens.count, "website", "websites"),
        ].compactMap { $0 }
        return parts.isEmpty ? "Nothing selected" : parts.joined(separator: ", ")
    }

    private static func count(_ n: Int, _ one: String, _ many: String) -> String? {
        n == 0 ? nil : "\(n) \(n == 1 ? one : many)"
    }
}

/// Blocking is part of ScreenSpan Pro. The app records the verified
/// entitlement in the App Group so extensions don't apply shields after it ends.
enum BlockingEntitlement {
    static var isActive: Bool {
        let status = UserDefaults.appGroup.string(forKey: SharedConstants.UserDefaultsKey.subscriptionStatus.rawValue)
        return status == "premium" || status == "trial"
    }
}
