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
        print("Passed \(checks) calculation and aggregation checks")
    }
}
