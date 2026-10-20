import Foundation

@main
struct CalculationTests {
    static func main() {
        var checks = 0
        func expect(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            checks += 1
        }
        func close(_ lhs: Double, _ rhs: Double) -> Bool { abs(lhs - rhs) < 0.000001 }

        let projection = ProjectionCalculator.calculateProjectionFromDaily(currentAge: 25, targetAge: 80, dailyHours: 5)
        expect(close(projection.yearsOnPhone, 55 * 5 / 24), "24-hour year conversion")
        expect(close(projection.daysOnPhone * 24, projection.hoursOnPhone), "Consistent days and hours")
        expect(close(projection.monthsOnPhone / 12, projection.yearsOnPhone), "Consistent months and years")
        expect(close(projection.percentOfWakingLife, 31.25), "16 waking hours assumption")
        let reclaim = ProjectionCalculator.calculateReclaim(currentProjection: projection, goalDailyMinutes: 120, currentAge: 25, targetAge: 80)
        expect(close(reclaim.yearsReclaimed, 55 * 3 / 24), "Projected savings")
        let higherGoal = ProjectionCalculator.calculateReclaim(currentProjection: projection, goalDailyMinutes: 480, currentAge: 25, targetAge: 80)
        expect(higherGoal.yearsReclaimed == 0, "No negative reclaimed time")

        for age in [0, 25, 80, 100, 150] {
            for hours in [-1.0, 0, 5, 16, 24, 100, .nan, .infinity] {
                let p = ProjectionCalculator.calculateProjectionFromDaily(currentAge: age, targetAge: 80, dailyHours: hours)
                expect(p.yearsOnPhone.isFinite && p.yearsOnPhone >= 0, "Finite, nonnegative projection")
                let grid = ProjectionCalculator.calculateLifeGrid(currentAge: age, targetAge: 80, monthsOnPhone: p.monthsOnPhone)
                expect(grid.monthsLived + grid.phoneMonths + grid.freeMonths == 960, "Exactly 960 months")
                expect(grid.freeMonths >= 0 && grid.phoneMonths >= 0, "No grid overflow")
                let won = ProjectionCalculator.calculateLifeGrid(currentAge: age, targetAge: 80, monthsOnPhone: p.monthsOnPhone, regainedMonths: 200)
                expect(won.monthsLived + won.phoneMonths + won.regainedMonths + won.freeMonths == 960, "Won-back months fit the grid")
                expect(won.regainedMonths >= 0 && won.freeMonths >= 0, "No won-back overflow")
            }
        }
        let invalidGrid = ProjectionCalculator.calculateLifeGrid(currentAge: -10, targetAge: -1, monthsOnPhone: .nan)
        expect(invalidGrid.totalMonths == 0 && invalidGrid.monthsLived == 0, "Invalid grid inputs")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12))!
        let interval = ActivitySummary.projectionInterval(now: now, calendar: calendar)
        expect(interval.end == calendar.startOfDay(for: now), "Exclude partial today")
        expect(calendar.dateComponents([.day], from: interval.start, to: interval.end).day == 7, "Seven calendar days across DST")
        expect(interval.duration == 7 * 86400 - 3600, "DST is not a fixed 168-hour interval")
        var summary = ActivitySummary()
        expect(summary.dailyAverageHours == nil, "Unavailable is not zero")
        summary.add(date: interval.start, duration: 3600, calendar: calendar)
        summary.add(date: interval.start.addingTimeInterval(100), duration: 7200, calendar: calendar)
        let secondDay = calendar.date(byAdding: .day, value: 1, to: interval.start)!
        summary.add(date: secondDay, duration: 0, calendar: calendar)
        expect(summary.days.count == 2, "Group same-day segments")
        expect(summary.dailyAverageHours == 1.5, "Count explicit zero, exclude absent days")
        expect(summary.days.map(\.hours) == [3, 0], "Preserve actual daily series")
        summary.add(date: now, duration: .nan, calendar: calendar)
        summary.add(date: now, duration: -1, calendar: calendar)
        expect(summary.days.count == 2, "Discard invalid durations")

        // Dashboard query window
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: interval.end)! }
        func days(between start: Date, and end: Date) -> Int? { calendar.dateComponents([.day], from: start, to: end).day }
        let noStart = ActivitySummary.dashboardInterval(trackingStart: nil, now: now, calendar: calendar)
        expect(noStart == interval, "No start date queries only the projection week")
        let startedToday = ActivitySummary.dashboardInterval(trackingStart: now, now: now, calendar: calendar)
        expect(startedToday == interval, "Starting today needs only the week before")
        let startedRecently = ActivitySummary.dashboardInterval(trackingStart: day(-10), now: now, calendar: calendar)
        expect(startedRecently.start == day(-17) && startedRecently.end == interval.end, "Week before start through yesterday")
        let startedLongAgo = ActivitySummary.dashboardInterval(trackingStart: day(-200), now: now, calendar: calendar)
        expect(days(between: startedLongAgo.start, and: startedLongAgo.end) == 35, "Query capped at 35 days")
        let futureStart = ActivitySummary.dashboardInterval(trackingStart: day(5), now: now, calendar: calendar)
        expect(futureStart == interval, "Future start treated as today")

        // Life regained since starting
        let start = day(-10)
        var history = (-17 ..< -10).map { ActivityDay(date: day($0), hours: 5) }
        history += (-10 ..< 0).map { ActivityDay(date: day($0), hours: 3) }
        history.append(ActivityDay(date: interval.end, hours: 9))
        let measured = LifeRegainedProgress(days: history, trackingStart: start.addingTimeInterval(3600 * 15),
                                            savedStartingMinutes: 120, now: now, calendar: calendar)
        expect(measured.startingPaceHours == 5 && measured.startingPaceSource == .measured(days: 7), "Measured week wins over saved entry")
        expect(measured.trackedDays.count == 10, "Start day counts; partial today excluded")
        expect(measured.currentPaceHours == 3 && measured.hoursBackSoFar == 20, "Since-start average and time back")
        expect(measured.coversWholeSinceStart, "Recent start fully covered")
        expect(measured.trackedDays(inLast: 7, calendar: calendar).count == 7, "Last seven tracked days")
        expect(measured.trackedDays(inLast: 1, calendar: calendar).first?.date == day(-1), "Yesterday")
        let regained = measured.regained(currentAge: 25, targetAge: 80)!
        expect(close(regained.yearsReclaimed, 55 * 365 * 2 / 8760), "Regained years from pace difference")
        let gapped = LifeRegainedProgress(days: history.filter { $0.date != day(-1) }, trackingStart: start,
                                          savedStartingMinutes: 0, now: now, calendar: calendar)
        expect(gapped.trackedDays.count == 9 && gapped.trackedDays(inLast: 1, calendar: calendar).isEmpty, "Missing days are not zero")

        let longAgo = day(-200)
        let recentOnly = Array(history.suffix(11))
        let saved = LifeRegainedProgress(days: recentOnly, trackingStart: longAgo, savedStartingMinutes: 300, now: now, calendar: calendar)
        expect(saved.startingPaceHours == 5 && saved.startingPaceSource == .saved, "Saved starting point after week ages out")
        expect(!saved.coversWholeSinceStart, "Long-ago start only partly covered")
        let missing = LifeRegainedProgress(days: recentOnly, trackingStart: longAgo, savedStartingMinutes: 0, now: now, calendar: calendar)
        expect(missing.startingPaceHours == nil && missing.regained(currentAge: 25, targetAge: 80) == nil, "No invented starting pace")
        let thin = LifeRegainedProgress(days: Array(history[5...]), trackingStart: start, savedStartingMinutes: 0, now: now, calendar: calendar)
        expect(thin.startingPaceHours == nil, "Two reported days are too few for a starting pace")
        let firstDay = LifeRegainedProgress(days: history, trackingStart: now, savedStartingMinutes: 0, now: now, calendar: calendar)
        expect(firstDay.startingPaceHours == 3 && firstDay.currentPaceHours == nil && firstDay.regained(currentAge: 25, targetAge: 80) == nil, "No progress before first full day")
        let wonBack = ProjectionCalculator.calculateLifeGrid(currentAge: 25, targetAge: 80, monthsOnPhone: 100, regainedMonths: .nan)
        expect(wonBack.regainedMonths == 0 && wonBack.freeMonths == 960 - 300 - 100, "Invalid won-back months ignored")

        // Trend line and goal streak
        let trend = ActivityDay.trailingAverages(of: history.filter { $0.date < interval.end }, calendar: calendar)
        expect(trend.first?.date == day(-15), "Trend waits for three reported days")
        expect(trend.last.map { close($0.hours, 3) } == true, "Trend averages the trailing week")
        let goalHistory = [ActivityDay(date: day(-4), hours: 3), ActivityDay(date: day(-3), hours: 1.5),
                           ActivityDay(date: day(-2), hours: 2), ActivityDay(date: day(-1), hours: 1)]
        let adherence = GoalAdherence(days: goalHistory, goalHours: 2, startDay: day(-5), now: now, calendar: calendar)
        expect(adherence.recent.count == 5 && adherence.recent.first?.hours == nil, "Goal days from start, missing kept")
        expect(adherence.daysReported == 4 && adherence.daysMet == 3 && adherence.currentStreak == 3, "Goal met count and streak")
        let broken = GoalAdherence(days: goalHistory.filter { $0.date != day(-1) }, goalHours: 2, startDay: day(-30), now: now, calendar: calendar)
        expect(broken.recent.count == 14 && broken.currentStreak == 0, "Missing yesterday ends streak; 14-day cap")

        let worse = ProjectionCalculator.calculateRegained(startingDailyHours: 2, currentDailyHours: 4, currentAge: 25, targetAge: 80)
        expect(worse.yearsReclaimed == 0, "No negative regained time")
        print("Passed \(checks) calculation and aggregation checks")
    }
}
