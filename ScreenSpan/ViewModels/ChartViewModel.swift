import Foundation
import Observation

/// ViewModel for the Chart (Life Grid) tab
@Observable
final class ChartViewModel {
    // MARK: - Properties

    var lifeGridData: LifeGridData?
    var isLoading: Bool = false

    var gridData: LifeGridData {
        if let lifeGridData {
            return lifeGridData
        }

        return LifeGridData.mockData()
    }

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Load chart data from AppGroupManager
    func loadData() {
        isLoading = true
        defer { isLoading = false }

        let currentAge = AppGroupManager.shared.currentAge
        let targetAge = AppGroupManager.shared.targetAge
        let dailyAvgHours = AppGroupManager.shared.screenTimeGoalMinutes / 60

        let projection = ProjectionCalculator.calculateProjectionFromDaily(
            currentAge: currentAge,
            targetAge: targetAge,
            dailyHours: dailyAvgHours > 0 ? dailyAvgHours : SharedConstants.DefaultValues.defaultDailyAvgHours
        )

        let gridData = ProjectionCalculator.calculateLifeGrid(
            currentAge: currentAge,
            targetAge: targetAge,
            monthsOnPhone: projection.monthsOnPhone
        )

        self.lifeGridData = gridData
    }

    /// Refresh chart data
    func refresh() {
        loadData()
    }
}
