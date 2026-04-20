import Foundation
import Observation

/// ViewModel for the Chart (Life Grid) tab.
///
/// PRIVACY MODEL
/// -------------
/// The life grid, goal slider reference values, and any usage-derived
/// rendering are produced by the `ScreenSpanReport` extension — see
/// `ChartTabView`. The host app is not permitted to derive daily screen
/// time hours from the Screen Time API, from onboarding self-estimates,
/// or from any other channel, and must not reconstruct life-grid
/// projections in-process.
///
/// This ViewModel is intentionally left empty. The previous
/// implementation read `onboardingWakingPercent` /
/// `onboardingProjectedYears` / `screenTimeGoalMinutes` from the App
/// Group and reverse-engineered average daily hours; that logic was a
/// compliance risk and has been removed. Do not reintroduce it.
@Observable
final class ChartViewModel {
    init() {}
}
