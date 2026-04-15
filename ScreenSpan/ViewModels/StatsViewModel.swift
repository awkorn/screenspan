import Foundation
import Observation

/// ViewModel for the Stats tab
/// In production, rendering happens in the extension. This VM is for coordination and fallback.
@Observable
final class StatsViewModel {
    // MARK: - Properties

    var projection: ProjectionResult?
    var isLoading: Bool = false

    // MARK: - Public Methods

    /// Load stats data from AppGroupManager
    func loadData() {
        isLoading = true
        defer { isLoading = false }

        let manager = AppGroupManager.shared

        projection = resolveProjection(using: manager)
    }

    /// Refresh stats from the latest available data
    func refresh() {
        loadData()
    }

    // MARK: - Private Methods

    private func resolveProjection(using manager: AppGroupManager) -> ProjectionResult? {
        let currentAge = manager.currentAge
        let targetAge = max(manager.targetAge, currentAge)

        if currentAge > 0, targetAge > currentAge {
            let dailyHours = resolveAverageDailyHours(
                currentAge: currentAge,
                targetAge: targetAge,
                manager: manager
            )

            if dailyHours > 0 {
                return ProjectionCalculator.calculateProjectionFromDaily(
                    currentAge: currentAge,
                    targetAge: targetAge,
                    dailyHours: dailyHours
                )
            }
        }

        let storedYears = manager.onboardingProjectedYears
        let storedPercent = manager.onboardingWakingPercent
        guard storedYears > 0 || storedPercent > 0 else { return nil }

        let wakeHoursPerDay = SharedConstants.DefaultValues.wakeHoursPerDay
        let resolvedDailyHours = storedPercent > 0
            ? (storedPercent / 100) * wakeHoursPerDay
            : 0

        return ProjectionResult(
            yearsOnPhone: storedYears,
            monthsOnPhone: storedYears * 12,
            daysOnPhone: storedYears * 365,
            hoursOnPhone: storedYears * SharedConstants.DefaultValues.hoursPerYear,
            percentOfWakingLife: storedPercent,
            dailyPhoneHours: resolvedDailyHours
        )
    }

    private func resolveAverageDailyHours(
        currentAge: Int,
        targetAge: Int,
        manager: AppGroupManager
    ) -> Double {
        let onboardingWakingPercent = manager.onboardingWakingPercent
        if onboardingWakingPercent > 0 {
            return (onboardingWakingPercent / 100) * SharedConstants.DefaultValues.wakeHoursPerDay
        }

        let projectedYears = manager.onboardingProjectedYears
        if projectedYears > 0, targetAge > currentAge {
            let remainingYears = Double(targetAge - currentAge)
            let derivedHours = (projectedYears * SharedConstants.DefaultValues.hoursPerYear) / (remainingYears * 365)
            if derivedHours > 0 {
                return derivedHours
            }
        }

        let storedGoalHours = manager.screenTimeGoalMinutes / 60
        if storedGoalHours > 0 {
            return storedGoalHours
        }

        return SharedConstants.DefaultValues.defaultDailyAvgHours
    }
}
