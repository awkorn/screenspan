import Foundation

/// A repeating window when the distraction list is blocked, such as bedtime.
/// Times are minutes after midnight in the user's calendar. A window whose end
/// is at or before its start runs overnight and belongs to the day it starts.
struct BlockSchedule: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var startMinute: Int
    var endMinute: Int
    /// Calendar weekdays (1 = Sunday … 7 = Saturday) the window starts on.
    var weekdays: Set<Int> = Set(1...7)
    var isEnabled = true

    /// DeviceActivity rejects intervals shorter than 15 minutes.
    static let minimumMinutes = 15
    static let weekdaysOnly: Set<Int> = Set(2...6)
    static let weekendsOnly: Set<Int> = [1, 7]

    static let presets: [BlockSchedule] = [
        BlockSchedule(name: "Bedtime", startMinute: 22 * 60, endMinute: 7 * 60),
        BlockSchedule(name: "Work hours", startMinute: 9 * 60, endMinute: 17 * 60, weekdays: weekdaysOnly),
        BlockSchedule(name: "Slow mornings", startMinute: 6 * 60, endMinute: 9 * 60),
    ]

    /// A copy with its own identity, for starting a new schedule from a preset.
    func duplicated() -> BlockSchedule {
        var copy = self
        copy.id = UUID()
        return copy
    }

    var isOvernight: Bool { endMinute <= startMinute }

    var durationMinutes: Int {
        isOvernight ? 24 * 60 - startMinute + endMinute : endMinute - startMinute
    }

    /// A schedule DeviceActivity accepts that also leaves some time unblocked.
    var isValid: Bool {
        durationMinutes >= Self.minimumMinutes && durationMinutes < 24 * 60 && !weekdays.isEmpty
            && (0..<24 * 60).contains(startMinute) && (0..<24 * 60).contains(endMinute)
    }

    /// The weekday the window around `date` started on. Overnight windows
    /// started yesterday when it is before their end time.
    func windowStartWeekday(for date: Date, calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        guard isOvernight, minuteOfDay(date, calendar: calendar) < endMinute else { return weekday }
        return weekday == 1 ? 7 : weekday - 1
    }

    func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        let minute = minuteOfDay(date, calendar: calendar)
        let inWindow = isOvernight
            ? minute >= startMinute || minute < endMinute
            : minute >= startMinute && minute < endMinute
        return inWindow && weekdays.contains(windowStartWeekday(for: date, calendar: calendar))
    }

    /// When the window containing `date` ends, or nil if it is not active.
    func end(after date: Date, calendar: Calendar = .current) -> Date? {
        guard isActive(at: date, calendar: calendar),
              let sameDay = calendar.date(bySettingHour: endMinute / 60, minute: endMinute % 60, second: 0, of: date)
        else { return nil }
        return sameDay > date ? sameDay : calendar.date(byAdding: .day, value: 1, to: sameDay)
    }

    /// "Every day", "Weekdays", "Weekends", or short day names in week order.
    func weekdaySummary(calendar: Calendar = .current) -> String {
        switch weekdays {
        case Set(1...7): return "Every day"
        case Self.weekdaysOnly: return "Weekdays"
        case Self.weekendsOnly: return "Weekends"
        default:
            let symbols = calendar.shortWeekdaySymbols
            return Self.orderedWeekdays(calendar: calendar)
                .filter(weekdays.contains)
                .map { symbols[$0 - 1] }
                .joined(separator: ", ")
        }
    }

    /// Weekdays starting from the calendar's first day of the week.
    static func orderedWeekdays(calendar: Calendar = .current) -> [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    private func minuteOfDay(_ date: Date, calendar: Calendar) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }
}
