import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

/// Focus blocks, schedules, daily limits, and the reduction plan. The app
/// applies shields right away; DeviceActivity monitoring lets the monitor
/// extension turn them on and off later while ScreenSpan isn't running.
@MainActor
final class BlockingService: ObservableObject {
    @Published private(set) var configuration: BlockingConfiguration
    @Published var errorMessage: String?

    static let sessionMinutes = [15, 30, 60, 120, 240]
    /// iOS shields at most 50 individual apps per store; categories have no cap.
    static let maximumShieldedApps = 50

    private let center = DeviceActivityCenter()
    /// The last recorded entitlement until StoreKit answers this launch.
    private var isEntitled = BlockingEntitlement.isActive

    init() {
        configuration = .load()
    }

    // MARK: - State

    func isBlocking(at date: Date = Date()) -> Bool {
        configuration.activeSession(at: date) != nil
            || (!configuration.blockList.isEmpty && !configuration.activeSchedules(at: date).isEmpty)
    }

    /// What is blocking now and until when: the focus block first, otherwise
    /// the running schedule that ends last.
    func currentBlock(at date: Date = Date()) -> (end: Date, isFocus: Bool)? {
        if let session = configuration.activeSession(at: date) { return (session.end, true) }
        guard !configuration.blockList.isEmpty,
              let end = configuration.activeSchedules(at: date).compactMap({ $0.end(after: date) }).max()
        else { return nil }
        return (end, false)
    }

    /// Strict mode forbids anything that would end a running block.
    func canTurnOff(_ schedule: BlockSchedule, at date: Date = Date()) -> Bool {
        !(configuration.isStrict(at: date) && schedule.isEnabled && schedule.isActive(at: date))
    }

    var canEndSession: Bool { !configuration.isStrict() }

    var canDisableStrictMode: Bool { !isBlocking() }

    /// Daily limits or plan limits, which make turning strict mode off wait for midnight.
    var hasDailyLimits: Bool {
        configuration.limits.contains(where: \.isEnabled) || !configuration.plan.apps.isEmpty
    }

    /// When strict mode switches itself off, if the user asked while limits ran.
    var strictModeEndsAt: Date? {
        configuration.isStrict() ? configuration.strictModeEndsAt : nil
    }

    // MARK: - Block list

    func updateBlockList(_ selection: FamilyActivitySelection) {
        guard selection != configuration.blockList else { return }
        configuration.blockList = selection
        save()
        // Running blocks pick up the new list immediately.
        if configuration.activeSession() != nil { BlockingRule.session.shield(selection) }
        for schedule in configuration.activeSchedules() { BlockingRule.schedule(schedule.id).shield(selection) }
    }

    // MARK: - Focus blocks

