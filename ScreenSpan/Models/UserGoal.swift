import Foundation

struct UserGoal: Codable, Sendable, Equatable {
    let dailyMinutesGoal: Double
    let selectedCategories: [UsageCategory]
    let isActive: Bool

    var dailyHoursGoal: Double {
        dailyMinutesGoal / 60
    }

    enum CodingKeys: String, CodingKey {
        case dailyMinutesGoal
        case selectedCategories
        case isActive
    }

    init(
        dailyMinutesGoal: Double,
        selectedCategories: [UsageCategory],
        isActive: Bool
    ) {
        self.dailyMinutesGoal = dailyMinutesGoal
        self.selectedCategories = selectedCategories
        self.isActive = isActive
    }
}
