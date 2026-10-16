import Foundation

/// Pure aggregation model. In production, populated only by the report extension.
/// Missing days are not zero-usage days. Explicit zero-duration segments are valid.
struct ActivityDay: Identifiable, Sendable, Equatable {
    let date: Date
    let hours: Double
    var id: Date { date }
}

struct ActivitySummary {
    private var secondsByDay: [Date: TimeInterval] = [:]

    mutating func add(date: Date, duration: TimeInterval, calendar: Calendar = .current) {
        guard duration.isFinite, duration >= 0 else { return }
        secondsByDay[calendar.startOfDay(for: date), default: 0] += duration
    }

    var days: [ActivityDay] {
        secondsByDay.map { ActivityDay(date: $0.key, hours: $0.value / 3600) }
            .sorted { $0.date < $1.date }
    }

    var dailyAverageHours: Double? {
        ActivityDay.averageHours(of: days)
    }

    static func projectionInterval(now: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -7, to: end)!
        return DateInterval(start: start, end: end)
    }

    /// The dashboard's single query: the week before the user started (their
    /// measured starting pace) through yesterday. Capped so a long-time user
    /// never asks iOS for more than baseline + progress days of daily totals;
    /// it always includes the seven-day projection window.
    static func dashboardInterval(
        trackingStart: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DateInterval {
        let recent = projectionInterval(now: now, calendar: calendar)
        guard let trackingStart else { return recent }
        let maxDays = SharedConstants.DefaultValues.baselineDays + SharedConstants.DefaultValues.progressHistoryDays
        let earliest = calendar.date(byAdding: .day, value: -maxDays, to: recent.end)!
        let startDay = calendar.startOfDay(for: min(trackingStart, now))
        let baselineStart = calendar.date(
            byAdding: .day, value: -SharedConstants.DefaultValues.baselineDays, to: startDay)!
        return DateInterval(start: max(min(baselineStart, recent.start), earliest), end: recent.end)
    }
}

extension ActivityDay {
    static func averageHours(of days: [ActivityDay]) -> Double? {
        guard !days.isEmpty else { return nil }
        return days.map(\.hours).reduce(0, +) / Double(days.count)
    }
}

extension Array where Element == ActivityDay {
    func within(_ interval: DateInterval) -> [ActivityDay] {
        filter { $0.date >= interval.start && $0.date < interval.end }
    }
}
