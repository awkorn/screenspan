import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// One thing that can block apps. Each rule has its own DeviceActivity name
/// and its own ManagedSettings store, so clearing one never lifts another;
/// iOS shields an app if any store blocks it.
enum BlockingRule: Hashable {
    case session
    case schedule(UUID)
    case limit(UUID)
    /// One app in the reduction plan, keyed by `PlannedApp.id`.
    case plan(UUID)
    /// The start of a later part of the day, when planned apps get more of
    /// their limit. It marks a time; it has no shields of its own.
    case planPart(DayPart)
    /// The end of an early unlock. Also only a time.
    case planUnlock

    static let limitEvent = DeviceActivityEvent.Name("dailyLimit")

    /// A planned app's threshold. The name carries its minutes, so the monitor
    /// knows which limit fired when today's and tomorrow's are both watched.
    static func planEvent(minutes: Int) -> DeviceActivityEvent.Name {
        DeviceActivityEvent.Name("planLimit.\(minutes)")
    }

    static func planEventMinutes(_ event: DeviceActivityEvent.Name) -> Int? {
        minutes(in: event, prefix: "planLimit")
    }

    /// How long before a part of the day's time runs out the user hears about it.
    static let planWarningLead = 5

    /// Minutes of warning before `cap` is reached; none when that leaves
    /// under five minutes of use before the warning.
    static func planWarningLead(cap minutes: Int) -> Int? {
        minutes - planWarningLead >= 5 ? planWarningLead : nil
    }

    /// A threshold `planWarningLead` minutes before `cap`, named for it.
    static func planWarningEvent(cap minutes: Int) -> DeviceActivityEvent.Name? {
        planWarningLead(cap: minutes) == nil ? nil : DeviceActivityEvent.Name("planWarning.\(minutes)")
    }

    static func planWarningCap(_ event: DeviceActivityEvent.Name) -> Int? {
        minutes(in: event, prefix: "planWarning")
    }

    private static func minutes(in event: DeviceActivityEvent.Name, prefix: Substring) -> Int? {
        let parts = event.rawValue.split(separator: ".", maxSplits: 1)
        guard parts.count == 2, parts[0] == prefix else { return nil }
        return Int(parts[1])
    }

    init?(activity: DeviceActivityName) {
        self.init(rawValue: activity.rawValue)
    }

    init?(rawValue: String) {
        if rawValue == "session" { self = .session; return }
        if rawValue == "planUnlock" { self = .planUnlock; return }
        let parts = rawValue.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        if parts[0] == "planPart" {
            guard let part = Int(parts[1]).flatMap(DayPart.init(rawValue:)) else { return nil }
            self = .planPart(part)
            return
        }
        guard let id = UUID(uuidString: parts[1]) else { return nil }
        switch parts[0] {
        case "schedule": self = .schedule(id)
        case "limit": self = .limit(id)
        case "plan": self = .plan(id)
        default: return nil
        }
    }

    var rawValue: String {
        switch self {
        case .session: "session"
        case .schedule(let id): "schedule.\(id.uuidString)"
        case .limit(let id): "limit.\(id.uuidString)"
        case .plan(let id): "plan.\(id.uuidString)"
        case .planPart(let part): "planPart.\(part.rawValue)"
        case .planUnlock: "planUnlock"
        }
    }

    var activityName: DeviceActivityName { DeviceActivityName(rawValue) }

    var store: ManagedSettingsStore { ManagedSettingsStore(named: ManagedSettingsStore.Name(rawValue)) }

    func shield(_ selection: FamilyActivitySelection) {
        let store = store
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    }

    func clear() {
        store.clearAllSettings()
    }

    /// Whether this rule's store is shielding anything now.
    var isShielding: Bool {
        let shield = store.shield
        return shield.applications != nil || shield.applicationCategories != nil || shield.webDomains != nil
    }

    /// Every rule the configuration can have shields in.
    static func all(in configuration: BlockingConfiguration) -> [BlockingRule] {
        [.session] + configuration.schedules.map { .schedule($0.id) } + configuration.limits.map { .limit($0.id) }
            + configuration.plan.apps.map { .plan($0.id) }
    }
}

