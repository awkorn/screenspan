import Foundation

enum SharedConstants {
    static let appGroupIdentifier = "group.com.screenspan.shared"

    enum UserDefaultsKey: String {
        case currentAge
        case targetAge
        case screenTimeGoalMinutes
        case onboardingProjectedYears
        case selectedCategories
        case subscriptionStatus
        case onboardingCompleted
    }

    enum DefaultValues {
        static let targetAge: Int = 80
        static let hoursAsleep: Double = 8
        static let wakeHoursPerDay: Double = 16
        static let defaultDailyAvgHours: Double = 5.0 // US average fallback
        static let hoursPerYear: Double = 8760
    }
}
