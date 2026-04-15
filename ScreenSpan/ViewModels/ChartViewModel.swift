import Foundation
import Observation

/// ViewModel for the Chart (Life Grid) tab
@Observable
final class ChartViewModel {
    // MARK: - Properties

    var averageGridData: LifeGridData = .mockData(months: 960)
    var goalGridData: LifeGridData = .mockData(months: 960)
    var averageDailyHours: Double = SharedConstants.DefaultValues.defaultDailyAvgHours
    var fixedGoalHours: Double = SharedConstants.DefaultValues.defaultDailyAvgHours
    var selectedGoalHours: Double = SharedConstants.DefaultValues.defaultDailyAvgHours
    var isLoading: Bool = false

    // MARK: - Initialization

    init() {
        loadData()
    }

    var maxSliderHours: Double {
        max(averageDailyHours, 0.1)
    }

    var fixedGoalProgress: Double {
        guard maxSliderHours > 0 else { return 0 }
        return min(max(fixedGoalHours / maxSliderHours, 0), 1)
    }

    // MARK: - Public Methods

    /// Load chart data from AppGroupManager
    func loadData() {
        isLoading = true
        defer { isLoading = false }

        let currentAge = max(AppGroupManager.shared.currentAge, 1)
        let targetAge = max(AppGroupManager.shared.targetAge, currentAge)
        let resolvedAverageHours = resolveAverageDailyHours(currentAge: currentAge, targetAge: targetAge)
        let storedGoalHours = AppGroupManager.shared.screenTimeGoalMinutes > 0
            ? AppGroupManager.shared.screenTimeGoalMinutes / 60
            : resolvedAverageHours

        averageDailyHours = resolvedAverageHours
        fixedGoalHours = min(max(storedGoalHours, 0), maxSliderHours)
        selectedGoalHours = fixedGoalHours

        averageGridData = buildGridData(
            currentAge: currentAge,
            targetAge: targetAge,
            dailyHours: averageDailyHours
        )

        goalGridData = buildGridData(
            currentAge: currentAge,
            targetAge: targetAge,
            dailyHours: selectedGoalHours
        )
    }

    func updateGoalHours(_ hours: Double) {
        let clampedHours = min(max(hours, 0), maxSliderHours)
        guard clampedHours != selectedGoalHours else { return }

        selectedGoalHours = clampedHours

        let currentAge = max(AppGroupManager.shared.currentAge, 1)
        let targetAge = max(AppGroupManager.shared.targetAge, currentAge)

        goalGridData = buildGridData(
            currentAge: currentAge,
            targetAge: targetAge,
            dailyHours: selectedGoalHours
        )
    }

    /// Refresh chart data
    func refresh() {
        loadData()
    }

    // MARK: - Private Methods

    private func resolveAverageDailyHours(currentAge: Int, targetAge: Int) -> Double {
        let onboardingWakingPercent = AppGroupManager.shared.onboardingWakingPercent
        if onboardingWakingPercent > 0 {
            return (onboardingWakingPercent / 100) * SharedConstants.DefaultValues.wakeHoursPerDay
        }

        let projectedYears = AppGroupManager.shared.onboardingProjectedYears
        if projectedYears > 0, targetAge > currentAge {
            let remainingYears = Double(targetAge - currentAge)
            let derivedHours = (projectedYears * SharedConstants.DefaultValues.hoursPerYear) / (remainingYears * 365)
            if derivedHours > 0 {
                return derivedHours
            }
        }

        let storedGoalHours = AppGroupManager.shared.screenTimeGoalMinutes / 60
        if storedGoalHours > 0 {
            return storedGoalHours
        }

        return SharedConstants.DefaultValues.defaultDailyAvgHours
    }

    private func buildGridData(currentAge: Int, targetAge: Int, dailyHours: Double) -> LifeGridData {
        let projection = ProjectionCalculator.calculateProjectionFromDaily(
            currentAge: currentAge,
            targetAge: targetAge,
            dailyHours: dailyHours
        )

        return ProjectionCalculator.calculateLifeGrid(
            currentAge: currentAge,
            targetAge: targetAge,
            monthsOnPhone: projection.monthsOnPhone
        )
    }
}
