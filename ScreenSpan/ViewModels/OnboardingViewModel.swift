import Foundation
import Observation

/// Represents each step in the onboarding flow
enum OnboardingStep: Int, Equatable {
    case welcome = 0
    case ageInput = 1
    case permission = 2
    case lifeGridReveal = 3
    case comparisons = 4
    case goalSetting = 5
    case paywall = 6
}

/// ViewModel managing the onboarding flow for new users
@Observable
final class OnboardingViewModel {
    // MARK: - Properties

    var currentStep: OnboardingStep = .welcome
    var selectedAge: Int = 25
    var isPermissionGranted: Bool = false
    var currentDailyAvgHours: Double = 5.0
    var sliderTargetHours: Double = 5.0
    var selectedCategories: Set<UsageCategory> = []
    var projectionResult: ProjectionResult?
    var reclaimResult: ReclaimResult?

    // MARK: - Compatibility Properties

    /// Legacy optional API still used by the onboarding views.
    var userAge: Int? {
        get { selectedAge }
        set {
            guard let newValue else { return }
            selectedAge = newValue
        }
    }

    /// Legacy API for the user's current daily screen time estimate.
    var estimatedDailyScreenTime: Double {
        get { currentDailyAvgHours }
        set {
            currentDailyAvgHours = newValue
            if sliderTargetHours == 0 || sliderTargetHours > newValue {
                sliderTargetHours = newValue
            }
            calculateProjection()
            calculateReclaim()
        }
    }

    /// Legacy API for the selected daily goal.
    var selectedDailyLimit: Double {
        get { sliderTargetHours }
        set {
            sliderTargetHours = newValue
            calculateReclaim()
        }
    }

    /// Derived years projected to be spent on the phone at the current pace.
    var projectedYearsOnPhone: Double {
        get {
            projectionResult?.yearsOnPhone ?? 0
        }
        set {
            projectionResult = ProjectionResult(
                yearsOnPhone: newValue,
                monthsOnPhone: newValue * 12,
                daysOnPhone: newValue * 365,
                hoursOnPhone: newValue * SharedConstants.DefaultValues.hoursPerYear,
                percentOfWakingLife: projectionResult?.percentOfWakingLife ?? 0,
                dailyPhoneHours: projectionResult?.dailyPhoneHours ?? currentDailyAvgHours
            )
        }
    }

    /// Derived percentage of waking hours currently spent on the phone.
    var percentageOfWakingHours: Double {
        get {
            projectionResult?.percentOfWakingLife ?? 0
        }
        set {
            if let projectionResult {
                self.projectionResult = ProjectionResult(
                    yearsOnPhone: projectionResult.yearsOnPhone,
                    monthsOnPhone: projectionResult.monthsOnPhone,
                    daysOnPhone: projectionResult.daysOnPhone,
                    hoursOnPhone: projectionResult.hoursOnPhone,
                    percentOfWakingLife: newValue,
                    dailyPhoneHours: projectionResult.dailyPhoneHours
                )
            }
        }
    }

    /// Derived years reclaimed by reducing usage to the selected goal.
    var reclaimedYears: Double {
        get {
            reclaimResult?.yearsReclaimed ?? 0
        }
        set {
            reclaimResult = ReclaimResult(
                yearsReclaimed: newValue,
                monthsReclaimed: newValue * 12,
                goalYearsOnPhone: max(projectedYearsOnPhone - newValue, 0)
            )
        }
    }

    /// Legacy API for remaining lifetime years used by the onboarding visuals.
    var remainingYearsOfLife: Double {
        get {
            Double(SharedConstants.DefaultValues.targetAge - selectedAge)
        }
        set {
            let targetAge = Int(Double(selectedAge) + newValue.rounded())
            AppGroupManager.shared.targetAge = max(targetAge, selectedAge)
        }
    }

    /// Legacy API for the Screen Time permission state used by onboarding views.
    var screenTimePermissionGranted: Bool {
        get { isPermissionGranted }
        set { isPermissionGranted = newValue }
    }

    // MARK: - Initialization

    init() {
        self.sliderTargetHours = currentDailyAvgHours
    }

    // MARK: - Public Methods

    /// Advance to the next onboarding step
    func advance() {
        guard let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            return
        }
        currentStep = nextStep
    }

    /// Return to the previous onboarding step
    func goBack() {
        guard let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) else {
            return
        }
        currentStep = previousStep
    }

    /// Calculate the projection of waking life spent on phone.
    ///
    /// The result is kept in-memory (`projectionResult`) for the
    /// duration of the onboarding flow only. It is deliberately NOT
    /// persisted to the App Group: even though the input is a user
    /// self-estimate (which is legal to store), the persisted value
    /// previously became a back-channel the host used to reconstruct
    /// daily hours. Keeping this ephemeral guarantees no usage-shaped
    /// number ever crosses the extension/host boundary.
    func calculateProjection() {
        let targetAge = SharedConstants.DefaultValues.targetAge
        projectionResult = ProjectionCalculator.calculateProjectionFromDaily(
            currentAge: selectedAge,
            targetAge: targetAge,
            dailyHours: currentDailyAvgHours
        )
    }

    /// Calculate the reclaim benefit of reducing screen time
    func calculateReclaim() {
        guard let projection = projectionResult else {
            calculateProjection()
            guard projectionResult != nil else { return }
            calculateReclaim()
            return
        }

        let targetAge = SharedConstants.DefaultValues.targetAge
        let goalMinutes = sliderTargetHours * 60

        reclaimResult = ProjectionCalculator.calculateReclaim(
            currentProjection: projection,
            goalDailyMinutes: goalMinutes,
            currentAge: selectedAge,
            targetAge: targetAge
        )
    }

    /// Legacy API used by onboarding views when the slider changes.
    func calculateReclaim(newDailyHours: Double) {
        sliderTargetHours = newDailyHours
        calculateReclaim()
    }

    /// Complete onboarding and save all data
    func completeOnboarding() async {
        // Ensure calculations are done
        calculateProjection()
        calculateReclaim()

        let existingGoalMinutes = AppGroupManager.shared.screenTimeGoalMinutes
        let resolvedGoalMinutes = existingGoalMinutes > 0
            ? existingGoalMinutes
            : sliderTargetHours * 60

        // Save data to AppGroupManager
        AppGroupManager.shared.currentAge = selectedAge
        AppGroupManager.shared.targetAge = SharedConstants.DefaultValues.targetAge
        AppGroupManager.shared.screenTimeGoalMinutes = resolvedGoalMinutes

        // Save selected categories as strings
        let categoryStrings = selectedCategories.map { $0.rawValue }
        AppGroupManager.shared.selectedCategories = categoryStrings

        // Mark onboarding as complete
        AppGroupManager.shared.onboardingCompleted = true
    }
}
