import Foundation

/// Manager for accessing shared UserDefaults via app groups
final class AppGroupManager {
    static let shared = AppGroupManager()

    private let userDefaults: UserDefaults

    private init() {
        self.userDefaults = UserDefaults(suiteName: SharedConstants.appGroupIdentifier)!
    }

    // MARK: - Typed Properties with Getters and Setters

    /// User's current age
    var currentAge: Int {
        get {
            userDefaults.integer(forKey: SharedConstants.UserDefaultsKey.currentAge.rawValue)
        }
        set {
            userDefaults.set(newValue, forKey: SharedConstants.UserDefaultsKey.currentAge.rawValue)
        }
    }

    /// User's target age (default 80)
    var targetAge: Int {
        get {
            let stored = userDefaults.integer(forKey: SharedConstants.UserDefaultsKey.targetAge.rawValue)
            return stored > 0 ? stored : SharedConstants.DefaultValues.targetAge
        }
        set {
            userDefaults.set(newValue, forKey: SharedConstants.UserDefaultsKey.targetAge.rawValue)
        }
    }

    /// Daily screen time goal in minutes
    var screenTimeGoalMinutes: Double {
        get {
            let stored = userDefaults.double(forKey: SharedConstants.UserDefaultsKey.screenTimeGoalMinutes.rawValue)
            return stored > 0 ? stored : 0
        }
        set {
            userDefaults.set(newValue, forKey: SharedConstants.UserDefaultsKey.screenTimeGoalMinutes.rawValue)
        }
    }

    /// Projected years on phone from onboarding
    var onboardingProjectedYears: Double {
        get {
            userDefaults.double(forKey: SharedConstants.UserDefaultsKey.onboardingProjectedYears.rawValue)
        }
        set {
            userDefaults.set(newValue, forKey: SharedConstants.UserDefaultsKey.onboardingProjectedYears.rawValue)
        }
    }


    /// Percentage of waking life spent on the phone from onboarding
    var onboardingWakingPercent: Double {
        get {
            userDefaults.double(forKey: SharedConstants.UserDefaultsKey.onboardingWakingPercent.rawValue)
        }
        set {
            userDefaults.set(newValue, forKey: SharedConstants.UserDefaultsKey.onboardingWakingPercent.rawValue)
        }
    }

    /// Selected DeviceActivity categories
    var selectedCategories: [String] {
        get {
            userDefaults.array(forKey: SharedConstants.UserDefaultsKey.selectedCategories.rawValue) as? [String] ?? []
        }
        set {
            userDefaults.set(newValue, forKey: SharedConstants.UserDefaultsKey.selectedCategories.rawValue)
        }
    }

    /// Subscription status
    var subscriptionStatus: String {
        get {
            userDefaults.string(forKey: SharedConstants.UserDefaultsKey.subscriptionStatus.rawValue) ?? ""
        }
        set {
            userDefaults.set(newValue, forKey: SharedConstants.UserDefaultsKey.subscriptionStatus.rawValue)
        }
    }

    /// Whether onboarding is completed
    var onboardingCompleted: Bool {
        get {
            userDefaults.bool(forKey: SharedConstants.UserDefaultsKey.onboardingCompleted.rawValue)
        }
        set {
            userDefaults.set(newValue, forKey: SharedConstants.UserDefaultsKey.onboardingCompleted.rawValue)
        }
    }
}
