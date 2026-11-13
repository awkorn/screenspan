import Foundation

/// How one planned app is doing, built inside the report extension from the
/// app's daily totals and the limits the user chose. Nothing here is written
/// anywhere or returned to the host.
struct PlanAppProgress: Equatable {
    struct Day: Equatable, Identifiable {
        let date: Date
        /// Nil when Screen Time didn't report the day.
        let hours: Double?
        let limitMinutes: Int
        /// The user unlocked the app early that day.
        var missed = false
        var id: Date { date }

        /// The limit held: usage stayed within it and it wasn't unlocked early.
        var kept: Bool { stayedWithin && !missed }

        /// At or under the limit, with a little slack: the block lands right
        /// at the limit, and Screen Time can count a minute or two past it.
        var stayedWithin: Bool { hours.map { $0 * 60 <= Double(limitMinutes) + 2 } ?? false }
    }

    let course: ReductionCourse
    /// Index into `course.plannedSteps()` of the limit in force now; nil before the first starts.
    let stepIndex: Int?
    let currentLimit: Int?
    /// Completed days of the limit in force now, oldest first.
    let stepDays: [Day]
    /// Reported completed days since the first limit started.
    let planDays: [ActivityDay]

    /// `usage` holds the app's hours for each day Screen Time reported,
    /// including zero for reported days without the app.
    init(course: ReductionCourse, usage: [ActivityDay], now: Date = Date(), calendar: Calendar = .current) {
        self.course = course
        let today = calendar.startOfDay(for: now)
        let planned = course.plannedSteps(calendar: calendar)
        stepIndex = planned.lastIndex { $0.startedAt <= now }
        currentLimit = stepIndex.map { planned[$0].dailyMinutes }
        let byDay = Dictionary(usage.map { (calendar.startOfDay(for: $0.date), $0.hours) }, uniquingKeysWith: +)
        if let stepIndex {
            let step = planned[stepIndex]
            var days: [Day] = []
            var day = calendar.startOfDay(for: step.startedAt)
            while day < today {
                days.append(Day(date: day, hours: byDay[day], limitMinutes: step.dailyMinutes, missed: course.isMissed(day, calendar: calendar)))
                day = calendar.date(byAdding: .day, value: 1, to: day)!
            }
            stepDays = days
        } else {
            stepDays = []
        }
        let planStart = calendar.startOfDay(for: course.steps[0].startedAt)
        planDays = usage.within(DateInterval(start: planStart, end: max(today, planStart)))
    }

    /// The last week of the limit, what the strip shows. The goal limit
    /// lasts past a week.
    var recentDays: ArraySlice<Day> { stepDays.suffix(ReductionCourse.stepDays) }
    var daysReported: Int { recentDays.filter { $0.hours != nil }.count }
    var daysWithin: Int { recentDays.filter(\.kept).count }

    var averageMinutesSinceStart: Double? {
        ActivityDay.averageHours(of: planDays).map { $0 * 60 }
    }

    /// Daily minutes below where the user said they started, on average.
    var minutesBackSinceStart: Double? {
        averageMinutesSinceStart.map { Double(course.baselineMinutes) - $0 }
    }
}

/// One day of the whole plan: kept when every app with a limit that day
/// stayed within it.
struct PlanDay: Equatable, Identifiable {
    enum State: Equatable { case kept, over, unreported, notStarted, today }

    let date: Date
    let state: State
    var id: Date { date }
}

enum PlanProgress {
    /// The last `count` days ending today, oldest first, across every app.
    /// `apps` pairs each course with the app's reported daily hours.
    static func recentDays(
        apps: [(course: ReductionCourse, usage: [ActivityDay])],
        count: Int = 7,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PlanDay] {
        let today = calendar.startOfDay(for: now)
        let usage = apps.map { Dictionary($0.usage.map { (calendar.startOfDay(for: $0.date), $0.hours) }, uniquingKeysWith: +) }
        return (0..<count).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            guard day < today else { return PlanDay(date: day, state: .today) }
            var state = PlanDay.State.notStarted
            for (index, app) in apps.enumerated() {
                guard let limit = app.course.limit(at: day, calendar: calendar) else { continue }
                let appDay = PlanAppProgress.Day(date: day, hours: usage[index][day], limitMinutes: limit,
                                                 missed: app.course.isMissed(day, calendar: calendar))
                if appDay.hours == nil, !appDay.missed {
                    if state != .over { state = .unreported }
                } else if !appDay.kept {
                    state = .over
                } else if state == .notStarted {
                    state = .kept
                }
            }
            return PlanDay(date: day, state: state)
        }
    }

    /// Kept days in a row ending yesterday. A day that wasn't reported ends
    /// the streak, since it can't be confirmed.
    static func streak(_ days: [PlanDay]) -> Int {
        days.filter { $0.state != .today }.reversed().prefix { $0.state == .kept }.count
    }

    /// Change in daily minutes on everything outside the plan, comparing the
    /// week before the plan with the time since. Positive when other apps
    /// took up some of the time. Nil without three reported days on each side.
    static func otherAppsChangeMinutes(
        total: [ActivityDay],
        planned: [[ActivityDay]],
        planStart: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Double? {
        let start = calendar.startOfDay(for: planStart)
        let today = calendar.startOfDay(for: now)
        guard start < today else { return nil }
        let plannedByDay = Dictionary(planned.joined().map { (calendar.startOfDay(for: $0.date), $0.hours) },
                                      uniquingKeysWith: +)
        func otherAverage(_ interval: DateInterval) -> Double? {
            let days = total.within(interval)
            guard days.count >= SharedConstants.DefaultValues.minimumBaselineDays else { return nil }
            let other = days.map { max($0.hours - (plannedByDay[calendar.startOfDay(for: $0.date)] ?? 0), 0) }
            return other.reduce(0, +) / Double(other.count) * 60
        }
        let weekBefore = DateInterval(start: calendar.date(byAdding: .day, value: -7, to: start)!, end: start)
        guard let before = otherAverage(weekBefore),
              let since = otherAverage(DateInterval(start: start, end: today))
        else { return nil }
        return since - before
    }
}
