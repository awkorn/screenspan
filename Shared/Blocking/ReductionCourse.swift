import Foundation

/// One app's way down from where the user started to their goal, a daily
/// limit at a time. Each limit lasts a week, then the next starts on its own
/// at midnight, because cuts small enough to stick beat big ones that don't.
/// The cut is a share of the current limit, so it's large while there's
/// slack and shrinks near the goal, where each minute is harder to give up.
///
/// Every number here is user-entered or derived from user entries, like the
/// goal. It holds the limits the user chose, never measured usage.
struct ReductionCourse: Codable, Equatable {
    /// Daily minutes the user said the app took when they started.
    private(set) var baselineMinutes: Int
    private(set) var targetMinutes: Int
    /// Limits fixed so far, oldest first: the first, and any that started
    /// before the goal moved. The rest of the way down follows from the last
    /// one, a week per limit; see `plannedSteps`.
    private(set) var steps: [Step]

    struct Step: Codable, Equatable {
        var dailyMinutes: Int
        /// When the limit takes effect, at a midnight.
        var startedAt: Date
    }

    /// Limits are whole multiples of this.
    static let increment = 5
    /// Below this there's too little to cut in steps.
    static let minimumBaselineMinutes = 20
    /// Waking hours; more than this isn't a plausible daily average for one app.
    static let maximumBaselineMinutes = 16 * 60
    static let minimumTargetMinutes = 10
    static let minimumCut = 10
    static let maximumCut = 30
    /// Each step cuts about this share of the current limit.
    static let cutFraction = 0.2
    /// Days each limit lasts before the next starts.
    static let stepDays = 7

    /// Starts the course with its first limit, effective `start`.
    init(baselineMinutes: Int, targetMinutes: Int? = nil, start: Date) {
        let baseline = Self.clamped(Self.rounded(Double(baselineMinutes)), Self.minimumBaselineMinutes, Self.maximumBaselineMinutes)
        self.baselineMinutes = baseline
        self.targetMinutes = Self.validTarget(targetMinutes ?? Self.defaultTarget(baselineMinutes: baseline), baseline: baseline)
        steps = [Step(dailyMinutes: Self.nextLimit(from: baseline, toward: self.targetMinutes), startedAt: start)]
    }

