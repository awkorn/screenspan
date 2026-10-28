import Foundation

/// Application-wide constants for ScreenSpan
enum AppConstants {
    // MARK: - StoreKit Product IDs

    /// ScreenSpan Pro auto-renewable subscriptions, one subscription group.
    /// Must match App Store Connect and `ScreenSpan.storekit`.
    enum ProductID {
        static let monthlySubscription = "com.screenspan.subscription.monthly"
        static let annualSubscription = "com.screenspan.subscription.annual"
        static let all = [annualSubscription, monthlySubscription]
    }

    // MARK: - Legal

    enum Legal {
        /// Apple's standard EULA. Replace if you publish your own terms.
        static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
        // TODO: Before submitting, replace with the privacy policy URL entered in App Store Connect.
        static let privacyPolicy = URL(string: "https://screenspan.app/privacy")!
    }
}
