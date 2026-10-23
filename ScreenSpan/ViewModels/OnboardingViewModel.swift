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
    case goal
    case plan
    /// ScreenSpan Pro, offered once the user has a goal to protect.
    case paywall
}

/// Onboarding state. Everything stored here is user-entered (age, guess,
/// intentions, goal) or navigation. Measured activity never reaches the host:
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

    var progress: Double {
        Double(currentStep.rawValue) / Double(OnboardingStep.allCases.count - 1)
    }

    func advance() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentStep == .reveal, revealPanel < OnboardingRevealPanels.panelCount - 1 {
                revealPanel += 1
            } else if let next = OnboardingStep(rawValue: currentStep.rawValue + 1) {
                currentStep = next
            }
        }
    }

    func goBack() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if currentStep == .reveal, revealPanel > 0 {
                revealPanel -= 1
            } else if currentStep == .goal {
                currentStep = .reveal
                revealPanel = OnboardingRevealPanels.panelCount - 1
            } else if let previous = OnboardingStep(rawValue: currentStep.rawValue - 1) {
                currentStep = previous
            }
        }
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
