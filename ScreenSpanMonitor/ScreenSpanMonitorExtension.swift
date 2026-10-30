import DeviceActivity
import Foundation

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
        case .limit, .plan:
            // Each day starts with a fresh allowance.
            rule.clear()
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        BlockingRule(activity: activity)?.clear()
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        if case .plan(let id) = BlockingRule(activity: activity) {
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

    /// Usage reached a watched threshold, so it's over any limit at or below
    /// it. The day's limit may be looser than one watched for tomorrow, or
    /// tighter than yesterday's, which is why the minutes are checked.
    private func planThresholdReached(_ event: DeviceActivityEvent.Name, id: UUID) {
        let now = Date()
        guard BlockingEntitlement.isActive, let minutes = BlockingRule.planEventMinutes(event),
              let app = BlockingConfiguration.load().plan.apps.first(where: { $0.id == id }),
              app.isEnforced(at: now), app.course.isOverLimit(atThreshold: minutes, at: now)
        else { return }
        BlockingRule.plan(id).shield(app.selection)
    }
}
