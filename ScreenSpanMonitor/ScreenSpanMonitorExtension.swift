import DeviceActivity
import Foundation
import UserNotifications

/// Turns shields on and off at schedule boundaries, daily limits, and plan limits while
/// ScreenSpan isn't running. It reads the user's blocking choices from the App
/// Group and writes only ManagedSettings shields; it never records usage.
final class ScreenSpanMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard let rule = BlockingRule(activity: activity) else { return }
        guard BlockingEntitlement.isActive else { return rule.clear() }
        let configuration = BlockingConfiguration.load()
        let now = Date()

        switch rule {
        case .session:
            if configuration.activeSession(at: now) != nil { rule.shield(configuration.blockList) }
        case .schedule(let id):
            // Schedules repeat daily; days the user left out are skipped here.
            guard let schedule = configuration.schedules.first(where: { $0.id == id }), schedule.isEnabled,
                  schedule.weekdays.contains(schedule.windowStartWeekday(for: now))
            else { return rule.clear() }
            rule.shield(configuration.blockList)
        case .limit:
            // Each day starts with a fresh allowance.
            rule.clear()
        case .plan(let id):
            PlanMonitoring.lift(id)
        case .planPart:
            planPartStarted(configuration.plan, now: now)
        case .planUnlock:
            break
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        switch BlockingRule(activity: activity) {
        case .planPart: break
        case .planUnlock: planUnlockEnded()
        case .plan(let id): PlanMonitoring.lift(id)
        case let rule?: rule.clear()
        case nil: break
        }
    }

    /// A later part of the day has started. Apps whose cap just went up get
    /// their block lifted; time they didn't use earlier is still theirs.
    private func planPartStarted(_ plan: ReductionPlan, now: Date) {
        let justBefore = now.addingTimeInterval(-120)
        for app in plan.enforcedApps(at: now) {
            guard let cap = plan.cap(for: app, at: now), let before = plan.cap(for: app, at: justBefore),
                  cap > before, !app.isUnlocked(at: now)
            else { continue }
            guard app.course.isMissed(now) else {
                PlanMonitoring.lift(app.id)
                continue
            }
            // After an early unlock, usage may already be past the new cap,
            // and the thresholds it crossed while unlocked won't fire again.
            // Watching afresh counts the day so far and blocks again if so.
            // Before iOS 17.4 a restart forgets the day, so the block stays.
            if #available(iOS 17.4, *) {
                PlanMonitoring.lift(app.id)
                try? PlanMonitoring.start(app, in: plan, now: now)
            }
        }
    }

    /// An early unlock is over. In the same part of the day the app was at
    /// its cap when it was unlocked, so it's blocked again. If a new part
    /// started meanwhile, the day is counted afresh instead.
    private func planUnlockEnded() {
        guard BlockingEntitlement.isActive else { return }
        let now = Date()
        let plan = BlockingConfiguration.load().plan
        for app in plan.enforcedApps(at: now) {
            guard let until = app.unlockedUntil, until <= now.addingTimeInterval(90) else { continue }
            let started = until.addingTimeInterval(-TimeInterval(ReductionPlan.unlockMinutes * 60))
            let samePart = Calendar.current.isDate(started, inSameDayAs: now)
                && plan.cap(for: app, at: started) == plan.cap(for: app, at: now)
            if samePart {
                PlanMonitoring.shield(app, at: now)
            } else if #available(iOS 17.4, *), Calendar.current.isDate(started, inSameDayAs: now) {
                try? PlanMonitoring.start(app, in: plan, now: now)
            }
        }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        if case .plan(let id) = BlockingRule(activity: activity) {
            if let cap = BlockingRule.planWarningCap(event) { return planWarningReached(cap: cap, id: id) }
            return planThresholdReached(event, id: id)
        }
        guard event == BlockingRule.limitEvent, case .limit(let id) = BlockingRule(activity: activity),
              BlockingEntitlement.isActive,
              let registered = BlockingConfiguration.load().limits.first(where: { $0.id == id }),
              let limit = registered.applying(at: Date()), limit.isEnabled
        else { return }
        // A change strict mode held until midnight may now allow more time than
        // the threshold iOS is watching; the app re-registers it when opened.
        guard limit.dailyMinutes <= registered.dailyMinutes else { return }
        BlockingRule.limit(id).shield(limit.selection)
    }

    /// Usage today reached a watched total, so it's at or over any cap at or
    /// below it. Totals for other parts of the day and other weeks are
    /// watched too, which is why the minutes are checked against the cap in
    /// force now. While an early unlock runs, nothing blocks.
    private func planThresholdReached(_ event: DeviceActivityEvent.Name, id: UUID) {
        let now = Date()
        let plan = BlockingConfiguration.load().plan
        guard BlockingEntitlement.isActive, let minutes = BlockingRule.planEventMinutes(event),
              let app = plan.apps.first(where: { $0.id == id }),
              app.isEnforced(at: now), !app.isUnlocked(at: now),
              let cap = plan.cap(for: app, at: now), minutes >= cap,
              Self.isPlausible(minutes: minutes, at: now)
        else { return }
        PlanMonitoring.shield(app, at: now)
    }

    /// iOS has delivered thresholds the moment monitoring starts. A day's
    /// total can't be reached before that much of the day has passed.
    private static func isPlausible(minutes: Int, at date: Date) -> Bool {
        date.timeIntervalSince(Calendar.current.startOfDay(for: date)) >= TimeInterval(minutes * 60) - 60
    }

    /// Usage is a few minutes short of the cap in force. Warnings for other
    /// caps fire too and are skipped, as is one arriving after the block,
    /// which a restart mid-day can cause. The monitor only ever sees the
    /// app's token, so the notification names it only when the user gave it
    /// a name in their plan.
    private func planWarningReached(cap: Int, id: UUID) {
        let now = Date()
        let defaults = UserDefaults.appGroup
        let plan = BlockingConfiguration.load().plan
        guard BlockingEntitlement.isActive,
              defaults.object(forKey: SharedConstants.UserDefaultsKey.planLimitWarnings.rawValue) as? Bool ?? true,
              let lead = BlockingRule.planWarningLead(cap: cap),
              let app = plan.apps.first(where: { $0.id == id }),
              app.isEnforced(at: now), !app.isUnlocked(at: now),
              plan.cap(for: app, at: now) == cap, !BlockingRule.plan(id).isShielding,
              Self.isPlausible(minutes: cap - lead, at: now)
        else { return }
        let part = DayPart.at(now)
        let next: String
        if let more = plan.moreTime(for: app, after: now) {
            next = "More opens up at \(more.formatted(date: .omitted, time: .shortened))."
        } else {
            next = "That’s today’s \(Self.duration(app.course.limit(at: now) ?? cap)). It’s back at midnight."
        }
        let content = UNMutableNotificationContent()
        if let name = app.displayName {
            content.title = "\(lead) minutes left on \(name) \(part.thisName)"
        } else {
            content.title = "\(lead) minutes left \(part.thisName)"
            content.subtitle = "An app in your plan"
        }
        content.body = next
        content.sound = .default
        let day = Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970)
        let request = UNNotificationRequest(identifier: "planWarning.\(id.uuidString).\(day).\(part.rawValue)",
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private static func duration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }
}
