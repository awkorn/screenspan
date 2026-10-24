import Foundation

/// Which of the user's rules is blocking an app. The shield matches the item
/// against the saved configuration; this is the result.
enum BlockReason: Equatable {
    case focus(until: Date)
    case schedule(name: String, until: Date)
    case limit(minutes: Int)
    case unknown
}

/// The words on the block screen. Short enough to take in at a glance, framed
/// as the user's own choice and as a pause rather than a ban, and ending on
/// something concrete they said they'd rather do.
struct BlockScreenCopy: Equatable {
    let title: String
    let subtitle: String
    let button: String

    init(appName: String?, reason: BlockReason, intentions: [TimeIntention], now: Date = Date(),
         calendar: Calendar = .current, nudge pick: ([String]) -> String? = { $0.randomElement() }) {
        let name = appName ?? "This app"
        func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
        let status: String
        switch reason {
        case .focus(let end):
            title = "\(name) can wait"
            status = "Focus block · until \(time(end))"
        case .schedule(let schedule, let end):
            title = "\(name) can wait"
            status = "\(schedule) · until \(time(end))"
        case .limit(let minutes):
            title = appName.map { "That’s \($0) for today" } ?? "That’s it for today"
            status = "\(Self.limitLabel(minutes: minutes)) daily limit · back tomorrow"
        case .unknown:
            title = "\(name) can wait"
            status = "Blocked with ScreenSpan"
        }
        let nudge = pick(Self.nudges(for: intentions, at: now, calendar: calendar))
        subtitle = [status, nudge].compactMap { $0 }.joined(separator: "\n")
        button = Self.isNight(now, calendar: calendar) ? "Good night" : "Back to my day"
    }

    /// Every line that suits this moment: the user's own intentions first,
    /// then a few about the time itself.
    static func nudges(for intentions: [TimeIntention], at date: Date, calendar: Calendar = .current) -> [String] {
        let night = isNight(date, calendar: calendar)
        let hour = calendar.component(.hour, from: date)
        let daylight = (8..<19).contains(hour)
        return (intentions.flatMap(\.nudges) + general).compactMap { line in
            switch line.when {
            case .any: line.text
            case .night: night ? line.text : nil
            case .day: night ? nil : line.text
            case .daylight: daylight ? line.text : nil
            }
        }
    }

    static func isNight(_ date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= 21 || hour < 4
    }

    private static let general: [Nudge] = [
        Nudge("Small blocks add up to years."),
        Nudge("This is the time you said you wanted back."),
        Nudge("Past you set this up for a reason."),
    ]

    private static func limitLabel(minutes: Int) -> String {
        let minutes = max(minutes, 0)
        if minutes < 60 { return "\(minutes)-minute" }
        if minutes % 60 == 0 { return "\(minutes / 60)-hour" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

/// One line for the block screen and when it makes sense to show it.
struct Nudge: Equatable {
    enum When { case any, day, night, daylight }
    let text: String
    let when: When

    init(_ text: String, when: When = .any) {
        self.text = text
        self.when = when
    }
}

extension TimeIntention {
    /// Offers, not orders: small, concrete, and in the terms the user picked.
    var nudges: [Nudge] {
        switch self {
        case .read: [
            Nudge("This could be reading time. Five pages?"),
            Nudge("Your book’s still where you left it."),
            Nudge("Read one page. See if you want another."),
        ]
        case .language: [
            Nudge("Five minutes of practice instead?"),
            Nudge("Learn five new words instead?"),
            Nudge("An hour a day gets you conversational in about a year."),
        ]
        case .exercise: [
            Nudge("Ten push-ups, then decide."),
            Nudge("A short walk would feel better than this.", when: .day),
            Nudge("Stretch for two minutes instead?"),
        ]
        case .family: [
            Nudge("Text someone you love instead?"),
            Nudge("Who haven’t you talked to in a while?"),
            Nudge("Call someone. They’ll be glad you did.", when: .day),
        ]
        case .sleep: [
            Nudge("Put it down. Tomorrow you’ll be glad you did.", when: .night),
            Nudge("An extra hour of sleep starts now.", when: .night),
            Nudge("Less phone today, better sleep tonight.", when: .day),
        ]
        case .create: [
            Nudge("Ten minutes on your project instead?"),
            Nudge("Something you make beats something you scroll."),
            Nudge("Make one small thing today.", when: .day),
        ]
        case .travel: [
            Nudge("Plan your next trip instead?"),
            Nudge("Look up somewhere you’ve never been."),
            Nudge("Pick a weekend and put it on the calendar."),
        ]
        case .outdoors: [
            Nudge("Step outside for five minutes?", when: .daylight),
            Nudge("Go find some sunlight.", when: .daylight),
            Nudge("Plan some time outside this weekend."),
        ]
        }
    }
}
