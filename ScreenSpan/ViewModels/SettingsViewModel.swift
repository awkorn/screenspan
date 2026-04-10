import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

/// ViewModel for the Settings tab
/// Manages user profile, goals, and subscription
@Observable
final class SettingsViewModel {
    // MARK: - Properties

    var currentAge: Int = 25 {
        didSet {
            Task {
                await saveProfile()
            }
        }
    }

    var targetAge: Int = SharedConstants.DefaultValues.targetAge {
        didSet {
            Task {
                await saveProfile()
            }
        }
    }

    var screenTimeGoalMinutes: Double = 300 {
        didSet {
            Task {
                await saveGoal()
            }
        }
    }

    var selectedCategories: [UsageCategory] = [] {
        didSet {
            Task {
                await saveGoal()
            }
        }
    }

    var isBlockingEnabled: Bool = false {
        didSet {
            Task {
                await toggleBlocking(isBlockingEnabled)
            }
        }
    }

    var subscriptionStatus: SubscriptionStatus = .free
    var isLoading: Bool = false

    // MARK: - Initialization

    init() {
        loadSettings()
    }

    // MARK: - Public Methods

    /// Load all settings from AppGroupManager
    func loadSettings() {
        isLoading = true
        defer { isLoading = false }

        // Load current age
        let savedAge = AppGroupManager.shared.currentAge
        currentAge = savedAge > 0 ? savedAge : 25

        // Load target age
        targetAge = AppGroupManager.shared.targetAge

        // Load screen time goal
        let savedGoal = AppGroupManager.shared.screenTimeGoalMinutes
        screenTimeGoalMinutes = savedGoal > 0 ? savedGoal : 300

        // Load selected categories
        let categoryStrings = AppGroupManager.shared.selectedCategories
        selectedCategories = categoryStrings.compactMap { UsageCategory(rawValue: $0) }

        // Load subscription status
        let statusString = AppGroupManager.shared.subscriptionStatus
        subscriptionStatus = SubscriptionStatus(rawValue: statusString) ?? .free
    }

    /// Refresh subscription status
    func refreshSubscriptionStatus() async {
        let statusString = AppGroupManager.shared.subscriptionStatus
        subscriptionStatus = SubscriptionStatus(rawValue: statusString) ?? .free
    }

    /// Save user profile (age)
    @MainActor
    func saveProfile() async {
        AppGroupManager.shared.currentAge = currentAge
        AppGroupManager.shared.targetAge = targetAge
    }

    /// Save screen time goal
    @MainActor
    func saveGoal() async {
        AppGroupManager.shared.screenTimeGoalMinutes = screenTimeGoalMinutes

        // Save selected categories as strings
        let categoryStrings = selectedCategories.map { $0.rawValue }
        AppGroupManager.shared.selectedCategories = categoryStrings
    }

    /// Toggle app blocking feature
    func toggleBlocking(_ enabled: Bool) async {
        // In production, this would enable/disable the blocking extension
    }

    /// Delete all user data (permanent)
    func deleteAllData() async {
        await MainActor.run {
            self.currentAge = 25
            self.screenTimeGoalMinutes = 300
            self.selectedCategories = []
            self.isBlockingEnabled = false

            AppGroupManager.shared.currentAge = 0
            AppGroupManager.shared.targetAge = SharedConstants.DefaultValues.targetAge
            AppGroupManager.shared.screenTimeGoalMinutes = 0
            AppGroupManager.shared.selectedCategories = []
            AppGroupManager.shared.onboardingCompleted = false
        }
    }

    /// Open the App Store subscription management page.
    @MainActor
    func openManageSubscription() {
#if canImport(UIKit)
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else {
            return
        }
        UIApplication.shared.open(url)
#endif
    }

    /// Restore previously purchased subscriptions.
    @MainActor
    func restorePurchases() {
        Task {
            await refreshSubscriptionStatus()
        }
    }
}
