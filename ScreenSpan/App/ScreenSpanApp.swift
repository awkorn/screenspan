import SwiftUI

/// Main entry point for the ScreenSpan application
/// Creates and injects services into the environment
@main
struct ScreenSpanApp: App {
    @StateObject private var authService = AuthorizationService()
    @StateObject private var storeKitService = StoreKitService()
    @StateObject private var notificationService = NotificationService()
    @StateObject private var goalService = GoalService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .screenSpanLightSurface()
                .environment(\.appGroupIdentifier, SharedConstants.appGroupIdentifier)
                .environmentObject(authService)
                .environmentObject(storeKitService)
                .environmentObject(notificationService)
                .environmentObject(goalService)
                .onAppear {
                    setupServices()
                }
        }
    }

    private func setupServices() {
        authService.refreshAuthorizationStatus()
        // Request permissions only when their feature is available and chosen.
        // Reports and goal planning need no notification or background task.
    }
}
