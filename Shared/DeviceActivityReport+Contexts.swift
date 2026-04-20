import DeviceActivity
import _DeviceActivity_SwiftUI

/// Custom `DeviceActivityReport.Context` identifiers shared between the
/// ScreenSpan host app and the ScreenSpanReport extension.
///
/// These must be declared in a file that is a member of *both* targets
/// so the host can construct `DeviceActivityReport(.stats, filter:)`
/// and the extension can register `DeviceActivityReportScene`s with
/// matching context values. The identifier strings (`"stats"`,
/// `"chart"`, `"history"`) are the contract that ties the two sides
/// together — do not change them without updating both ends.
extension DeviceActivityReport.Context {
    /// Stats view: hero years number, donut chart, stat cards, reclaim preview.
    static let stats = Self("stats")

    /// Chart view: life grid visualization.
    static let chart = Self("chart")

    /// History view: weekly trends (premium-gated).
    static let history = Self("history")

    /// Onboarding goal-setting module rendered by the report extension.
    static let onboardingGoal = Self("onboardingGoal")
}
