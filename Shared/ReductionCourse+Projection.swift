import Foundation

extension ReductionCourse {
    /// Lifetime time back from holding `limitMinutes` instead of the starting
    /// amount, from now until the planning age.
    func regained(atLimit limitMinutes: Int, currentAge: Int, targetAge: Int) -> ReclaimResult {
        ProjectionCalculator.calculateRegained(
            startingDailyHours: Double(baselineMinutes) / 60,
            currentDailyHours: Double(limitMinutes) / 60,
            currentAge: currentAge,
            targetAge: targetAge
        )
    }
}

extension Collection where Element == ReductionCourse {
    /// Lifetime time back across the plan at today's limits.
    func regained(currentAge: Int, targetAge: Int) -> ReclaimResult {
        Self.regained(minutesBack: minutesBack, currentAge: currentAge, targetAge: targetAge)
    }

    /// Lifetime time back across the plan once every app reaches its target.
    func regainedAtTarget(currentAge: Int, targetAge: Int) -> ReclaimResult {
        Self.regained(minutesBack: minutesBackAtTarget, currentAge: currentAge, targetAge: targetAge)
    }

    private static func regained(minutesBack: Int, currentAge: Int, targetAge: Int) -> ReclaimResult {
        ProjectionCalculator.calculateRegained(
            startingDailyHours: Double(minutesBack) / 60,
            currentDailyHours: 0,
            currentAge: currentAge,
            targetAge: targetAge
        )
    }
}
