import Foundation

/// One app's way down from where the user started to their goal, a daily
/// limit at a time. Each limit lasts a week, then the next starts on its own
/// at midnight, because cuts small enough to stick beat big ones that don't.
/// The cut is a share of the current limit, so it's large while there's
/// slack and shrinks near the goal, where each minute is harder to give up.
/// The user picks how big a share (`Pace`) and can set any week's limit by
/// hand; those weeks are then kept as they set them.
///
/// Every number here is user-entered or derived from user entries, like the
/// goal. It holds the limits the user chose, never measured usage.
struct ReductionCourse: Codable, Equatable {
    /// Daily minutes the user said the app took when they started.
    private(set) var baselineMinutes: Int
    private(set) var targetMinutes: Int
    /// Limits fixed so far, oldest first: the first, any that started before
    /// the goal moved, and any the user set by hand. The rest of the way down
    /// follows from the last one at `pace`, a week per limit; see `plannedSteps`.
    private(set) var steps: [Step]
    /// How big each step down is.
    private(set) var pace: Pace

    /// How much of the current limit each week cuts.
    enum Pace: String, Codable, CaseIterable, Identifiable {
        case gentle, steady, faster

        var id: Self { self }

        var cutFraction: Double {
            switch self {
            case .gentle: 0.1
            case .steady: 0.2
            case .faster: 0.3
            }
        }

        var minimumCut: Int {
            switch self {
            case .gentle: 5
            case .steady: 10
            case .faster: 15
            }
        }

        var maximumCut: Int {
            switch self {
            case .gentle: 15
            case .steady: 30
            case .faster: 45
            }
        }
    }

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
    /// The goal is at least this far below the starting point.
    static let minimumCut = 10
    /// Days each limit lasts before the next starts.
    static let stepDays = 7

    /// Starts the course with its first limit, effective `start`.
    init(baselineMinutes: Int, targetMinutes: Int? = nil, pace: Pace = .steady, start: Date) {
        let baseline = Self.clamped(Self.rounded(Double(baselineMinutes)), Self.minimumBaselineMinutes, Self.maximumBaselineMinutes)
        self.baselineMinutes = baseline
        self.pace = pace
        self.targetMinutes = Self.validTarget(targetMinutes ?? Self.defaultTarget(baselineMinutes: baseline), baseline: baseline)
        steps = [Step(dailyMinutes: Self.nextLimit(from: baseline, toward: self.targetMinutes, pace: pace), startedAt: start)]
    }

    /// Starts the course with limits the user set week by week, the first
    /// effective `start`. Each is clamped between the goal floor and the
    /// starting point and never above the week before; the last is the goal.
    init(baselineMinutes: Int, limits: [Int], pace: Pace = .steady, start: Date, calendar: Calendar = .current) {
        self.init(baselineMinutes: baselineMinutes, pace: pace, start: start)
        guard !limits.isEmpty else { return }
        var previous = self.baselineMinutes
        let fixed = limits.map { minutes -> Int in
            previous = Self.clamped(Self.rounded(Double(minutes)), Self.minimumTargetMinutes, previous)
            return previous
        }
        setLimits(Self.trimmingHeldGoal(fixed), from: 0, calendar: calendar)
    }

    /// Courses saved by builds with weekly check-ins also carry `heldUntil`,
    /// which is ignored: their remaining limits now follow on their own.
    /// Courses from before paces were steady.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baselineMinutes = try container.decode(Int.self, forKey: .baselineMinutes)
        targetMinutes = try container.decode(Int.self, forKey: .targetMinutes)
        pace = try container.decodeIfPresent(Pace.self, forKey: .pace) ?? .steady
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

    /// The next limit below `current`. At a steady pace the cut is about a
    /// fifth of `current`, between 10 and 30 minutes, and never leaves a token
    /// last step: a remainder under the smallest cut either joins this step
    /// (if the combined cut still fits under the largest) or the rest is split
    /// into two even steps.
    static func nextLimit(from current: Int, toward target: Int, pace: Pace = .steady) -> Int {
        let gap = current - target
        guard gap > 0 else { return current }
        let cut = clamped(rounded(Double(current) * pace.cutFraction), pace.minimumCut, pace.maximumCut)
        if gap <= cut { return target }
        if gap - cut < pace.minimumCut {
            return gap <= pace.maximumCut ? target : current - max(rounded(Double(gap) / 2), increment)
        }
        return current - cut
    }

