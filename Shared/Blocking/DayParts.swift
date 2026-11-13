import Foundation

/// A stretch of the day with its own share of a planned app's limit. Using
/// a whole day's time by lunch leaves nothing for the evening, when the pull
/// is strongest and quitting the plan is most tempting, so the limit opens
/// up through the day instead.
enum DayPart: Int, CaseIterable, Codable {
    case morning, afternoon, evening

    /// The hour each part starts. Parts stay inside one calendar day, so a
    /// day's limit and Screen Time's daily totals cover the same hours.
    var startHour: Int {
        switch self {
        case .morning: 0
        case .afternoon: 12
        case .evening: 18
        }
    }

    var name: String {
        switch self {
        case .morning: "morning"
        case .afternoon: "afternoon"
        case .evening: "evening"
        }
    }

    /// "this morning", "this afternoon", "this evening".
    var thisName: String { "this \(name)" }

    static func at(_ date: Date, calendar: Calendar = .current) -> DayPart {
        let hour = calendar.component(.hour, from: date)
        return allCases.last { $0.startHour <= hour } ?? .morning
    }

    /// When this part starts on the day of `date`.
    func start(onDayOf date: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: date)
        return calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: day) ?? day
    }
}

/// How a day's limit is shared between its parts. Each part adds to what's
/// available, and time not used carries forward to later the same day, so
/// the caps are running totals: by noon, by 6 PM, by midnight.
enum DaySpread: String, Codable, CaseIterable, Identifiable {
    /// A quarter by noon, half by 6 PM: half the day's time is kept for the evening.
    case evening
    /// A third in each part.
    case even
    /// The whole limit from midnight, as plans worked before day parts.
    case anytime

    var id: Self { self }

    /// Limits shorter than this aren't split; the parts would be a few minutes each.
    static let minimumSplitMinutes = 30

    private var shares: [Double] {
        switch self {
        case .evening: [0.25, 0.5]
        case .even: [1.0 / 3, 2.0 / 3]
        case .anytime: [1, 1]
        }
    }

    /// The most of `limit` usable by the end of each part, in whole fives,
    /// each part adding at least five minutes. The last is always `limit`.
    func caps(limit: Int) -> [Int] {
        guard self != .anytime, limit >= Self.minimumSplitMinutes else { return [limit, limit, limit] }
        var caps: [Int] = []
        for (index, share) in shares.enumerated() {
            let rounded = Int((Double(limit) * share / 5).rounded()) * 5
            let lowest = (caps.last ?? 0) + 5
            let highest = limit - 5 * (shares.count - index)
            caps.append(min(max(rounded, lowest), highest))
        }
        return caps + [limit]
    }

    /// The most of `limit` usable so far today at `date`.
    func cap(limit: Int, at date: Date, calendar: Calendar = .current) -> Int {
        caps(limit: limit)[DayPart.at(date, calendar: calendar).rawValue]
    }

    /// The minutes each part adds.
    func allowances(limit: Int) -> [Int] {
        let caps = caps(limit: limit)
        return caps.enumerated().map { index, cap in cap - (index > 0 ? caps[index - 1] : 0) }
    }

    /// When more of `limit` opens up after `date`, today; nil when the rest
    /// of the day adds nothing and the next fresh time is at midnight.
    func moreTime(limit: Int, after date: Date, calendar: Calendar = .current) -> Date? {
        let caps = caps(limit: limit)
        let now = DayPart.at(date, calendar: calendar)
        return DayPart.allCases
            .first { $0.rawValue > now.rawValue && caps[$0.rawValue] > caps[now.rawValue] }
            .map { $0.start(onDayOf: date, calendar: calendar) }
    }
}
