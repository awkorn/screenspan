import Foundation
import SwiftUI

/// Service for managing user goals and checking milestones
@MainActor
class GoalService: ObservableObject {
    @Published var currentGoal: UserGoal?
    @Published var timeInterval: TimeInterval = TimeInterval(AppConstants.Defaults.screenTimeGoal * 60)

    /// Check goals and send notifications if milestones reached
    func checkAndNotifyGoals() {
        // Check if user has reached any milestones
        // This would be called from background tasks
    }

    /// Update the screen time goal
    func updateGoal(_ minutes: Double, categories: [UsageCategory] = []) {
        let goal = UserGoal(
            dailyMinutesGoal: minutes,
            selectedCategories: categories,
            isActive: true
        )
        currentGoal = goal
        timeInterval = TimeInterval(minutes * 60)

        // Persist to AppGroupManager
        AppGroupManager.shared.screenTimeGoalMinutes = minutes
        AppGroupManager.shared.selectedCategories = categories.map { $0.rawValue }
    }

    /// Get remaining time for today's goal
    func getRemainingTime() -> TimeInterval {
        // Calculate remaining time based on today's usage
        return timeInterval
    }
}
