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

    static var screenSpanHistory: DeviceActivityFilter { screenSpanProjectionAverage }

    static var screenSpanDaily: DeviceActivityFilter {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return DeviceActivityFilter(segment: .daily(during: DateInterval(start: start, end: end)),
                                    users: .all, devices: .init([.iPhone]))
    }
}
