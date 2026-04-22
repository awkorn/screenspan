import DeviceActivity
import FamilyControls
import Foundation

/// DeviceActivityFilter helpers used when the host app embeds the
/// `ScreenSpanReport` extension inside a `DeviceActivityReport(filter:)` view.
///
/// PRIVACY NOTE
/// ------------
/// These filters describe *which* segment of usage the extension should
/// render — they never carry raw usage values themselves. Construction of
/// the filter is allowed in the host app; the host still never sees the
/// resulting per-app / per-category numeric results, because those are
/// only delivered to `makeConfiguration(representing:)` inside the
/// extension process.
extension DeviceActivityFilter {
    /// Filter covering the current calendar day. Use only for surfaces
    /// that intentionally show live/in-progress daily activity, not for
    /// lifetime projections.
    static var screenSpanDaily: DeviceActivityFilter {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now

        return DeviceActivityFilter(
            segment: .daily(
                during: DateInterval(start: startOfDay, end: endOfDay)
            ),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
    }

    /// Filter covering the last eight weeks. Used by the History tab
    /// (premium) to render weekly trend data via the extension.
    static var screenSpanHistory: DeviceActivityFilter {
        let calendar = Calendar.current
        let now = Date()
        let eightWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -8, to: now) ?? now

        return DeviceActivityFilter(
            segment: .weekly(
                during: DateInterval(start: eightWeeksAgo, end: now)
            ),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
    }

    /// Filter covering the last 28 completed days. Used by all lifetime
    /// projection surfaces so screen-time calculations are based on a
    /// stable habit window rather than today's still-in-progress usage.
    static var screenSpanProjectionAverage: DeviceActivityFilter {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let twentyEightDaysAgo = calendar.date(byAdding: .day, value: -28, to: startOfToday) ?? startOfToday

        return DeviceActivityFilter(
            segment: .daily(
                during: DateInterval(start: twentyEightDaysAgo, end: startOfToday)
            ),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
    }
}
