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
            try center.startMonitoring(rule.activityName, during: PlanMonitoring.wholeDay, events: [BlockingRule.limitEvent: event])
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    // MARK: - Reduction plan

    var canAddToPlan: Bool { configuration.plan.apps.count < ReductionPlan.maximumApps }

    /// Adds an app to the plan. Its first limit starts at the next midnight,
    /// a fresh day, rather than blocking time the user has already spent today.
    /// `course` is expected to start then.
    func addToPlan(_ selection: FamilyActivitySelection, course: ReductionCourse, name: String? = nil) {
        guard !selection.isEmpty, canAddToPlan else { return }
        let app = PlannedApp(selection: selection, course: course, name: PlannedApp.cleaned(name))
        configuration.plan.apps.append(app)
        save()
        restart(app)
        watchPlanParts()
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

    /// Replaces an app's limits. Before its first limit starts nothing is in
    /// force, so anything goes; after, the change is kept only if no day's
    /// limit goes up and today's stays, so the plan never loosens.
    func setCourse(_ app: PlannedApp, to course: ReductionCourse) {
        let now = Date()
        guard let current = plannedApp(app.id), course != current.course,
              course.steps[0].startedAt == current.course.steps[0].startedAt,
              course.baselineMinutes == current.course.baselineMinutes,
              !current.course.hasStarted(at: now) || course.isNoLooser(than: current.course, from: now)
        else { return }
        update(app.id) { $0.course = course }
    }

    /// What notifications call the app.
    func rename(_ app: PlannedApp, to name: String?) {
        update(app.id, restartsMonitoring: false) { $0.name = PlannedApp.cleaned(name) }
    }

    /// Whether any planned app's limits are running.
    private func planHasStarted(at date: Date) -> Bool {
        configuration.plan.apps.contains { $0.course.hasStarted(at: date) }
    }

    /// How the day's time is shared out. Once limits are running the change
    /// waits for midnight, so it can't open up more time today.
    func setSpread(_ spread: DaySpread) {
        let now = Date()
        if planHasStarted(at: now) {
            configuration.plan.pendingSpread = spread == configuration.plan.spread
                ? nil : .init(spread: spread, effective: BlockingConfiguration.nextMidnight(after: now))
        } else {
            configuration.plan.spread = spread
            configuration.plan.pendingSpread = nil
        }
        save()
        configuration.plan.apps.forEach { restart($0, now: now) }
    }

    /// Takes an app out of the plan. Once its limits are running that waits
    /// for midnight: leaving the plan is not a way around a block.
    func removeFromPlan(_ app: PlannedApp) {
        guard let current = plannedApp(app.id) else { return }
        if current.course.hasStarted(at: Date()) {
            update(app.id, restartsMonitoring: false) { $0.removesAt = BlockingConfiguration.nextMidnight() }
            return
        }
        configuration.plan.apps.removeAll { $0.id == app.id }
        save()
        stop(.plan(app.id))
        PlanMonitoring.setShieldedAt(nil, for: app.id)
        watchPlanParts()
    }

    /// Keeps an app in the plan after asking to remove it.
    func cancelRemoval(_ app: PlannedApp) {
        update(app.id, restartsMonitoring: false) { $0.removesAt = nil }
    }

    // MARK: Early unlock

    /// Whether the app's plan block is on now.
    func isPlanBlocked(_ app: PlannedApp) -> Bool {
        BlockingRule.plan(app.id).isShielding
    }

    /// Why an early unlock isn't on offer, or nil when it is.
    func unlockUnavailableReason(_ app: PlannedApp, at date: Date = Date()) -> String? {
        if configuration.isStrict(at: date) { return "Strict mode is on, so this block can’t be unlocked early." }
        if configuration.plan.apps.contains(where: { $0.isUnlocked(at: date) }) { return "Another app is unlocked right now." }
        return nil
    }

    /// Seconds to wait before unlocking `app` early: longer once today has
    /// already been unlocked.
    func unlockWaitSeconds(_ app: PlannedApp, at date: Date = Date()) -> Int {
        (plannedApp(app.id)?.course.isMissed(date) ?? false)
            ? ReductionPlan.repeatUnlockWaitSeconds : ReductionPlan.unlockWaitSeconds
    }

    /// Lifts the app's block for `ReductionPlan.unlockMinutes` and marks the
    /// day missed. Returns whether that made the week's limit repeat.
    @discardableResult
    func unlockEarly(_ app: PlannedApp) -> Bool {
        let now = Date()
        guard isEntitled, let current = plannedApp(app.id), current.isEnforced(at: now),
              isPlanBlocked(current), unlockUnavailableReason(current, at: now) == nil
        else { return false }
        let end = now.addingTimeInterval(TimeInterval(ReductionPlan.unlockMinutes * 60))
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        do {
            try center.startMonitoring(BlockingRule.planUnlock.activityName, during: DeviceActivitySchedule(
                intervalStart: Calendar.current.dateComponents(components, from: now),
                intervalEnd: Calendar.current.dateComponents(components, from: end),
                repeats: false))
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
        var held = false
        update(app.id, restartsMonitoring: false) {
            held = $0.course.recordMiss(at: now)
            $0.unlockedUntil = end
        }
        PlanMonitoring.lift(app.id)
        // A week that repeats moves the limits ahead; watch the new dates.
        if held, let updated = plannedApp(app.id) { restart(updated, now: now) }
        return held
    }

    /// Ends an early unlock: blocks again in the same part of the day, and
    /// clears the marker either way. The monitor normally does the blocking;
    /// this covers the times iOS doesn't call it.
    private func finishUnlocks(now: Date) {
        for app in configuration.plan.apps {
            guard let until = app.unlockedUntil, until <= now else { continue }
            let started = until.addingTimeInterval(-TimeInterval(ReductionPlan.unlockMinutes * 60))
            if app.isEnforced(at: now), !isPlanBlocked(app), Calendar.current.isDate(started, inSameDayAs: now),
               configuration.plan.cap(for: app, at: started) == configuration.plan.cap(for: app, at: now) {
                PlanMonitoring.shield(app, at: until)
            }
            update(app.id, restartsMonitoring: false) { $0.unlockedUntil = nil }
        }
    }

    /// Lifts plan blocks the monitor should have lifted: ones from a
    /// previous day, or from before a part of the day that opened more time.
    /// Days with an early unlock are left to the monitor, which recounts them.
    private func liftLapsedPlanBlocks(now: Date) {
        for app in configuration.plan.apps where isPlanBlocked(app) && !app.course.isMissed(now) {
            guard let shieldedAt = PlanMonitoring.shieldedAt(app.id),
                  PlanMonitoring.blockHasLapsed(for: app, in: configuration.plan, shieldedAt: shieldedAt, now: now)
            else { continue }
            PlanMonitoring.lift(app.id)
        }
    }

    /// With Screen Time access switched off nothing is blocked, so the day
    /// counts as missed for every app whose limits are running.
    private func recordAccessLoss(now: Date) {
        guard AuthorizationCenter.shared.authorizationStatus == .denied else { return }
        for app in configuration.plan.apps where app.course.hasStarted(at: now) && !app.course.isMissed(now) {
            update(app.id, restartsMonitoring: false) { _ = $0.course.recordMiss(at: now) }
        }
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

    /// Watches a threshold for every cap in force today or coming up, so
    /// each part of the day and each week's limit applies without the app.
    /// Today's limit never changes mid-day, so an existing shield is left in place.
    private func restart(_ app: PlannedApp, now: Date = Date()) {
        let rule = BlockingRule.plan(app.id)
        center.stopMonitoring([rule.activityName])
        guard isEntitled, app.isEnforced(at: now) else { return PlanMonitoring.lift(app.id) }
        do {
            try PlanMonitoring.start(app, in: configuration.plan, center: center, now: now)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Watches the start of the afternoon and the evening while the plan has
    /// apps, so the monitor can lift blocks when more time opens up.
    private func watchPlanParts(monitored: Set<String>? = nil) {
        let monitored = monitored ?? Set(center.activities.map(\.rawValue))
        let wanted = isEntitled && !configuration.plan.apps.isEmpty
        for part in PlanMonitoring.laterParts {
            let rule = BlockingRule.planPart(part)
            if wanted, !monitored.contains(rule.rawValue) {
                do {
                    try center.startMonitoring(rule.activityName, during: PlanMonitoring.schedule(for: part))
                } catch {
                    errorMessage = Self.message(for: error)
                }
            } else if !wanted, monitored.contains(rule.rawValue) {
                center.stopMonitoring([rule.activityName])
            }
        }
    }

    private static func minutes(_ threshold: DateComponents) -> Int {
        (threshold.hour ?? 0) * 60 + (threshold.minute ?? 0)
    }

    private static func event(for selection: FamilyActivitySelection, minutes: Int) -> DeviceActivityEvent {
        PlanMonitoring.event(for: selection, minutes: minutes)
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
            // Thresholds are compared too, so a changed heads-up lead takes effect.
            let registered = center.events(for: rule.activityName)
            let isCurrent = PlanMonitoring.events(for: app, in: configuration.plan, now: now).allSatisfy { name, event in
                registered[name].map { Self.minutes($0.threshold) == Self.minutes(event.threshold) } ?? false
            }
            if !monitored.contains(rule.rawValue) || !isCurrent {
                restart(app, now: now)
            }
        }
        watchPlanParts(monitored: monitored)
        finishUnlocks(now: now)
        liftLapsedPlanBlocks(now: now)
        recordAccessLoss(now: now)
        // Monitoring left behind by deleted rules.
        var known = Set(BlockingRule.all(in: configuration).map(\.rawValue))
        if !configuration.plan.apps.isEmpty {
            known.formUnion(PlanMonitoring.laterParts.map { BlockingRule.planPart($0).rawValue })
            known.insert(BlockingRule.planUnlock.rawValue)
        }
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
            PlanMonitoring.setShieldedAt(nil, for: app.id)
        }
        if let pending = configuration.plan.pendingSpread, now >= pending.effective {
            configuration.plan.spread = pending.spread
            configuration.plan.pendingSpread = nil
            changed = true
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
