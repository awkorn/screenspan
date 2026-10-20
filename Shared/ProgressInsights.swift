import Foundation

extension ActivityDay {
    /// Trailing seven-day average for each reported day, once enough of that
    /// window was reported. Smooths daily noise without inventing missing days.
    static func trailingAverages(
        of days: [ActivityDay],
        window: Int = 7,
        minimumDays: Int = 3,
        calendar: Calendar = .current
    ) -> [ActivityDay] {
        days.compactMap { day in
            let start = calendar.date(byAdding: .day, value: -(window - 1), to: day.date)!
            let end = calendar.date(byAdding: .day, value: 1, to: day.date)!
            let windowDays = days.within(DateInterval(start: start, end: end))
            guard windowDays.count >= minimumDays, let average = averageHours(of: windowDays) else { return nil }
            return ActivityDay(date: day.date, hours: average)
        }
    }
}

/// How recent completed days since starting compare with the daily goal.
struct GoalAdherence: Equatable {
    struct Day: Identifiable, Equatable {
        let date: Date
        /// `nil` when Screen Time did not report the day.
        let hours: Double?
        let goalHours: Double
        var id: Date { date }
        var met: Bool? { hours.map { $0 <= goalHours } }
    }

    /// Calendar days, oldest first, from the later of the start day or
    /// `count` days ago through yesterday.
    let recent: [Day]

    init(
        days: [ActivityDay],
        goalHours: Double,
        startDay: Date,
        count: Int = 14,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let today = calendar.startOfDay(for: now)
        let earliest = calendar.date(byAdding: .day, value: -count, to: today)!
        var date = max(calendar.startOfDay(for: startDay), earliest)
        let hoursByDay = Dictionary(days.map { ($0.date, $0.hours) }, uniquingKeysWith: +)
        var recent: [Day] = []
        while date < today {
            recent.append(Day(date: date, hours: hoursByDay[date], goalHours: goalHours))
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        self.recent = recent
    }

    var daysReported: Int { recent.filter { $0.hours != nil }.count }
    var daysMet: Int { recent.filter { $0.met == true }.count }

    /// Consecutive days at or under the goal ending yesterday. A missing day
    /// ends the streak because it cannot be confirmed.
    var currentStreak: Int {
        recent.reversed().prefix { $0.met == true }.count
    }
}
