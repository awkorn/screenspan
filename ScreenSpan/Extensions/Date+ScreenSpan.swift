import Foundation

/// Date helper extensions for ScreenSpan
extension Date {
    /// Returns the start of the week (Monday) for this date
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: self)

        return calendar.date(from: components) ?? self
    }

    /// Returns the end of the week (Sunday) for this date
    var endOfWeek: Date {
        var components = DateComponents()
        components.day = 7
        return Calendar.current.date(byAdding: components, to: startOfWeek) ?? self
    }

    /// Returns the start of the month for this date
    var startOfMonth: Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.year, .month], from: self)) ?? self
    }

    /// Returns the end of the month for this date
    var endOfMonth: Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.month = 1
        components.day = -1
        return calendar.date(byAdding: components, to: startOfMonth) ?? self
    }

    /// Returns the start of the year for this date
    var startOfYear: Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.year], from: self)) ?? self
    }

    /// Returns the number of weeks until a given date
    /// - Parameter date: The target date
    /// - Returns: Number of weeks between self and target date
    func weeksUntil(date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekOfYear], from: self, to: date)
        return components.weekOfYear ?? 0
    }

    /// Returns the number of days until a given date
    /// - Parameter date: The target date
    /// - Returns: Number of days between self and target date
    func daysUntil(date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: self, to: date)
        return components.day ?? 0
    }

    /// Returns the number of months between two dates
    /// - Parameter date: The target date
    /// - Returns: Number of months between self and target date
    func monthsBetween(date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: self, to: date)
        return components.month ?? 0
    }

    /// Returns the number of years between two dates
    /// - Parameter date: The target date
    /// - Returns: Number of years between self and target date
    func yearsBetween(date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: self, to: date)
        return components.year ?? 0
    }

    /// Returns a formatted string representing the number of days until a date
    /// - Parameter date: The target date
    /// - Returns: Human-readable string like "3 days" or "1 week"
    func timeUntilFormatted(date: Date) -> String {
        let days = daysUntil(date: date)

        if days < 0 {
            return "Past"
        } else if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Tomorrow"
        } else if days < 7 {
            return "\(days) days"
        } else {
            let weeks = weeksUntil(date: date)
            return "\(weeks) weeks"
        }
    }

    /// Returns a readable date string
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: self)
    }

    /// Returns a readable time string
    func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    /// Returns a readable date and time string
    func formattedDateTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    /// Checks if this date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Checks if this date is tomorrow
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }

    /// Checks if this date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Checks if this date is within this week
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }

    /// Checks if this date is within this month
    var isThisMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }

    /// Checks if this date is within this year
    var isThisYear: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year)
    }

    /// Returns the age in years as of this date
    /// - Parameter birthDate: The birth date
    /// - Returns: Age in years
    func age(from birthDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: birthDate, to: self)
        return components.year ?? 0
    }

    /// Returns a date by adding days
    /// - Parameter days: Number of days to add (can be negative)
    /// - Returns: New date
    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    /// Returns a date by adding weeks
    /// - Parameter weeks: Number of weeks to add (can be negative)
    /// - Returns: New date
    func addingWeeks(_ weeks: Int) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: self) ?? self
    }

    /// Returns a date by adding months
    /// - Parameter months: Number of months to add (can be negative)
    /// - Returns: New date
    func addingMonths(_ months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }

    /// Returns a date by adding years
    /// - Parameter years: Number of years to add (can be negative)
    /// - Returns: New date
    func addingYears(_ years: Int) -> Date {
        Calendar.current.date(byAdding: .year, value: years, to: self) ?? self
    }
}
