import Foundation

/// Which of the user's rules is blocking an app. The shield matches the item
/// against the saved configuration; this is the result.
enum BlockReason: Equatable {
    case focus(until: Date)
    case schedule(name: String, until: Date)
    case limit(minutes: Int)
    case unknown
}

/// Clear block details and a brief reminder of what stepping away makes room
/// for. The message assumes neither distress nor a particular personal goal.
struct BlockScreenCopy: Equatable {
    let title: String
    let subtitle: String
    let button: String

    init(appName: String?, reason: BlockReason, now: Date = Date(), calendar: Calendar = .current) {
        let name = appName?.trimmingCharacters(in: .whitespacesAndNewlines)
        title = "\(name.flatMap { $0.isEmpty ? nil : $0 } ?? "This app") is paused"

        func endLabel(_ date: Date) -> String {
            let time = date.formatted(date: .omitted, time: .shortened)
            if calendar.isDate(date, inSameDayAs: now) { return "until \(time)" }
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
               calendar.isDate(date, inSameDayAs: tomorrow) {
                return "until tomorrow at \(time)"
            }
            return "until \(date.formatted(date: .abbreviated, time: .shortened))"
        }

        let status: String
        switch reason {
        case .focus(let end):
            status = "Focus block · \(endLabel(end))"
        case .schedule(let schedule, let end):
            let label = schedule.trimmingCharacters(in: .whitespacesAndNewlines)
            status = "\(label.isEmpty ? "Scheduled break" : label) · \(endLabel(end))"
        case .limit(let minutes):
            status = "\(Self.limitLabel(minutes: minutes)) limit · resets at midnight"
        case .unknown:
            status = "App blocking is on"
        }
        subtitle = status + "\n\n" + Self.message(at: now)
        button = "Close app"
    }

    /// Keep the same message across apps and extension reloads within each
    /// 15-minute window. Repeated attempts shouldn't produce a stream of advice.
    /// This needs no saved state or tracking of the user's app-opening attempts.
    static func message(at date: Date) -> String {
        let window = Int(floor(date.timeIntervalSince1970 / (15 * 60)))
        let index = (window % messages.count + messages.count) % messages.count
        return messages[index]
    }

    // Concrete time, choice, and responding to urges before entering an app.
    // Evidence and editorial decisions: docs/BLOCK_SCREEN_COPY.md.
    private static let messages = [
        "Your attention is yours to spend.",
        "Reclaim your time. Start with this moment.",
        "Resist the urge.",
        "Take back your time.",
        "20 minutes less a day frees up over 5 days a year.",
        "The next few minutes are yours to choose.",
    ]

    private static func limitLabel(minutes: Int) -> String {
        let minutes = max(minutes, 0)
        if minutes < 60 { return "\(minutes)-minute" }
        if minutes % 60 == 0 { return "\(minutes / 60)-hour" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
