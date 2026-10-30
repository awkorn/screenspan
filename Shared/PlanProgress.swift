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
        var id: Date { date }

        /// Within a minute of the limit counts as reaching it: the block
        /// stops usage right at the limit.
        var reachedLimit: Bool { hours.map { $0 * 60 >= Double(limitMinutes) - 1 } ?? false }
        var stayedUnder: Bool { hours != nil && !reachedLimit }
    }

    let course: ReductionCourse
    /// Index into `course.steps` of the limit in force now; nil before the first starts.
    let stepIndex: Int?
    /// Completed days of the limit in force now, oldest first.
    let stepDays: [Day]
    /// Reported completed days since the first limit started.
    let planDays: [ActivityDay]

    /// `usage` holds the app's hours for each day Screen Time reported,
    /// including zero for reported days without the app.
    init(course: ReductionCourse, usage: [ActivityDay], now: Date = Date(), calendar: Calendar = .current) {
        self.course = course
        let today = calendar.startOfDay(for: now)
        stepIndex = course.steps.lastIndex { $0.startedAt <= now }
        let byDay = Dictionary(usage.map { (calendar.startOfDay(for: $0.date), $0.hours) }, uniquingKeysWith: +)
        if let stepIndex {
            let step = course.steps[stepIndex]
            var days: [Day] = []
            var day = calendar.startOfDay(for: step.startedAt)
            while day < today {
                days.append(Day(date: day, hours: byDay[day], limitMinutes: step.dailyMinutes))
                day = calendar.date(byAdding: .day, value: 1, to: day)!
            }
            stepDays = days
        } else {
            stepDays = []
        }
        let planStart = calendar.startOfDay(for: course.steps[0].startedAt)
        planDays = usage.within(DateInterval(start: planStart, end: max(today, planStart)))
    }

    var currentLimit: Int? { stepIndex.map { course.steps[$0].dailyMinutes } }
    /// "Step 2 of 4", counting limits taken so far and those still ahead.
    var stepNumber: Int { (stepIndex ?? 0) + 1 }
    var stepCount: Int { stepNumber + ReductionCourse.ladder(from: currentLimit ?? course.latestMinutes, to: course.targetMinutes).count }
    /// The last week of the step: what the strip shows and check-ins judge,
    /// even when the user held past the check-in.
    var recentDays: ArraySlice<Day> { stepDays.suffix(ReductionCourse.stepDays) }
    var daysReported: Int { recentDays.filter { $0.hours != nil }.count }
    var daysUnder: Int { recentDays.filter(\.stayedUnder).count }
    var daysAtLimit: Int { recentDays.filter(\.reachedLimit).count }
    var yesterday: Day? { stepDays.last }

    /// Reaching the limit on most days means the next cut would bite before
    /// this one has settled, so holding a week is the better call.
    var suggestsHolding: Bool { daysReported >= 4 && daysAtLimit * 2 > daysReported }

    var averageMinutesSinceStart: Double? {
        ActivityDay.averageHours(of: planDays).map { $0 * 60 }
    }

    /// Daily minutes below where the user said they started, on average.
    var minutesBackSinceStart: Double? {
        averageMinutesSinceStart.map { Double(course.baselineMinutes) - $0 }
    }
}

enum PlanProgress {
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
