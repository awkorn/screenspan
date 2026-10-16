import DeviceActivity
import FamilyControls
import Foundation

extension DeviceActivityFilter {
    /// Seven completed calendar days. Daily buckets preserve real trend points;
    /// excluding today avoids treating a partial day as a change in habits.
    /// iPhone only: the product promises phone time, not combined iPad usage.
    static var screenSpanProjectionAverage: DeviceActivityFilter {
        let interval = ActivitySummary.projectionInterval()
        return DeviceActivityFilter(
            segment: .daily(during: interval),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    /// The dashboard's one query: the week before the user started through
    /// yesterday, capped at 35 days. Life Grid and Stats still use only the
    /// last seven days; Progress uses the rest. Only the start date, a
    /// non-usage setting, shapes it.
    static var screenSpanDashboard: DeviceActivityFilter {
        let interval = ActivitySummary.dashboardInterval(trackingStart: AppGroupManager.shared.trackingStartDate)
        return DeviceActivityFilter(
            segment: .daily(during: interval),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    static var screenSpanHistory: DeviceActivityFilter { screenSpanProjectionAverage }

    static var screenSpanDaily: DeviceActivityFilter {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return DeviceActivityFilter(segment: .daily(during: DateInterval(start: start, end: end)),
                                    users: .all, devices: .init([.iPhone]))
    }
}
