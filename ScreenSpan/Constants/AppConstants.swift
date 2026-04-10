import Foundation

/// Application-wide constants for ScreenSpan
enum AppConstants {
    // MARK: - StoreKit Product IDs

    enum ProductID {
        static let monthlySubscription = "com.screenspan.subscription.monthly"
        static let annualSubscription = "com.screenspan.subscription.annual"
        static let lifeTimeAccess = "com.screenspan.lifetime"
    }

    // MARK: - Notification Identifiers

    enum NotificationID {
        static let dailyReminder = "com.screenspan.notification.daily-reminder"
        static let goalMilestone = "com.screenspan.notification.goal-milestone"
        static let weeklyReport = "com.screenspan.notification.weekly-report"
        static let limitApproaching = "com.screenspan.notification.limit-approaching"
        static let goalAchieved = "com.screenspan.notification.goal-achieved"
    }

    // MARK: - Background Task Identifiers

    static let backgroundTaskIdentifier = "com.screenspan.background.check-goals"

    // MARK: - Animation Durations

    enum AnimationDuration {
        static let short: TimeInterval = 0.2
        static let normal: TimeInterval = 0.3
        static let long: TimeInterval = 0.5
        static let extraLong: TimeInterval = 0.8
    }

    // MARK: - Comparison Card Data

    /// Comparison text for different projection magnitudes
    enum ComparisonTexts {
        static let yearsReclaimed: [String] = [
            "That's like adding a second childhood!",
            "Enough time to learn a new skill and master it.",
            "Time to travel around the world.",
            "Enough to write a novel and then some.",
            "That's a whole new chapter in your life.",
            "Years that could change everything."
        ]

        static let monthsReclaimed: [String] = [
            "A solid chunk of time back!",
            "Months of uninterrupted focus.",
            "Time to reset and recharge.",
            "A season of your life reclaimed.",
            "Enough for a major life project.",
            "Time worth celebrating."
        ]

        static let daysReclaimed: [String] = [
            "Every day counts!",
            "You're making progress.",
            "Keep the momentum going!",
            "Those days add up fast.",
            "You're on the right track.",
            "Small steps, big impact."
        ]
    }

    // MARK: - Default Values

    enum Defaults {
        static let screenTimeGoal = 120 // minutes
        static let dailyReminderHour = 20 // 8 PM
        static let dailyReminderMinute = 0
    }

    // MARK: - UI Constants

    enum UI {
        static let cornerRadius: CGFloat = 12
        static let smallCornerRadius: CGFloat = 8
        static let tinyCornerRadius: CGFloat = 4

        static let padding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let largePadding: CGFloat = 24

        static let spacing: CGFloat = 12
        static let smallSpacing: CGFloat = 4
        static let largeSpacing: CGFloat = 20
    }

    // MARK: - Onboarding

    enum Onboarding {
        static let minimumAge = 13
        static let defaultTargetAge = 80
        static let maxAge = 120
    }

    // MARK: - Analytics

    enum Analytics {
        static let appOpenEvent = "app_open"
        static let goalCreatedEvent = "goal_created"
        static let subscriptionPurchasedEvent = "subscription_purchased"
        static let settingsChangedEvent = "settings_changed"
    }
}
