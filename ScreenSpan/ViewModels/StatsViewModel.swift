import Foundation
import Observation

/// ViewModel for the Stats tab.
///
/// PRIVACY MODEL
/// -------------
/// All screen time figures on the Stats tab are rendered by the
/// `ScreenSpanReport` extension — see `StatsTabView`. The host app is
/// not permitted to derive, infer, or reverse-engineer daily screen
/// time hours from any source (not from the Screen Time API, not from
/// onboarding self-estimates stored in the App Group, and not from
/// saved goals).
///
/// Consequently, this ViewModel no longer performs any usage
/// calculation. It is kept as a minimal, empty observable so existing
/// Xcode project membership remains valid. If a future Stats-tab
/// feature needs host-side state (e.g. a user-chosen time-range
/// selector), add it here — but never add anything that reads or
/// computes numeric screen time usage.
@Observable
final class StatsViewModel {
    init() {}
}
