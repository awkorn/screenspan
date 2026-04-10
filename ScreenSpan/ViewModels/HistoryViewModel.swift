import Foundation
import Observation

/// ViewModel for the History tab
/// Premium-gated feature: if not premium, isLocked = true
@Observable
final class HistoryViewModel {
    // MARK: - Properties

    var selectedPeriod: String = "3M"
    var weeklyAverages: [Double] = []
    var trendDelta: Double?
    var yearsReclaimed: Double?
    var isLocked: Bool = false
    var showPaywall: Bool = false

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Load history data from AppGroupManager
    func loadData() async {
        // Check premium access first
        await checkPremiumAccess()

        if isLocked {
            showPaywall = true
            return
        }

        // Load weekly averages
        loadWeeklyAverages()

        // Calculate trend
        calculateTrendDelta()

        // Load years reclaimed from stored data
        loadYearsReclaimed()
    }

    /// Check if user has premium subscription
    func checkPremiumAccess() async {
        let statusString = AppGroupManager.shared.subscriptionStatus
        let status = SubscriptionStatus(rawValue: statusString) ?? .free
        self.isLocked = !status.isPremium
        self.showPaywall = isLocked
    }

    /// Refresh history data
    func refresh() async {
        await loadData()
    }

    // MARK: - Private Methods

    /// Load weekly screen time averages (simulated from projection)
    private func loadWeeklyAverages() {
        // In production, this would pull from ScreenTime framework or server
        // For now, generate mock data based on stored daily goal
        let dailyAvgHours = AppGroupManager.shared.screenTimeGoalMinutes / 60
        let baseHours = dailyAvgHours > 0 ? dailyAvgHours : SharedConstants.DefaultValues.defaultDailyAvgHours

        var averages: [Double] = []
        for _ in 0..<12 {
            let variance = Double.random(in: -0.5...0.5)
            let weekAverage = baseHours + variance
            averages.append(max(0, weekAverage))
        }
        self.weeklyAverages = averages
    }

    /// Calculate trend delta (change from first week to most recent)
    private func calculateTrendDelta() {
        guard !weeklyAverages.isEmpty else { return }

        let firstWeek = weeklyAverages.first ?? 0
        let lastWeek = weeklyAverages.last ?? 0
        self.trendDelta = lastWeek - firstWeek
    }

    /// Load years reclaimed from stored data
    private func loadYearsReclaimed() {
        let projectedYears = AppGroupManager.shared.onboardingProjectedYears
        if projectedYears > 0 {
            self.yearsReclaimed = projectedYears
        }
    }
}
