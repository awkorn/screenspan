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
        guard !secondsByDay.isEmpty else { return nil }
        return secondsByDay.values.reduce(0, +) / Double(secondsByDay.count) / 3600
    }

    static func projectionInterval(now: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -7, to: end)!
        return DateInterval(start: start, end: end)
    }
}
