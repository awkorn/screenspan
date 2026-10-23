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

        // Onboarding reveal
        expect(close(RevealMath.daysPerYear(dailyHours: 4.8), 73), "Days per year at 4h 48m")
        expect(RevealMath.daysPerYear(dailyHours: .nan) == 0 && RevealMath.daysPerYear(dailyHours: 30) == 365, "Days per year bounded")
        expect(RevealMath.underestimateHours(guess: 3, actual: 4.5) == 1.5, "Underestimate is positive")
        expect(RevealMath.potentialTargets(currentDailyHours: 2.1) == [1], "Only targets meaningfully below pace")
        expect(RevealMath.potentialTargets(currentDailyHours: 0.9).isEmpty, "No targets when already low")
        expect(close(TimeIntention.read.unitsPerYear(dailyHours: 6), 365), "Books per year")
        expect(TimeIntention.language.unitsPerYear(dailyHours: -1) == 0, "No negative conversions")
        expect(TimeIntention.resolve(nil) == TimeIntention.defaults && TimeIntention.resolve(["bogus"]) == TimeIntention.defaults, "Intention defaults")
        expect(TimeIntention.resolve(["sleep", "read"]) == [.read, .sleep], "Intentions in display order")
        expect(TimeIntention.read.unitLabel(count: 1) == "book" && TimeIntention.read.unitLabel(count: 2) == "books", "Unit plurals")

        // Reveal layout: the host's window must land on the right goal row.
        expect(OnboardingRevealLayout.goalValues.count == 31, "Goal rows from 30m to 8h in 15-minute steps")
        expect(OnboardingRevealLayout.goalIndex(0.5) == 0 && OnboardingRevealLayout.goalIndex(2) == 6, "Goal row index")
        expect(OnboardingRevealLayout.goalIndex(0) == 0 && OnboardingRevealLayout.goalIndex(20) == 30, "Goal index clamped")
        expect(OnboardingRevealLayout.goalValues[OnboardingRevealLayout.goalIndex(3.75)] == 3.75, "Row matches its goal")
        expect(OnboardingRevealLayout.goalOffset(0.5, panelHeight: 600) == 3000, "Goal strip starts after five panels")
        expect(OnboardingRevealLayout.totalHeight(panelHeight: 600) == 3000 + 31 * OnboardingRevealLayout.goalRowHeight, "Total report height")
        expect(OnboardingRevealLayout.panelOffset(9, panelHeight: 600) == 2400, "Panel offset clamped")

        let worse = ProjectionCalculator.calculateRegained(startingDailyHours: 2, currentDailyHours: 4, currentAge: 25, targetAge: 80)
        expect(worse.yearsReclaimed == 0, "No negative regained time")
        // Block schedules: windows, overnight weekday attribution, and DST.
        func at(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 10) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
        }
        // October 2026: the 19th is a Monday, the 24th a Saturday, the 25th a Sunday.
        let work = BlockSchedule(name: "Work", startMinute: 9 * 60, endMinute: 17 * 60, weekdays: BlockSchedule.weekdaysOnly)
        expect(work.isActive(at: at(19, 9), calendar: calendar), "Window starts on time")
        expect(!work.isActive(at: at(19, 17), calendar: calendar), "Window end is exclusive")
        expect(!work.isActive(at: at(24, 12), calendar: calendar), "Skipped weekday")
        expect(work.end(after: at(19, 12), calendar: calendar) == at(19, 17), "Daytime end")
        expect(work.end(after: at(19, 18), calendar: calendar) == nil, "No end when inactive")
        let bedtime = BlockSchedule(name: "Bed", startMinute: 22 * 60, endMinute: 7 * 60, weekdays: [6]) // Friday nights
        expect(bedtime.isOvernight && bedtime.durationMinutes == 9 * 60, "Overnight duration")
        expect(bedtime.isActive(at: at(23, 23), calendar: calendar), "Friday night is on")
        expect(bedtime.isActive(at: at(24, 6, 59), calendar: calendar), "Saturday morning belongs to Friday")
        expect(!bedtime.isActive(at: at(24, 23), calendar: calendar), "Saturday night is off")
        expect(!bedtime.isActive(at: at(23, 6), calendar: calendar), "Friday morning belongs to Thursday")
        expect(bedtime.windowStartWeekday(for: at(24, 3), calendar: calendar) == 6, "Window started Friday")
        expect(bedtime.end(after: at(23, 23), calendar: calendar) == at(24, 7), "Overnight end is next morning")
        let saturdayNight = BlockSchedule(name: "Sat", startMinute: 22 * 60, endMinute: 7 * 60, weekdays: [7])
        expect(saturdayNight.isActive(at: at(25, 2), calendar: calendar), "Sunday morning wraps to Saturday")
        expect(!BlockSchedule(name: "Short", startMinute: 600, endMinute: 610).isValid, "Under 15 minutes rejected")
        expect(!BlockSchedule(name: "Always", startMinute: 600, endMinute: 600).isValid, "All-day rejected")
        expect(!BlockSchedule(name: "None", startMinute: 600, endMinute: 700, weekdays: []).isValid, "No days rejected")
        expect(BlockSchedule.presets.allSatisfy(\.isValid), "Presets are valid")
        let copy = BlockSchedule.presets[0].duplicated()
        expect(copy.id != BlockSchedule.presets[0].id && copy.startMinute == BlockSchedule.presets[0].startMinute, "Preset copies get new IDs")
        // US DST ends Sunday, November 1, 2026 at 2:00.
        let overnightDST = BlockSchedule(name: "Bed", startMinute: 22 * 60, endMinute: 7 * 60)
        expect(overnightDST.end(after: at(31, 23, month: 10), calendar: calendar) == at(1, 7, month: 11), "Overnight end across DST")
        var english = calendar
        english.locale = Locale(identifier: "en_US")
        expect(work.weekdaySummary(calendar: english) == "Weekdays" && bedtime.weekdaySummary(calendar: english) == "Fri", "Day summaries")
        expect(BlockSchedule.orderedWeekdays(calendar: calendar).count == 7, "All weekdays listed")

        print("Passed \(checks) calculation and aggregation checks")
    }
}
