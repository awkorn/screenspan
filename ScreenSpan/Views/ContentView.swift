import SwiftUI

/// Root view for the ScreenSpan app
/// Handles onboarding state and routing to main app or onboarding flow
struct ContentView: View {
    @AppStorage("onboarding_completed") var onboardingCompleted = false

    var body: some View {
        if onboardingCompleted {
            MainTabView()
        } else {
            OnboardingContainerView()
        }
    }
}
