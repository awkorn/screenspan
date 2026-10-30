import FamilyControls
import Foundation
import Observation
import SwiftUI

/// Each step in the onboarding flow, in order.
enum OnboardingStep: Int, CaseIterable, Equatable {
    case welcome
    case age
    case estimate
    case intentions
    case permission
    case reveal
    /// Without Screen Time access, a single daily goal instead of a plan.
    case goal
    /// With access: the apps that take the most, then where each starts.
    case planApps
    case planBaselines
    case plan
    /// ScreenSpan Pro, offered once the user has a plan or goal to protect.
    case paywall
}

/// Onboarding state. Everything stored here is user-entered (age, guess,
/// intentions, goal, the plan's apps and starting points) or navigation.
/// Measured activity never reaches the host:
/// the reveal is rendered by the report extension, or, in estimate mode, from
/// the user's own guess.
@Observable
final class OnboardingViewModel {
    var currentStep: OnboardingStep = .welcome
    var selectedAge: Int = 25
    var estimatedHours: Double = 3
    var intentions: Set<TimeIntention> = []
    var goalHours: Double = 2
    /// The visible reveal panel, 0..<OnboardingRevealPanels.panelCount.
    var revealPanel = 0
    /// True when Screen Time access was declined or the report never appeared;
    /// the reveal then uses the user's estimate and says so.
    var usesEstimate = false
    /// True once Screen Time access is allowed. Blocking needs it, so only
    /// then is there a plan to build; otherwise the user sets a daily goal.
    var buildsPlan = false
    /// The apps picked for the plan, one item per app.
    var planItems: [PlanDraftItem] = PlanDraftItem.load()

    private var steps: [OnboardingStep] {
        OnboardingStep.allCases.filter { step in
            switch step {
            case .goal: !buildsPlan
            case .planApps, .planBaselines: buildsPlan
            default: true
            }
        }
    }

    var progress: Double {
        let steps = steps
        return Double(steps.firstIndex(of: currentStep) ?? 0) / Double(steps.count - 1)
    }

    func advance() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentStep == .reveal, revealPanel < OnboardingRevealPanels.panelCount - 1 {
                revealPanel += 1
            } else if let index = steps.firstIndex(of: currentStep), index + 1 < steps.count {
                currentStep = steps[index + 1]
            }
        }
    }

    func goBack() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if currentStep == .reveal, revealPanel > 0 {
                revealPanel -= 1
            } else if let index = steps.firstIndex(of: currentStep), index > 0 {
                currentStep = steps[index - 1]
                if currentStep == .reveal { revealPanel = OnboardingRevealPanels.panelCount - 1 }
            }
        }
    }

    // MARK: - Plan

    /// Every picked app has a starting point the plan can step down from.
    var planIsReady: Bool {
        !planItems.isEmpty && planItems.allSatisfy { $0.course(start: Date()) != nil }
    }

    func setPlanSelection(_ selection: FamilyActivitySelection) {
        planItems = PlanDraftItem.items(from: selection, keeping: planItems)
        savePlanDraft()
    }

    func savePlanDraft() {
        PlanDraftItem.save(planItems)
    }

    /// "Start your plan. Get 3.1 years back." Nil without a plan.
    var paywallHeadline: String? {
        guard buildsPlan else { return nil }
        let courses = planItems.compactMap { $0.course(start: Date()) }
        guard !courses.isEmpty else { return nil }
        let years = courses.regainedAtTarget(currentAge: selectedAge, targetAge: SharedConstants.DefaultValues.targetAge).yearsReclaimed
        return "Start your plan. Get \(PlanFormat.years(years)) back."
    }

    /// Starts the plan's limits at the next midnight and clears the draft.
    @MainActor
    func startPlan(with blocking: BlockingService) {
        for item in planItems {
            guard let baseline = item.baselineMinutes else { continue }
            blocking.addToPlan(item.selection, baselineMinutes: baseline, targetMinutes: item.targetMinutes)
        }
        planItems = []
        PlanDraftItem.save([])
    }

    func saveAge(_ age: Int) {
        selectedAge = age
        AppGroupManager.shared.currentAge = age
        AppGroupManager.shared.targetAge = SharedConstants.DefaultValues.targetAge
    }

    func saveEstimate() {
        AppGroupManager.shared.estimatedDailyMinutes = estimatedHours * 60
    }

    func saveIntentions() {
        AppGroupManager.shared.timeIntentions = TimeIntention.allCases.filter(intentions.contains)
    }

    func saveGoal() {
        AppGroupManager.shared.screenTimeGoalMinutes = goalHours * 60
    }

    /// The reveal built from the user's own estimate, for estimate mode.
    var estimateRevealData: RevealData {
        RevealData(dailyHours: estimatedHours, isMeasured: false, guessHours: estimatedHours,
                   currentAge: selectedAge, targetAge: SharedConstants.DefaultValues.targetAge,
                   intentions: TimeIntention.resolve(TimeIntention.allCases.filter(intentions.contains).map(\.rawValue)))
    }

    /// Save everything and finish. Progress compares days after today with
    /// the week before it; repeating onboarding keeps the original start.
    func completeOnboarding() async {
        saveAge(selectedAge)
        saveEstimate()
        saveIntentions()
        saveGoal()
        AppGroupManager.shared.ensureTrackingStartDate()
        AppGroupManager.shared.onboardingCompleted = true
    }
}
