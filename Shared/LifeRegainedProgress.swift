import Foundation

/// Since-start comparison, built inside the report extension from the daily
/// totals it already holds. The host supplies only the start date and an
/// optional starting point the user typed; nothing here is written anywhere.
struct LifeRegainedProgress: Equatable {
    enum StartingPaceSource: Equatable {
        /// Average of the reported days in the week before the start date.
        case measured(days: Int)
        /// The user's own entry, used once Screen Time no longer has that week.
        case saved
    }

    let startDay: Date
    let today: Date
    let startingPaceHours: Double?
    let startingPaceSource: StartingPaceSource?
    /// Completed days on or after the start date that Screen Time returned.
    let trackedDays: [ActivityDay]
    /// False when the start date is older than the query reaches, so tracked
    /// days cover only the most recent part of the time since starting.
    let coversWholeSinceStart: Bool

    init(
        days: [ActivityDay],
        trackingStart: Date,
        savedStartingMinutes: Double,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let today = calendar.startOfDay(for: now)
        let startDay = min(calendar.startOfDay(for: trackingStart), today)
        let baselineWeek = DateInterval(
            start: calendar.date(byAdding: .day, value: -SharedConstants.DefaultValues.baselineDays, to: startDay)!,
            end: startDay
        )
        let baselineDays = days.within(baselineWeek)

        if baselineDays.count >= SharedConstants.DefaultValues.minimumBaselineDays,
           let measured = ActivityDay.averageHours(of: baselineDays) {
            startingPaceHours = measured
            startingPaceSource = .measured(days: baselineDays.count)
        } else if savedStartingMinutes.isFinite, savedStartingMinutes > 0 {
            startingPaceHours = min(savedStartingMinutes / 60, 24)
            startingPaceSource = .saved
        } else {
            startingPaceHours = nil
            startingPaceSource = nil
        }

        self.startDay = startDay
        self.today = today
        trackedDays = days.within(DateInterval(start: startDay, end: today))
        coversWholeSinceStart = ActivitySummary.dashboardInterval(
            trackingStart: trackingStart, now: now, calendar: calendar
        ).start <= startDay
    }

    /// Daily average across tracked days since starting.
    var currentPaceHours: Double? {
        ActivityDay.averageHours(of: trackedDays)
    }

    /// Phone time below the starting pace, summed over tracked days. Negative
    /// when usage has been above the starting pace.
    var hoursBackSoFar: Double? {
        guard let startingPaceHours, !trackedDays.isEmpty else { return nil }
        return trackedDays.reduce(0) { $0 + startingPaceHours - $1.hours }
    }

    func regained(currentAge: Int, targetAge: Int) -> ReclaimResult? {
        guard let startingPaceHours, let currentPaceHours else { return nil }
        return ProjectionCalculator.calculateRegained(
            startingDailyHours: startingPaceHours,
            currentDailyHours: currentPaceHours,
            currentAge: currentAge,
            targetAge: targetAge
        )
    }

    func trackedDays(inLast count: Int, calendar: Calendar = .current) -> [ActivityDay] {
        let start = calendar.date(byAdding: .day, value: -count, to: today)!
        return trackedDays.within(DateInterval(start: start, end: today))
    }
}