    /// Every limit after `current` down to `target`, in order.
    static func ladder(from current: Int, to target: Int, pace: Pace = .steady) -> [Int] {
        var limits: [Int] = []
        var limit = current
        while limit > target {
            let next = nextLimit(from: limit, toward: target, pace: pace)
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

    /// Drops repeats of the last limit: once the goal starts, it stays anyway.
    private static func trimmingHeldGoal(_ limits: [Int]) -> [Int] {
        var limits = limits
        while limits.count > 1, limits[limits.count - 2] == limits[limits.count - 1] { limits.removeLast() }
        return limits
    }

    // MARK: - Where the course stands

    /// Every limit from the first to the goal: the fixed ones, then the rest
    /// of the ladder, each starting a week after the one before.
    func plannedSteps(calendar: Calendar = .current) -> [Step] {
        let last = steps[steps.count - 1]
        let lastDay = calendar.startOfDay(for: last.startedAt)
        return steps + Self.ladder(from: last.dailyMinutes, to: targetMinutes, pace: pace).enumerated().map { index, minutes in
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
            self = ReductionCourse(baselineMinutes: baselineMinutes, targetMinutes: goal, pace: pace, start: steps[0].startedAt)
            return
        }
        // Weeks the user set by hand that haven't started yet are kept; the
        // way down continues from the last of them.
        if steps.contains(where: { $0.startedAt > date }) {
            targetMinutes = goal
            return
        }
        steps = plannedSteps(calendar: calendar).filter { $0.startedAt <= date }
        targetMinutes = goal
        let last = steps[steps.count - 1]
        let next = Self.nextLimit(from: last.dailyMinutes, toward: goal, pace: pace)
        guard next < last.dailyMinutes else { return }
        let week = calendar.date(byAdding: .day, value: Self.stepDays, to: calendar.startOfDay(for: last.startedAt))!
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
        steps.append(Step(dailyMinutes: next, startedAt: max(week, midnight)))
    }

    /// Sets one week's limit by hand. `index` counts from the first limit in
    /// `plannedSteps`. Weeks after it that were higher come down to it, and
    /// weeks before it that haven't started and were lower go up to it. Only
    /// weeks that haven't started can change. Before the plan starts a week
    /// can go up to the starting point; after, no higher than `ceiling`,
    /// by default the week's current limit, so the plan never loosens. The
    /// last week is the goal.
    mutating func setLimit(at index: Int, to minutes: Int, at date: Date, ceiling: Int? = nil, calendar: Calendar = .current) {
        let planned = plannedSteps(calendar: calendar)
        guard planned.indices.contains(index), planned[index].startedAt > date else { return }
        let upper = hasStarted(at: date) ? min(ceiling ?? planned[index].dailyMinutes, baselineMinutes) : baselineMinutes
        let value = Self.clamped(Self.rounded(Double(minutes)), Self.minimumTargetMinutes, max(upper, Self.minimumTargetMinutes))
        let first = planned.lastIndex { $0.startedAt <= date }.map { $0 + 1 } ?? 0
        var limits = planned.map(\.dailyMinutes)
        limits[index] = value
        for later in limits.indices where later > index { limits[later] = min(limits[later], value) }
        for earlier in first..<index { limits[earlier] = max(limits[earlier], value) }
        guard limits != planned.map(\.dailyMinutes) else { return }
        setLimits(Self.trimmingHeldGoal(Array(limits[first...])), from: first, calendar: calendar, keeping: planned)
    }

    /// A different pace, before the plan starts. Limits set by hand are
    /// redrawn at the new pace.
    mutating func setPace(_ pace: Pace, at date: Date) {
        guard !hasStarted(at: date), pace != self.pace else { return }
        self = ReductionCourse(baselineMinutes: baselineMinutes, targetMinutes: targetMinutes, pace: pace, start: steps[0].startedAt)
    }

    /// Whether this course's limit is never higher than `other`'s from `date`
    /// on, and today's is the same. Limits change only when a step starts, so
    /// checking each start is enough.
    func isNoLooser(than other: ReductionCourse, from date: Date, calendar: Calendar = .current) -> Bool {
        guard limit(at: date, calendar: calendar) == other.limit(at: date, calendar: calendar) else { return false }
        let changes = (plannedSteps(calendar: calendar) + other.plannedSteps(calendar: calendar)).map(\.startedAt).filter { $0 > date }
        return changes.allSatisfy { day in
            guard let mine = limit(at: day, calendar: calendar) else { return true }
            return other.limit(at: day, calendar: calendar).map { mine <= $0 } ?? true
        }
    }

    /// Replaces every limit from `first` on with `limits`, a week apart from
    /// the limit before, and makes the last one the goal.
    private mutating func setLimits(_ limits: [Int], from first: Int, calendar: Calendar, keeping planned: [Step]? = nil) {
        let planned = planned ?? plannedSteps(calendar: calendar)
        var fixed = Array(planned.prefix(first))
        let anchor = fixed.last.map { calendar.startOfDay(for: $0.startedAt) } ?? steps[0].startedAt
        let weeksAfterAnchor = fixed.isEmpty ? 0 : 1
        for (offset, minutes) in limits.enumerated() {
            let weeks = offset + weeksAfterAnchor
            fixed.append(Step(dailyMinutes: minutes,
                              startedAt: weeks == 0 ? anchor : calendar.date(byAdding: .day, value: Self.stepDays * weeks, to: anchor)!))
        }
        guard !fixed.isEmpty else { return }
        steps = fixed
        targetMinutes = fixed[fixed.count - 1].dailyMinutes
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
