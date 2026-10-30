import Foundation

/// One app's way down from where the user started to their target, a daily
/// limit at a time. Each limit is held for a week before the next, because
/// cuts small enough to stick beat big ones that don't. The cut is a share of
/// the current limit, so it's large while there's slack and shrinks near the
/// target, where each minute is harder to give up.
///
/// Every number here is user-entered or derived from user entries, like the
/// goal. It holds the limits the user chose, never measured usage.
struct ReductionCourse: Codable, Equatable {
    /// Daily minutes the user said the app took when they started.
    private(set) var baselineMinutes: Int
    private(set) var targetMinutes: Int
    /// Every limit the app has had, oldest first. The last may start at the
    /// next midnight.
    private(set) var steps: [Step]
    /// "Not yet" at a check-in moves the next one back a week.
    private(set) var heldUntil: Date?

    struct Step: Codable, Equatable {
        var dailyMinutes: Int
        /// When the limit took effect.
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
    /// Days each limit is held before the next can start.
    static let stepDays = 7

    /// Starts the course with its first limit, effective `start`.
    init(baselineMinutes: Int, targetMinutes: Int? = nil, start: Date) {
        let baseline = Self.clamped(Self.rounded(Double(baselineMinutes)), Self.minimumBaselineMinutes, Self.maximumBaselineMinutes)
        self.baselineMinutes = baseline
        self.targetMinutes = Self.validTarget(targetMinutes ?? Self.defaultTarget(baselineMinutes: baseline), baseline: baseline)
        steps = [Step(dailyMinutes: Self.nextLimit(from: baseline, toward: self.targetMinutes), startedAt: start)]
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baselineMinutes = try container.decode(Int.self, forKey: .baselineMinutes)
        targetMinutes = try container.decode(Int.self, forKey: .targetMinutes)
        steps = try container.decode([Step].self, forKey: .steps)
        heldUntil = try container.decodeIfPresent(Date.self, forKey: .heldUntil)
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

    /// The most recent limit the user chose. It may not start until the next midnight.
    var latest: Step { steps[steps.count - 1] }
    var latestMinutes: Int { latest.dailyMinutes }
    var isAtTarget: Bool { latestMinutes <= targetMinutes }
    /// Limits still ahead, ending at the target.
    var remainingLimits: [Int] { Self.ladder(from: latestMinutes, to: targetMinutes) }
    var nextMinutes: Int? { remainingLimits.first }
    /// Daily minutes back compared with where the user started.
    var minutesBack: Int { max(baselineMinutes - latestMinutes, 0) }
    var minutesBackAtTarget: Int { max(baselineMinutes - targetMinutes, 0) }

    /// The limit in force at `date`; nil before the first one starts.
    func limit(at date: Date) -> Int? {
        steps.last { $0.startedAt <= date }?.dailyMinutes
    }

    /// Whether usage that reached `minutes` is over the limit in force at `date`.
    func isOverLimit(atThreshold minutes: Int, at date: Date) -> Bool {
        limit(at: date).map { $0 <= minutes } ?? false
    }

    /// Whether the latest limit is still waiting for its midnight.
    func hasScheduledChange(at date: Date) -> Bool {
        latest.startedAt > date
    }

    /// Every limit that is in force at `date` or starts later. iOS watches a
    /// threshold for each, so a change takes effect at midnight without the app.
    func limitsInForce(from date: Date) -> Set<Int> {
        Set(steps.filter { $0.startedAt > date }.map(\.dailyMinutes) + [limit(at: date)].compactMap { $0 })
    }

    /// The earliest midnight the next limit can start: a full week after the
    /// latest one started, or later if the user held. Nil at the target.
    func nextStepDate(calendar: Calendar = .current) -> Date? {
        guard !isAtTarget else { return nil }
        let week = calendar.date(byAdding: .day, value: Self.stepDays, to: calendar.startOfDay(for: latest.startedAt))!
        guard let heldUntil else { return week }
        return max(week, calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: heldUntil))!)
    }

    /// The check-in opens on the last day of the step, so a "yes" that day
    /// starts the next limit at midnight, right on the week.
    func checkInDate(calendar: Calendar = .current) -> Date? {
        nextStepDate(calendar: calendar).map { calendar.date(byAdding: .day, value: -1, to: $0)! }
    }

    func isReadyForNextStep(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        checkInDate(calendar: calendar).map { date >= $0 } ?? false
    }

    /// When the target limit starts if each step is taken at its check-in.
    func projectedTargetDate(calendar: Calendar = .current) -> Date? {
        guard let next = nextStepDate(calendar: calendar) else { return nil }
        return calendar.date(byAdding: .day, value: Self.stepDays * (remainingLimits.count - 1), to: next)
    }

    /// A limit to go back to when the latest one is too much: the last
    /// looser limit, or on the first step, a cut half as big. Nil when that
    /// would be no cut at all.
    var easedBackMinutes: Int? {
        if let previous = steps.dropLast().last(where: { $0.dailyMinutes > latestMinutes }) {
            return previous.dailyMinutes
        }
        let eased = latestMinutes + max(Self.rounded(Double(baselineMinutes - latestMinutes) / 2), Self.increment)
        return eased < baselineMinutes ? eased : nil
    }

    // MARK: - Changes
    //
    // Plan changes start at a midnight, so each limit covers whole days and
    // changing course in the moment, while blocked, does nothing until then.

    /// Takes the next limit, starting `date`.
    mutating func stepDown(effective date: Date) {
        guard let next = nextMinutes else { return }
        steps.append(Step(dailyMinutes: next, startedAt: date))
        heldUntil = nil
    }

    /// Keeps the latest limit for another week.
    mutating func hold(at date: Date = Date(), calendar: Calendar = .current) {
        guard !isAtTarget else { return }
        heldUntil = calendar.date(byAdding: .day, value: Self.stepDays, to: calendar.startOfDay(for: date))
    }

    /// Goes back to a looser limit, starting `date`.
    mutating func easeBack(effective date: Date) {
        guard let eased = easedBackMinutes else { return }
        steps.append(Step(dailyMinutes: eased, startedAt: date))
        heldUntil = nil
    }

    /// Drops a limit that hasn't started yet. The first limit stays; ending
    /// the course is a separate decision.
    mutating func cancelScheduledChange(at date: Date) {
        guard steps.count > 1, hasScheduledChange(at: date) else { return }
        steps.removeLast()
    }

    /// A new target. The latest limit stays; one already below a raised
    /// target isn't loosened to meet it.
    mutating func retarget(_ minutes: Int) {
        targetMinutes = Self.validTarget(minutes, baseline: baselineMinutes)
        if isAtTarget { heldUntil = nil }
    }
}

extension Collection where Element == ReductionCourse {
    /// The plan's next check-in: the earliest among apps not yet at target.
    func nextCheckIn(calendar: Calendar = .current) -> Date? {
        compactMap { $0.checkInDate(calendar: calendar) }.min()
    }

    var minutesBack: Int { reduce(0) { $0 + $1.minutesBack } }
    var minutesBackAtTarget: Int { reduce(0) { $0 + $1.minutesBackAtTarget } }
}
