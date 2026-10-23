import SwiftUI

/// Main entry point for the ScreenSpan application
/// Creates and injects services into the environment
@main
struct ScreenSpanApp: App {
    @StateObject private var authService = AuthorizationService()
    @StateObject private var storeKitService = StoreKitService()
    @StateObject private var notificationService = NotificationService()
    @StateObject private var goalService = GoalService()
    @StateObject private var blockingService = BlockingService()

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
                .environmentObject(blockingService)
                .onAppear {
                    setupServices()
                }
                // Blocking follows the verified Pro entitlement, never a guess.
                .onChange(of: storeKitService.verifiedEntitlement, initial: true) { _, entitled in
                    if let entitled { blockingService.setEntitled(entitled) }
                }
        }
    }

    private func setupServices() {
        authService.refreshAuthorizationStatus()
        // Request permissions only when their feature is available and chosen.
        // Reports and goal planning need no notification or background task.
    }
}
