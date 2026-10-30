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
        // A year of phone time, spent on habits instead.
        let heavy = HabitPlan(intentions: [.family, .sleep, .create], dailyHours: 6.84)
        expect(heavy.fitsTogether && heavy.habits == [TimeIntention.family.habits[0], TimeIntention.sleep.habits[0], TimeIntention.create.habits[0]], "Heavy use covers the top habits")
        expect(close(heavy.spareHours, 6.84 * 365 - 547.5 - 365 - 416), "Spare hours after habits")
        let lighter = HabitPlan(intentions: [.family, .sleep, .create], dailyHours: 2.5)
        expect(lighter.fitsTogether && lighter.habits == [TimeIntention.family.habits[1], TimeIntention.sleep.habits[0], TimeIntention.create.habits[1]], "Steps down the costliest habits first")
        expect(lighter.habits.map(\.hoursPerYear).reduce(0, +) <= 2.5 * 365, "Stepped-down habits fit the year")
        let tiny = HabitPlan(intentions: [.language, .sleep, .family], dailyHours: 0.6)
        expect(!tiny.fitsTogether && tiny.spareHours == 0, "Too little time to fit together")
        expect(tiny.habits == [TimeIntention.language.habits[1], TimeIntention.sleep.habits[1], TimeIntention.family.habits[1]], "Each gets the most it can fit alone")
        expect(HabitPlan(intentions: [.travel], dailyHours: 0.05).habits.isEmpty, "Habits that can't fit are left out")
        expect(HabitPlan(intentions: [.read], dailyHours: .nan).habits.isEmpty && HabitPlan(intentions: [], dailyHours: 5).habits.isEmpty, "Invalid plans are empty")
        expect(TimeIntention.allCases.allSatisfy { intention in
            zip(intention.habits, intention.habits.dropFirst()).allSatisfy { $0.hoursPerYear > $1.hoursPerYear }
        }, "Habit tiers get lighter")
        expect(TimeIntention.resolve(nil) == TimeIntention.defaults && TimeIntention.resolve(["bogus"]) == TimeIntention.defaults, "Intention defaults")
        expect(TimeIntention.resolve(["sleep", "read"]) == [.read, .sleep], "Intentions in display order")

        // Block screen copy
        let noon = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12))!
        let late = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 23))!
        let focus = BlockScreenCopy(appName: "LinkedIn", reason: .focus(until: noon), now: noon, calendar: calendar)
        expect(focus.title == "LinkedIn is paused" && focus.subtitle.hasPrefix("Focus block · until "), "Focus copy")
        expect(focus.subtitle.contains("\n\n") && focus.button == "Close app", "Separate support from status; literal close action")
        let limit = BlockScreenCopy(appName: nil, reason: .limit(minutes: 90), now: late, calendar: calendar)
        expect(limit.title == "This app is paused" && limit.subtitle.hasPrefix("1h 30m limit · resets at midnight"), "Limit copy")
        expect(limit.button == focus.button, "Same close action at night")
        let tomorrowMorning = calendar.date(byAdding: .hour, value: 8, to: late)!
        let overnight = BlockScreenCopy(appName: "Instagram", reason: .schedule(name: "Evenings", until: tomorrowMorning),
                                        now: late, calendar: calendar)
        expect(overnight.subtitle.hasPrefix("Evenings · until tomorrow at "), "Overnight schedules identify the next day")
        let unnamed = BlockScreenCopy(appName: "  ", reason: .unknown, now: noon)
        expect(unnamed.title == "This app is paused" && unnamed.subtitle.hasPrefix("App blocking is on"), "Missing names and reasons stay clear")
        let windowStart = Date(timeIntervalSince1970: 1_800_000_000)
        let firstAttempt = BlockScreenCopy(appName: "Instagram", reason: .unknown, now: windowStart)
        let repeatedAttempt = BlockScreenCopy(appName: "Instagram", reason: .unknown, now: windowStart.addingTimeInterval(899))
        expect(firstAttempt == repeatedAttempt, "Repeated attempts keep the message throughout a 15-minute window")
        let anotherApp = BlockScreenCopy(appName: "TikTok", reason: .unknown, now: windowStart)
        expect(firstAttempt.subtitle == anotherApp.subtitle, "Switching apps doesn't generate more advice")
        let laterAttempt = BlockScreenCopy(appName: "Instagram", reason: .unknown, now: windowStart.addingTimeInterval(900))
        expect(firstAttempt.subtitle != laterAttempt.subtitle, "Messages change at the next window")

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

        // Reduction plan: week-long steps from where the user started to their target.
        expect(ReductionCourse.ladder(from: 180, to: 90) == [150, 120, 90], "3h to 1h 30m in three steps")
        expect(ReductionCourse.ladder(from: 360, to: 180) == [330, 300, 270, 240, 210, 180], "Cuts capped at 30 minutes")
        expect(ReductionCourse.ladder(from: 60, to: 30) == [50, 40, 30], "Smaller cuts near the floor")
        expect(ReductionCourse.ladder(from: 150, to: 115) == [130, 115], "No token last step; split evenly")
        expect(ReductionCourse.ladder(from: 90, to: 90).isEmpty && ReductionCourse.nextLimit(from: 60, toward: 90) == 60, "Nothing below the target")
        var everyLadderSteps = true
        for baseline in stride(from: ReductionCourse.minimumBaselineMinutes, through: ReductionCourse.maximumBaselineMinutes, by: 5) {
            for target in stride(from: ReductionCourse.minimumTargetMinutes, through: baseline - ReductionCourse.minimumCut, by: 5) {
                let limits = ReductionCourse.ladder(from: baseline, to: target)
                let cuts = zip([baseline] + limits, limits).map { $0 - $1 }
                everyLadderSteps = everyLadderSteps && limits.last == target && limits.allSatisfy { $0 % 5 == 0 }
                    && cuts.allSatisfy { (ReductionCourse.minimumCut...ReductionCourse.maximumCut).contains($0) }
            }
        }
        expect(everyLadderSteps, "Every ladder ends at its target in 10–30 minute cuts of whole 5 minutes")
        expect(ReductionCourse.defaultTarget(baselineMinutes: 180) == 90 && ReductionCourse.defaultTarget(baselineMinutes: 25) == 15, "Default target is half")
        expect(ReductionCourse.defaultTarget(baselineMinutes: 20) == 10, "Default target leaves room for one cut")

        // October 19, 2026 is a Monday; US DST ends November 1.
        let planStart = at(19, 9)
        var course = ReductionCourse(baselineMinutes: 180, start: planStart)
        expect(course.targetMinutes == 90 && course.currentMinutes == 150 && course.remainingLimits == [120, 90], "First step starts right away")
        expect(course.minutesBack == 30 && course.minutesBackAtTarget == 90, "Minutes back now and at target")
        expect(course.checkInDate(calendar: calendar) == at(26, 0), "Check-in a week after the first day")
        expect(!course.isReadyForNextStep(at: at(25, 23, 59), calendar: calendar) && course.isReadyForNextStep(at: at(26, 0), calendar: calendar), "Ready at the check-in")
        expect(course.projectedTargetDate(calendar: calendar) == at(2, 0, month: 11), "Target date counts whole days across DST")
        expect(course.easedBackMinutes == 165, "Easing back the first step halves the cut")
        course.hold(at: at(26, 10), calendar: calendar)
        expect(course.checkInDate(calendar: calendar) == at(2, 0, month: 11) && course.currentMinutes == 150, "Holding keeps the limit a week")
        course.stepDown(at: at(2, 8, month: 11))
        expect(course.currentMinutes == 120 && course.steps.count == 2, "Stepping down takes the next limit")
        expect(course.checkInDate(calendar: calendar) == at(9, 0, month: 11), "Stepping down clears the hold")
        expect(course.easedBackMinutes == 150, "Easing back returns to the last limit")
        course.easeBack(effective: at(3, 0, month: 11))
        expect(course.currentMinutes == 150 && course.checkInDate(calendar: calendar) == at(10, 0, month: 11), "Eased limit restarts the week")
        expect(course.easedBackMinutes == 165, "Easing back again halves the first cut")
        course.retarget(60)
        expect(course.remainingLimits == [120, 95, 75, 60], "Lower target extends the ladder")
        course.retarget(500)
        expect(course.targetMinutes == 170 && course.isAtTarget && course.currentMinutes == 150, "Raised target never loosens the limit")
        expect(course.checkInDate(calendar: calendar) == nil && course.projectedTargetDate(calendar: calendar) == nil, "No check-ins at target")
        let before = course
        course.stepDown(at: at(12, 9, month: 11))
        expect(course == before, "No step below the target")
        course.retarget(3)
        expect(course.targetMinutes == ReductionCourse.minimumTargetMinutes, "Target floor")

        let smallApp = ReductionCourse(baselineMinutes: 7, start: planStart)
        expect(smallApp.baselineMinutes == 20 && smallApp.currentMinutes == 10 && smallApp.isAtTarget, "Small apps get one step")
        expect(smallApp.easedBackMinutes == 15, "Small apps can still ease back")
        let odd = ReductionCourse(baselineMinutes: 2000, targetMinutes: 2, start: planStart)
        expect(odd.baselineMinutes == 960 && odd.targetMinutes == 10, "Out-of-range entries clamped")
        let tooHigh = ReductionCourse(baselineMinutes: 183, targetMinutes: 400, start: planStart)
        expect(tooHigh.baselineMinutes == 185 && tooHigh.targetMinutes == 175 && tooHigh.currentMinutes == 175, "Target always below the start")

        let light = ReductionCourse(baselineMinutes: 60, start: at(21, 20))
        let plan = [ReductionCourse(baselineMinutes: 180, start: planStart), light]
        expect(plan.minutesBack == 40 && plan.minutesBackAtTarget == 120, "Plan totals")
        expect(plan.nextCheckIn(calendar: calendar) == at(26, 0), "Plan check-in is the earliest app's")
        expect(close(plan.regained(currentAge: 30, targetAge: 80).yearsReclaimed, 50 * 365 * (40.0 / 60) / 8760), "Plan time back so far")
        expect(close(plan[0].regained(atLimit: 90, currentAge: 30, targetAge: 80).yearsReclaimed, 50 * 365 * 1.5 / 8760), "Time back at one app's target")
        expect(close(plan.regainedAtTarget(currentAge: 30, targetAge: 80).yearsReclaimed, 50 * 365 * 2.0 / 8760), "Plan time back at target")

        let encoded = try! JSONEncoder().encode(before)
        expect((try? JSONDecoder().decode(ReductionCourse.self, from: encoded)) == before, "Course round-trips")
        let empty = #"{"baselineMinutes":180,"targetMinutes":90,"steps":[]}"#.data(using: .utf8)!
        expect((try? JSONDecoder().decode(ReductionCourse.self, from: empty)) == nil, "A course without steps is rejected")

        print("Passed \(checks) calculation and aggregation checks")
    }
}