/// What iOS watches for the plan, shared by the app and the monitor so
/// either can start it: each app's day with a threshold for every cap, and
/// the times of day when more of a limit opens up.
enum PlanMonitoring {
    static let wholeDay = DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0),
                                                 intervalEnd: DateComponents(hour: 23, minute: 59),
                                                 repeats: true)

    /// The parts of the day that start after midnight, each watched so the
    /// monitor can lift a block when more time opens up.
    static let laterParts: [DayPart] = [.afternoon, .evening]

    static func schedule(for part: DayPart) -> DeviceActivitySchedule {
        let next = DayPart(rawValue: part.rawValue + 1)
        return DeviceActivitySchedule(intervalStart: DateComponents(hour: part.startHour, minute: 0),
                                      intervalEnd: next.map { DateComponents(hour: $0.startHour, minute: 0) }
                                          ?? DateComponents(hour: 23, minute: 59),
                                      repeats: true)
    }

    /// How many limits ahead get thresholds. The app refreshes them whenever
    /// it opens; if it stays closed past these, the last watched limit still
    /// blocks, a little later than the newer one would.
    static let limitsAhead = 3

    /// Every running total the app's usage is checked against: each part's
    /// cap for the limit in force and the next few, under the spread in
    /// force and one due at midnight.
    static func caps(for app: PlannedApp, in plan: ReductionPlan, now: Date, calendar: Calendar = .current) -> Set<Int> {
        var limits = [app.course.limit(at: now, calendar: calendar)].compactMap { $0 }
        limits += app.course.plannedSteps(calendar: calendar).filter { $0.startedAt > now }.prefix(limitsAhead).map(\.dailyMinutes)
        let spreads = Set([plan.spread(at: now), plan.pendingSpread?.spread ?? plan.spread])
        return Set(limits.flatMap { limit in spreads.flatMap { $0.caps(limit: limit) } })
    }

    /// A threshold for each cap, and one shortly before it for the heads-up.
    static func events(for app: PlannedApp, in plan: ReductionPlan, now: Date) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for cap in caps(for: app, in: plan, now: now) {
            events[BlockingRule.planEvent(minutes: cap)] = event(for: app.selection, minutes: cap)
            if let warning = BlockingRule.planWarningEvent(cap: cap), let lead = BlockingRule.planWarningLead(cap: cap) {
                events[warning] = event(for: app.selection, minutes: cap - lead)
            }
        }
        return events
    }

    static func event(for selection: FamilyActivitySelection, minutes: Int) -> DeviceActivityEvent {
        let threshold = DateComponents(minute: minutes)
        if #available(iOS 17.4, *) {
            // Count time already used today, so a new limit applies right away
            // and restarting monitoring doesn't forget the day so far.
            return DeviceActivityEvent(applications: selection.applicationTokens,
                                       categories: selection.categoryTokens,
                                       webDomains: selection.webDomainTokens,
                                       threshold: threshold, includesPastActivity: true)
        }
        return DeviceActivityEvent(applications: selection.applicationTokens,
                                   categories: selection.categoryTokens,
                                   webDomains: selection.webDomainTokens,
                                   threshold: threshold)
    }

    /// Starts, or restarts, watching `app`'s day.
    static func start(_ app: PlannedApp, in plan: ReductionPlan, center: DeviceActivityCenter = DeviceActivityCenter(),
                      now: Date = Date()) throws {
        try center.startMonitoring(BlockingRule.plan(app.id).activityName, during: wholeDay,
                                   events: events(for: app, in: plan, now: now))
    }

    // When a plan block turned on. Block state, like the shield itself: the
    // app uses it to tell a block that should have lifted from one that's due.

    private static func shieldedKey(_ id: UUID) -> String { "planShieldedAt.\(id.uuidString)" }

    static func shieldedAt(_ id: UUID, defaults: UserDefaults = .appGroup) -> Date? {
        let seconds = defaults.double(forKey: shieldedKey(id))
        return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }

    static func setShieldedAt(_ date: Date?, for id: UUID, defaults: UserDefaults = .appGroup) {
        if let date { defaults.set(date.timeIntervalSince1970, forKey: shieldedKey(id)) }
        else { defaults.removeObject(forKey: shieldedKey(id)) }
    }

    /// Blocks `app` under its plan rule and notes when.
    static func shield(_ app: PlannedApp, at date: Date = Date()) {
        BlockingRule.plan(app.id).shield(app.selection)
        setShieldedAt(date, for: app.id)
    }

    static func lift(_ id: UUID) {
        BlockingRule.plan(id).clear()
        setShieldedAt(nil, for: id)
    }

    /// Whether a block that turned on at `shieldedAt` should be off by `now`:
    /// a new day has started, or a later part of the day has opened more time.
    static func blockHasLapsed(for app: PlannedApp, in plan: ReductionPlan, shieldedAt: Date, now: Date,
                               calendar: Calendar = .current) -> Bool {
        guard calendar.isDate(shieldedAt, inSameDayAs: now) else { return true }
        guard let before = plan.cap(for: app, at: shieldedAt, calendar: calendar),
              let current = plan.cap(for: app, at: now, calendar: calendar)
        else { return false }
        return current > before
    }
}
