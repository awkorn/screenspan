import Foundation

enum SharedConstants {
    static let appGroupIdentifier = "group.com.screenspan.shared"

    enum UserDefaultsKey: String {
        // PRIVACY MODEL
        // -------------
        // Only keys for *non-usage* values (user-entered settings,
        // opaque tokens, subscription state) may be added here.
        // The host app must never store or read numeric screen time
        // usage through this App Group — that data belongs to the
        // `ScreenSpanReport` extension process only.
        //
        // `onboardingProjectedYears` / `onboardingWakingPercent`
        // previously lived here as a channel the host used to
        // reconstruct daily hours. That channel has been removed to
        // prevent it from ever being repurposed for real Screen Time
        // API output; do not reintroduce it.
        case currentAge
        case targetAge
        case screenTimeGoalMinutes
        case selectedCategories
        case subscriptionStatus
        case onboardingCompleted
    }

    enum DefaultValues {
        static let targetAge: Int = 80
        static let hoursAsleep: Double = 8
        static let wakeHoursPerDay: Double = 16
        static let hoursPerYear: Double = 8760
    }
}
