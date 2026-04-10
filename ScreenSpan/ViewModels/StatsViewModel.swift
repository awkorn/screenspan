import Foundation
import Observation

/// ViewModel for the Stats tab
/// In production, rendering happens in the extension. This VM is for coordination and fallback.
@Observable
final class StatsViewModel {
    // MARK: - Properties

    var projection: ProjectionResult?
    var reclaimPreview: ReclaimResult?
    var hasGoal: Bool = false
    var isLoading: Bool = false

    // MARK: - Public Methods

    /// Load stats data from AppGroupManager
    func loadData() {
        isLoading = true
        defer { isLoading = false }

        let manager = AppGroupManager.shared

        let currentAge = manager.currentAge
        let targetAge = manager.targetAge
        let goalMinutes = manager.screenTimeGoalMinutes

        // Check if we have enough data to calculate
        guard currentAge > 0 else { return }

        // For now, use the goal or a default to show projections
        // In production, actual weekly avg comes from the DeviceActivity extension
        let dailyHours = SharedConstants.DefaultValues.defaultDailyAvgHours
        let weeklyMinutes = dailyHours * 60 * 7

        projection = ProjectionCalculator.calculateProjection(
            currentAge: currentAge,
            targetAge: targetAge,
            weeklyAvgMinutes: weeklyMinutes
        )

        // Calculate reclaim preview if a goal is set
        hasGoal = goalMinutes > 0
        if hasGoal, let projection = projection {
            reclaimPreview = ProjectionCalculator.calculateReclaim(
                currentProjection: projection,
                goalDailyMinutes: goalMinutes,
                currentAge: currentAge,
                targetAge: targetAge
            )
        }
    }

    /// Refresh stats from the latest available data
    func refresh() {
        loadData()
    }
}
