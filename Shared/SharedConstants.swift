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
        /// When the user finished onboarding (seconds since 1970). A date the
        /// host already knows, not usage; the report uses it to split its own
        /// daily totals into "before" and "since starting".
        case trackingStartDate
        /// Optional starting daily average the user typed in Settings. Used
        /// only after Screen Time no longer returns the week before they started.
        case startingDailyMinutes
    }

    enum DefaultValues {
        static let targetAge: Int = 80
        static let hoursAsleep: Double = 8
        static let wakeHoursPerDay: Double = 16
        static let hoursPerYear: Double = 8760
        /// Completed days before the start date that define the starting pace.
        static let baselineDays = 7
        /// Most recent completed days shown on Progress. Screen Time keeps
        /// roughly a month of history, and each extra day adds query work.
        static let progressHistoryDays = 28
        /// Fewer reported days than this is too thin to call a starting pace.
        static let minimumBaselineDays = 3
    }
}
