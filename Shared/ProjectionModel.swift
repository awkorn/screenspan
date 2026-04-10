import Foundation

struct ProjectionResult: Codable, Sendable, Equatable {
    let yearsOnPhone: Double
    let monthsOnPhone: Double
    let daysOnPhone: Double
    let hoursOnPhone: Double
    let percentOfWakingLife: Double
    let dailyPhoneHours: Double

    enum CodingKeys: String, CodingKey {
        case yearsOnPhone
        case monthsOnPhone
        case daysOnPhone
        case hoursOnPhone
        case percentOfWakingLife
        case dailyPhoneHours
    }

    init(
        yearsOnPhone: Double,
        monthsOnPhone: Double,
        daysOnPhone: Double,
        hoursOnPhone: Double,
        percentOfWakingLife: Double,
        dailyPhoneHours: Double
    ) {
        self.yearsOnPhone = yearsOnPhone
        self.monthsOnPhone = monthsOnPhone
        self.daysOnPhone = daysOnPhone
        self.hoursOnPhone = hoursOnPhone
        self.percentOfWakingLife = percentOfWakingLife
        self.dailyPhoneHours = dailyPhoneHours
    }
}

struct ReclaimResult: Codable, Sendable, Equatable {
    let yearsReclaimed: Double
    let monthsReclaimed: Double
    let goalYearsOnPhone: Double

    enum CodingKeys: String, CodingKey {
        case yearsReclaimed
        case monthsReclaimed
        case goalYearsOnPhone
    }

    init(
        yearsReclaimed: Double,
        monthsReclaimed: Double,
        goalYearsOnPhone: Double
    ) {
        self.yearsReclaimed = yearsReclaimed
        self.monthsReclaimed = monthsReclaimed
        self.goalYearsOnPhone = goalYearsOnPhone
    }
}

struct LifeGridData: Codable, Sendable, Equatable {
    let totalMonths: Int
    let monthsLived: Int
    let phoneMonths: Int
    let freeMonths: Int

    enum CodingKeys: String, CodingKey {
        case totalMonths
        case monthsLived
        case phoneMonths
        case freeMonths
    }

    init(
        totalMonths: Int,
        monthsLived: Int,
        phoneMonths: Int,
        freeMonths: Int
    ) {
        self.totalMonths = totalMonths
        self.monthsLived = monthsLived
        self.phoneMonths = phoneMonths
        self.freeMonths = freeMonths
    }
}
