import DeviceActivity
import _DeviceActivity_SwiftUI

/// Custom DeviceActivityReport contexts used by ScreenSpan
extension DeviceActivityReport.Context {
    /// Stats view: hero years number, donut chart, stat cards, reclaim preview
    static let stats = Self("stats")

    /// Chart view: life grid visualization
    static let chart = Self("chart")

    /// History view: weekly trends (premium-gated)
    static let history = Self("history")
}
