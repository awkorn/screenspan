import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// Focus blocks, schedules, and daily limits. The app applies shields right
/// away; DeviceActivity monitoring lets the monitor extension turn them on
/// and off later while ScreenSpan isn't running.
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

    /// Strict mode forbids anything that would end a running block.
    func canTurnOff(_ schedule: BlockSchedule, at date: Date = Date()) -> Bool {
        !(configuration.strictMode && schedule.isEnabled && schedule.isActive(at: date))
    }

    var canEndSession: Bool { !configuration.strictMode }

    var canDisableStrictMode: Bool { !isBlocking() }

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

    func save(_ limit: AppLimit) {
        guard !limit.selection.isEmpty, limit.dailyMinutes > 0 else { return }
        if let index = configuration.limits.firstIndex(where: { $0.id == limit.id }) {
            configuration.limits[index] = limit
        } else {
            guard configuration.limits.count < BlockingConfiguration.maximumLimits else { return }
            configuration.limits.append(limit)
        }
        save()
        restart(limit)
    }

    func setEnabled(_ enabled: Bool, limit: AppLimit) {
        var updated = limit
        updated.isEnabled = enabled
        save(updated)
    }

    func delete(_ limit: AppLimit) {
        configuration.limits.removeAll { $0.id == limit.id }
        save()
        stop(.limit(limit.id))
    }

    private func restart(_ limit: AppLimit) {
        let rule = BlockingRule.limit(limit.id)
        stop(rule)
        guard isEntitled, limit.isEnabled else { return }
        let day = DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0),
                                         intervalEnd: DateComponents(hour: 23, minute: 59),
                                         repeats: true)
        let threshold = DateComponents(minute: limit.dailyMinutes)
        let event: DeviceActivityEvent
        if #available(iOS 17.4, *) {
            // Count time already used today, so a new limit applies right away.
            event = DeviceActivityEvent(applications: limit.selection.applicationTokens,
                                        categories: limit.selection.categoryTokens,
                                        webDomains: limit.selection.webDomainTokens,
                                        threshold: threshold, includesPastActivity: true)
        } else {
            event = DeviceActivityEvent(applications: limit.selection.applicationTokens,
                                        categories: limit.selection.categoryTokens,
                                        webDomains: limit.selection.webDomainTokens,
                                        threshold: threshold)
        }
        do {
            try center.startMonitoring(rule.activityName, during: day, events: [BlockingRule.limitEvent: event])
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    // MARK: - Strict mode

    func setStrictMode(_ enabled: Bool) {
        guard enabled || canDisableStrictMode else { return }
        configuration.strictMode = enabled
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
        // Monitoring left behind by deleted rules.
        let known = Set(BlockingRule.all(in: configuration).map(\.rawValue))
        for name in monitored.subtracting(known) {
            if let rule = BlockingRule(rawValue: name) { stop(rule) }
        }
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