    func startSession(minutes: Int) {
        guard isEntitled, !configuration.blockList.isEmpty else { return }
        let start = Date()
        let end = start.addingTimeInterval(TimeInterval(minutes * 60))
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(components, from: start),
            intervalEnd: Calendar.current.dateComponents(components, from: end),
            repeats: false)
        do {
            try center.startMonitoring(BlockingRule.session.activityName, during: schedule)
        } catch {
            errorMessage = Self.message(for: error)
            return
        }
        configuration.session = FocusSession(start: start, end: end)
        save()
        BlockingRule.session.shield(configuration.blockList)
    }

    func endSession() {
        guard canEndSession else { return }
        clearSession()
    }

    private func clearSession() {
        center.stopMonitoring([BlockingRule.session.activityName])
        BlockingRule.session.clear()
        configuration.session = nil
        save()
    }

    // MARK: - Schedules

    func save(_ schedule: BlockSchedule) {
        guard schedule.isValid else { return }
        if let index = configuration.schedules.firstIndex(where: { $0.id == schedule.id }) {
            configuration.schedules[index] = schedule
        } else {
            guard configuration.schedules.count < BlockingConfiguration.maximumSchedules else { return }
            configuration.schedules.append(schedule)
        }
        save()
        restart(schedule)
    }

    func setEnabled(_ enabled: Bool, schedule: BlockSchedule) {
        guard enabled || canTurnOff(schedule) else { return }
        var updated = schedule
        updated.isEnabled = enabled
        save(updated)
    }

    func delete(_ schedule: BlockSchedule) {
        guard canTurnOff(schedule) else { return }
        configuration.schedules.removeAll { $0.id == schedule.id }
        save()
        stop(.schedule(schedule.id))
    }

    private func restart(_ schedule: BlockSchedule) {
        let rule = BlockingRule.schedule(schedule.id)
        stop(rule)
        guard isEntitled, schedule.isEnabled else { return }
        let interval = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: schedule.startMinute / 60, minute: schedule.startMinute % 60),
            intervalEnd: DateComponents(hour: schedule.endMinute / 60, minute: schedule.endMinute % 60),
            repeats: true)
        do {
            try center.startMonitoring(rule.activityName, during: interval)
        } catch {
            errorMessage = Self.message(for: error)
            return
        }
        // Monitoring doesn't reliably start a window that's already open.
        if schedule.isActive(at: Date()) { rule.shield(configuration.blockList) }
    }

    // MARK: - Daily limits

    /// Saves a new or changed limit. Under strict mode, a change that allows
    /// more (more time, fewer apps, switched off) waits until midnight, when
    /// today's allowance would reset anyway; tightening applies right away.
    func save(_ limit: AppLimit) {
        guard !limit.selection.isEmpty, limit.dailyMinutes > 0 else { return }
        var updated = limit
        updated.pending = nil
        if let index = configuration.limits.firstIndex(where: { $0.id == limit.id }) {
            let current = configuration.limits[index]
            if configuration.isStrict(), current.isLoosened(by: limit) {
                configuration.limits[index].pending = AppLimit.PendingChange(
                    selection: limit.selection, dailyMinutes: limit.dailyMinutes, isEnabled: limit.isEnabled,
                    effective: BlockingConfiguration.nextMidnight())
                save()
                return
            }
            configuration.limits[index] = updated
        } else {
            guard configuration.limits.count < BlockingConfiguration.maximumLimits else { return }
            configuration.limits.append(updated)
        }
        save()
        restart(updated)
    }

    func setEnabled(_ enabled: Bool, limit: AppLimit) {
        var updated = limit
        updated.isEnabled = enabled
        save(updated)
    }

    func delete(_ limit: AppLimit) {
        guard let index = configuration.limits.firstIndex(where: { $0.id == limit.id }) else { return }
        if configuration.isStrict(), configuration.limits[index].isEnabled {
            let current = configuration.limits[index]
            configuration.limits[index].pending = AppLimit.PendingChange(
                selection: current.selection, dailyMinutes: current.dailyMinutes, isEnabled: false, removes: true,
                effective: BlockingConfiguration.nextMidnight())
            save()
            return
        }
        configuration.limits.remove(at: index)
        save()
        stop(.limit(limit.id))
    }

    /// Drops a change waiting for midnight. Keeping the stricter limit is
    /// always allowed.
    func cancelPendingChange(_ limit: AppLimit) {
        guard let index = configuration.limits.firstIndex(where: { $0.id == limit.id }) else { return }
        configuration.limits[index].pending = nil
        save()
    }

    private func restart(_ limit: AppLimit) {
        let rule = BlockingRule.limit(limit.id)
        stop(rule)
        guard isEntitled, limit.isEnabled else { return }
        let event = Self.event(for: limit.selection, minutes: limit.dailyMinutes)
        do {
            try center.startMonitoring(rule.activityName, during: Self.wholeDay, events: [BlockingRule.limitEvent: event])
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    // MARK: - Reduction plan

    var canAddToPlan: Bool { configuration.plan.apps.count < ReductionPlan.maximumApps }

    /// Adds an app to the plan. Its first limit starts at the next midnight,
    /// a fresh day, rather than blocking time the user has already spent today.
    func addToPlan(_ selection: FamilyActivitySelection, baselineMinutes: Int, targetMinutes: Int? = nil) {
        guard !selection.isEmpty, canAddToPlan else { return }
        let course = ReductionCourse(baselineMinutes: baselineMinutes, targetMinutes: targetMinutes,
                                     start: BlockingConfiguration.nextMidnight())
        let app = PlannedApp(selection: selection, course: course)
        configuration.plan.apps.append(app)
        save()
        restart(app)
        if warnsBeforePlanLimits { Task { await requestNotificationPermission() } }
    }

    /// The heads-up before a plan limit runs out. Only the monitor posts it.
    var warnsBeforePlanLimits: Bool {
        get { UserDefaults.appGroup.object(forKey: SharedConstants.UserDefaultsKey.planLimitWarnings.rawValue) as? Bool ?? true }
        set {
            objectWillChange.send()
            UserDefaults.appGroup.set(newValue, forKey: SharedConstants.UserDefaultsKey.planLimitWarnings.rawValue)
            if newValue { Task { await requestNotificationPermission() } }
        }
    }

    /// Asks once; later calls return what the user chose.
    @discardableResult
    func requestNotificationPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Changes where an app starts or ends up before its first limit starts.
    /// Nothing is in force yet, so this loosens nothing.
    func revise(_ app: PlannedApp, baselineMinutes: Int, targetMinutes: Int) {
        guard let current = plannedApp(app.id), !current.course.hasStarted(at: Date()) else { return }
        update(app.id) {
            $0.course = ReductionCourse(baselineMinutes: baselineMinutes, targetMinutes: targetMinutes,
                                        start: current.course.steps[0].startedAt)
        }
    }

    /// Moves the goal down. Today's limit stays; the plan never loosens.
    func lowerGoal(_ app: PlannedApp, minutes: Int) {
        update(app.id) { $0.course.lowerGoal(to: minutes, at: Date()) }
    }

    /// Takes an app out of the plan, at midnight under strict mode.
    func removeFromPlan(_ app: PlannedApp) {
        guard plannedApp(app.id) != nil else { return }
        if configuration.isStrict() {
            update(app.id, restartsMonitoring: false) { $0.removesAt = BlockingConfiguration.nextMidnight() }
            return
        }
        configuration.plan.apps.removeAll { $0.id == app.id }
        save()
        stop(.plan(app.id))
    }

    /// Keeps an app in the plan after asking to remove it under strict mode.
    func cancelRemoval(_ app: PlannedApp) {
        update(app.id, restartsMonitoring: false) { $0.removesAt = nil }
    }

    private func plannedApp(_ id: UUID) -> PlannedApp? {
        configuration.plan.apps.first { $0.id == id }
    }

    private func update(_ id: UUID, restartsMonitoring: Bool = true, _ change: (inout PlannedApp) -> Void) {
        guard let index = configuration.plan.apps.firstIndex(where: { $0.id == id }) else { return }
        change(&configuration.plan.apps[index])
        save()
        if restartsMonitoring { restart(configuration.plan.apps[index]) }
    }

    /// Watches a threshold for every limit in force today or still ahead, so
    /// each week's limit applies at midnight without the app. Today's limit never
    /// changes mid-day, so an existing shield is left in place.
    private func restart(_ app: PlannedApp, now: Date = Date()) {
        let rule = BlockingRule.plan(app.id)
        center.stopMonitoring([rule.activityName])
        guard isEntitled, app.isEnforced(at: now) else { return rule.clear() }
        do {
            try center.startMonitoring(rule.activityName, during: Self.wholeDay, events: Self.planEvents(for: app, now: now))
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Each limit's threshold, and one a few minutes before it for the warning.
    private static func planEvents(for app: PlannedApp, now: Date) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for minutes in app.course.limitsInForce(from: now) {
            events[BlockingRule.planEvent(minutes: minutes)] = event(for: app.selection, minutes: minutes)
            if let warning = BlockingRule.planWarningEvent(limit: minutes) {
                events[warning] = event(for: app.selection, minutes: minutes - BlockingRule.planWarningLead)
            }
        }
        return events
    }

    private static let wholeDay = DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0),
                                                         intervalEnd: DateComponents(hour: 23, minute: 59),
                                                         repeats: true)

    private static func event(for selection: FamilyActivitySelection, minutes: Int) -> DeviceActivityEvent {
        let threshold = DateComponents(minute: minutes)
        if #available(iOS 17.4, *) {
            // Count time already used today, so a new limit applies right away.
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

    // MARK: - Strict mode

    /// Turning strict mode on is immediate. Turning it off waits for nothing
    /// to be blocking, and, while daily limits or the plan run, until
    /// midnight; otherwise switching it off would undo a used-up limit early.
    func setStrictMode(_ enabled: Bool) {
        if enabled {
            configuration.strictMode = true
            configuration.strictModeEndsAt = nil
        } else {
            guard canDisableStrictMode, configuration.isStrict() else { return }
            if hasDailyLimits {
                configuration.strictModeEndsAt = BlockingConfiguration.nextMidnight()
            } else {
                configuration.strictMode = false
                configuration.strictModeEndsAt = nil
            }
        }
        save()
    }

    // MARK: - Lifecycle

    /// Called with each verified entitlement. Blocking is a Pro feature, so
    /// losing Pro lifts every block; the user's setup is kept for later.
    func setEntitled(_ entitled: Bool) {
        isEntitled = entitled
        if entitled { reconcile() } else { deactivateAll() }
    }

    /// Brings shields and monitoring in line with the saved configuration,
    /// on launch and whenever the app returns to the foreground.
    func reconcile(now: Date = Date()) {
        guard isEntitled else { return }
        configuration = .load()
        applyDueChanges(now: now)
        if let session = configuration.session {
            if session.isActive(at: now) {
                BlockingRule.session.shield(configuration.blockList)
            } else {
                clearSession()
            }
        }
        let monitored = Set(center.activities.map(\.rawValue))
        for schedule in configuration.schedules {
            let rule = BlockingRule.schedule(schedule.id)
            if !schedule.isEnabled {
                if monitored.contains(rule.rawValue) { stop(rule) }
            } else if !monitored.contains(rule.rawValue) {
                restart(schedule)
            } else if schedule.isActive(at: now) {
                rule.shield(configuration.blockList)
            } else {
                rule.clear()
            }
        }
        for limit in configuration.limits {
            let rule = BlockingRule.limit(limit.id)
            if limit.isEnabled != monitored.contains(rule.rawValue) { restart(limit) }
        }
        for app in configuration.plan.apps {
            let rule = BlockingRule.plan(app.id)
            // Restart only when a limit isn't watched: a restart before iOS
            // 17.4 forgets time already used today. Thresholds left from past
            // weeks are harmless, since each checks the day's limit.
            let expected = Set(Self.planEvents(for: app, now: now).keys)
            if !monitored.contains(rule.rawValue) || !expected.isSubset(of: Set(center.events(for: rule.activityName).keys)) {
                restart(app, now: now)
            }
        }
        // Monitoring left behind by deleted rules.
        let known = Set(BlockingRule.all(in: configuration).map(\.rawValue))
        for name in monitored.subtracting(known) {
            if let rule = BlockingRule(rawValue: name) { stop(rule) }
        }
    }

    /// Applies what strict mode held back once its midnight has passed.
    private func applyDueChanges(now: Date) {
        var changed = false
        if configuration.strictMode, let end = configuration.strictModeEndsAt, now >= end {
            configuration.strictMode = false
            configuration.strictModeEndsAt = nil
            changed = true
        }
        for limit in configuration.limits {
            guard let pending = limit.pending, now >= pending.effective else { continue }
            changed = true
            if let applied = limit.applying(at: now),
               let index = configuration.limits.firstIndex(where: { $0.id == limit.id }) {
                configuration.limits[index] = applied
                restart(applied)
            } else {
                configuration.limits.removeAll { $0.id == limit.id }
                stop(.limit(limit.id))
            }
        }
        for app in configuration.plan.apps where !app.isEnforced(at: now) {
            changed = true
            configuration.plan.apps.removeAll { $0.id == app.id }
            stop(.plan(app.id))
        }
        if changed { save() }
    }

    private func deactivateAll() {
        center.stopMonitoring()
        BlockingRule.all(in: configuration).forEach { $0.clear() }
        if configuration.session != nil {
            configuration.session = nil
            save()
        }
    }

    // MARK: - Helpers

    private func stop(_ rule: BlockingRule) {
        center.stopMonitoring([rule.activityName])
        rule.clear()
    }

    private func save() {
        configuration.save()
    }

    private static func message(for error: Error) -> String {
        guard let error = error as? DeviceActivityCenter.MonitoringError else {
            return "iOS couldn't start this block. Check that Screen Time access is allowed, then try again."
        }
        switch error {
        case .excessiveActivities:
            return "iOS limits how many blocks can run at once. Remove a schedule or limit, then try again."
        case .intervalTooLong:
            return "This block is longer than iOS allows. Try a shorter one."
        case .intervalTooShort:
            return "Blocks need to last at least 15 minutes."
        case .invalidDateComponents:
            return "Those times didn't work. Pick different start and end times."
        case .unauthorized:
            return "Allow Screen Time access to block apps."
        @unknown default:
            return "iOS couldn't start this block. Please try again."
        }
    }
}
