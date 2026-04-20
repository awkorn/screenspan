import Foundation
import Observation

/// ViewModel for the History tab.
///
/// PRIVACY MODEL
/// -------------
/// Weekly averages, trend deltas, and life-reclaimed values on the
/// History tab are Screen Time-derived and are therefore rendered by
/// the `ScreenSpanReport` extension — see `HistoryTabView`. The host
/// app must not compute, synthesize, or persist these values.
///
/// The previous implementation generated mock weekly averages locally
/// with a comment noting that production would "pull from ScreenTime
/// framework or server" — both of those paths are hard App Review
/// rejections. That logic has been removed.
///
/// What remains here is only the premium-gating state, which is driven
/// by `subscriptionStatus` (a non-usage value that the host is allowed
/// to read from the App Group).
@Observable
final class HistoryViewModel {
    // MARK: - Properties

    var isLocked: Bool = false
    var showPaywall: Bool = false

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Refresh premium gating state.
    func loadData() async {
        await checkPremiumAccess()
        if isLocked {
            showPaywall = true
        }
    }

    /// Check if user has premium subscription.
    func checkPremiumAccess() async {
        let statusString = AppGroupManager.shared.subscriptionStatus
        let status = SubscriptionStatus(rawValue: statusString) ?? .free
        self.isLocked = !status.isPremium
        self.showPaywall = isLocked
    }

    /// Refresh gating state.
    func refresh() async {
        await loadData()
    }
}
