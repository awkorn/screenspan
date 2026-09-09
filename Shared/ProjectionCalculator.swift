import Foundation

/// Calculates screen time projections based on DeviceActivity data and age
struct ProjectionCalculator {

    private static func boundedHours(_ hours: Double) -> Double {
        hours.isFinite ? min(max(hours, 0), 24) : 0
    }

    // MARK: - Static Methods

    /// Calculate projection of phone usage through target age
    /// - Parameters:
    ///   - currentAge: User's current age in years
    ///   - targetAge: Target age (default 80)
    ///   - weeklyAvgMinutes: Average weekly screen time in minutes (from DeviceActivity)
    /// - Returns: ProjectionResult with projected phone usage metrics
    static func calculateProjection(
        currentAge: Int,
        targetAge: Int,
        weeklyAvgMinutes: Double
    ) -> ProjectionResult {
        // Constants
        let wakeHoursPerDay = SharedConstants.DefaultValues.wakeHoursPerDay
        let hoursPerYear = SharedConstants.DefaultValues.hoursPerYear

        // Derived calculations
        let yearsRemaining = Double(max(targetAge - currentAge, 0))
        let dailyPhoneHours = boundedHours(weeklyAvgMinutes / 7 / 60)
        let phoneHoursRemaining = yearsRemaining * 365 * dailyPhoneHours
        let yearsOnPhone = phoneHoursRemaining / hoursPerYear

        // Display values
        let percentOfWakingLife = min(dailyPhoneHours / wakeHoursPerDay, 1) * 100
        let monthsOnPhone = yearsOnPhone * 12
        let daysOnPhone = yearsOnPhone * 365
        let hoursOnPhone = phoneHoursRemaining

        return ProjectionResult(
            yearsOnPhone: yearsOnPhone,
            monthsOnPhone: monthsOnPhone,
            daysOnPhone: daysOnPhone,
            hoursOnPhone: hoursOnPhone,
            percentOfWakingLife: percentOfWakingLife,
            dailyPhoneHours: dailyPhoneHours
        )
    }

    /// Convenience method to calculate projection from daily hours
    /// - Parameters:
    ///   - currentAge: User's current age in years
    ///   - targetAge: Target age (default 80)
    ///   - dailyHours: Daily screen time in hours
    /// - Returns: ProjectionResult with projected phone usage metrics
    static func calculateProjectionFromDaily(
        currentAge: Int,
        targetAge: Int,
        dailyHours: Double
    ) -> ProjectionResult {
        let weeklyMinutes = dailyHours * 60 * 7
        return calculateProjection(
            currentAge: currentAge,
            targetAge: targetAge,
            weeklyAvgMinutes: weeklyMinutes
        )
    }

    /// Calculate years reclaimed by achieving a screen time goal
    /// - Parameters:
    ///   - currentProjection: Current projection without goal changes
    ///   - goalDailyMinutes: Target daily screen time in minutes
    ///   - currentAge: User's current age in years
    ///   - targetAge: Target age (default 80)
    /// - Returns: ReclaimResult with reclaimed time metrics
    static func calculateReclaim(
        currentProjection: ProjectionResult,
        goalDailyMinutes: Double,
        currentAge: Int,
        targetAge: Int
    ) -> ReclaimResult {
        let hoursPerYear = SharedConstants.DefaultValues.hoursPerYear

        // Goal calculations
        let goalDailyHours = boundedHours(goalDailyMinutes / 60)
        let yearsRemaining = Double(max(targetAge - currentAge, 0))
        let goalPhoneHoursRemaining = yearsRemaining * 365 * goalDailyHours
        let goalYearsOnPhone = goalPhoneHoursRemaining / hoursPerYear
        let yearsReclaimed = max(currentProjection.yearsOnPhone - goalYearsOnPhone, 0)
        let monthsReclaimed = yearsReclaimed * 12

        return ReclaimResult(
            yearsReclaimed: yearsReclaimed,
            monthsReclaimed: monthsReclaimed,
            goalYearsOnPhone: goalYearsOnPhone
        )
    }

    /// Calculate life grid data for visualization
    /// - Parameters:
    ///   - currentAge: User's current age in years
    ///   - targetAge: Target age (default 80)
    ///   - monthsOnPhone: Projected months on phone
    /// - Returns: LifeGridData for visual representation
    static func calculateLifeGrid(
        currentAge: Int,
        targetAge: Int,
        monthsOnPhone: Double
    ) -> LifeGridData {
        let totalMonths = min(max(targetAge, 0), 150) * 12
        let monthsLived = min(max(currentAge, 0), totalMonths / 12) * 12
        let safePhoneMonths = monthsOnPhone.isFinite ? monthsOnPhone : 0
        let phoneMonthsRounded = Int(min(max(safePhoneMonths.rounded(), 0), Double(totalMonths - monthsLived)))
        let freeMonths = totalMonths - monthsLived - phoneMonthsRounded

        return LifeGridData(
            totalMonths: totalMonths,
            monthsLived: monthsLived,
            phoneMonths: phoneMonthsRounded,
            freeMonths: freeMonths
        )
    }
}