    /// Courses saved by builds with weekly check-ins also carry `heldUntil`,
    /// which is ignored: their remaining limits now follow on their own.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baselineMinutes = try container.decode(Int.self, forKey: .baselineMinutes)
        targetMinutes = try container.decode(Int.self, forKey: .targetMinutes)
        steps = try container.decode([Step].self, forKey: .steps)
        guard !steps.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .steps, in: container, debugDescription: "A course has at least one step")
        }
    }

    // MARK: - Step math

    /// Half of where the user started: ambitious, but reachable in a few weeks.
    static func defaultTarget(baselineMinutes: Int) -> Int {
        validTarget(rounded(Double(baselineMinutes) / 2), baseline: baselineMinutes)
    }

    /// The next limit below `current`. The cut is about a fifth of `current`,
    /// between 10 and 30 minutes, and never leaves a token last step: a
    /// remainder under 10 minutes either joins this step (if the combined cut
    /// still fits within 30) or the rest is split into two even steps.
    static func nextLimit(from current: Int, toward target: Int) -> Int {
        let gap = current - target
        guard gap > 0 else { return current }
        let cut = clamped(rounded(Double(current) * cutFraction), minimumCut, maximumCut)
        if gap <= cut { return target }
        if gap - cut < minimumCut {
            return gap <= maximumCut ? target : current - rounded(Double(gap) / 2)
        }
        return current - cut
    }

    /// Every limit after `current` down to `target`, in order.
    static func ladder(from current: Int, to target: Int) -> [Int] {
        var limits: [Int] = []
        var limit = current
        while limit > target {
            let next = nextLimit(from: limit, toward: target)
            guard next < limit else { break }
            limits.append(next)
            limit = next
        }
        return limits
    }

    static func rounded(_ minutes: Double) -> Int {
        guard minutes.isFinite else { return 0 }
        return Int((minutes / Double(increment)).rounded()) * increment
    }

    private static func validTarget(_ minutes: Int, baseline: Int) -> Int {
        clamped(rounded(Double(minutes)), minimumTargetMinutes, baseline - minimumCut)
    }

    private static func clamped(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        min(max(value, lower), upper)
    }

    // MARK: - Where the course stands

    /// Every limit from the first to the goal: the fixed ones, then the rest
    /// of the ladder, each starting a week after the one before.
    func plannedSteps(calendar: Calendar = .current) -> [Step] {
        let last = steps[steps.count - 1]
        let lastDay = calendar.startOfDay(for: last.startedAt)
        return steps + Self.ladder(from: last.dailyMinutes, to: targetMinutes).enumerated().map { index, minutes in
            Step(dailyMinutes: minutes, startedAt: calendar.date(byAdding: .day, value: Self.stepDays * (index + 1), to: lastDay)!)
        }
    }

    /// The first limit, which starts at the midnight after the plan was made.
    var firstMinutes: Int { steps[0].dailyMinutes }
    /// When the goal limit starts.
    func goalDate(calendar: Calendar = .current) -> Date { plannedSteps(calendar: calendar).last!.startedAt }
    var minutesBackAtTarget: Int { max(baselineMinutes - targetMinutes, 0) }

    func hasStarted(at date: Date) -> Bool { steps[0].startedAt <= date }

    /// The limit in force at `date`; nil before the first one starts.
    func limit(at date: Date, calendar: Calendar = .current) -> Int? {
        plannedSteps(calendar: calendar).last { $0.startedAt <= date }?.dailyMinutes
    }

    func isAtGoal(at date: Date, calendar: Calendar = .current) -> Bool {
        limit(at: date, calendar: calendar).map { $0 <= targetMinutes } ?? false
    }

    /// The next limit to start after `date`; nil once the goal is in force.
    func nextChange(after date: Date, calendar: Calendar = .current) -> Step? {
        plannedSteps(calendar: calendar).first { $0.startedAt > date }
    }

    /// Whether usage that reached `minutes` is over the limit in force at `date`.
    func isOverLimit(atThreshold minutes: Int, at date: Date, calendar: Calendar = .current) -> Bool {
        limit(at: date, calendar: calendar).map { $0 <= minutes } ?? false
    }

    /// Every limit in force at `date` or starting later. iOS watches a
    /// threshold for each, so each week's limit starts at midnight without the app.
    func limitsInForce(from date: Date, calendar: Calendar = .current) -> Set<Int> {
        let planned = plannedSteps(calendar: calendar)
        return Set(planned.filter { $0.startedAt > date }.map(\.dailyMinutes) + [limit(at: date, calendar: calendar)].compactMap { $0 })
    }

    // MARK: - Changes
    //
    // The plan only gets stricter once it starts: limits follow on their own
    // and the goal can move down, never up.

    /// A lower goal. Limits that have started stay as they were; the next one
    /// starts at the later of its week and the next midnight, so today's
    /// limit never changes, and the rest follow a week apart.
    mutating func lowerGoal(to minutes: Int, at date: Date, calendar: Calendar = .current) {
        let goal = Self.validTarget(minutes, baseline: baselineMinutes)
        guard goal < targetMinutes else { return }
        guard hasStarted(at: date) else {
            self = ReductionCourse(baselineMinutes: baselineMinutes, targetMinutes: goal, start: steps[0].startedAt)
            return
        }
        steps = plannedSteps(calendar: calendar).filter { $0.startedAt <= date }
        targetMinutes = goal
        let last = steps[steps.count - 1]
        let next = Self.nextLimit(from: last.dailyMinutes, toward: goal)
        guard next < last.dailyMinutes else { return }
        let week = calendar.date(byAdding: .day, value: Self.stepDays, to: calendar.startOfDay(for: last.startedAt))!
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
        steps.append(Step(dailyMinutes: next, startedAt: max(week, midnight)))
    }
}

extension Collection where Element == ReductionCourse {
    var minutesBackAtTarget: Int { reduce(0) { $0 + $1.minutesBackAtTarget } }
}

// MARK: - Week by week

extension ReductionCourse {
    /// One limit in the plan's schedule, past, present, or ahead.
    struct ScheduleEntry: Equatable {
        enum Kind: Equatable { case past, current, upcoming }

        let kind: Kind
        let dailyMinutes: Int
        let start: Date
        /// When the next limit starts. Nil for the goal, which stays.
        let end: Date?
        let isGoal: Bool
    }

    /// Every limit from the first to the goal, placed relative to `date`.
    func schedule(at date: Date = Date(), calendar: Calendar = .current) -> [ScheduleEntry] {
        let planned = plannedSteps(calendar: calendar)
        return planned.enumerated().map { index, step in
            let end = index + 1 < planned.count ? planned[index + 1].startedAt : nil
            let kind: ScheduleEntry.Kind = step.startedAt > date ? .upcoming : (end.map { $0 <= date } ?? false) ? .past : .current
            return ScheduleEntry(kind: kind, dailyMinutes: step.dailyMinutes, start: step.startedAt, end: end,
                                 isGoal: index == planned.count - 1)
        }
    }

    /// Whole weeks until the goal limit starts; nil once it has.
    func weeksToGoal(at date: Date = Date(), calendar: Calendar = .current) -> Int? {
        let goal = goalDate(calendar: calendar)
        guard goal > date else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: goal).day ?? 0
        return max(Int((Double(days) / Double(Self.stepDays)).rounded(.up)), 1)
    }
}
