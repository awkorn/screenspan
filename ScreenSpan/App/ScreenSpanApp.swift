import SwiftUI
import BackgroundTasks

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
        // Request DeviceActivity authorization
        Task {
            await authService.requestAuthorization()
        }

        // Initialize StoreKit
        storeKitService.loadProducts()

        // Request notification permissions
        Task {
            await notificationService.requestAuthorization()
        }

        // Register background tasks
        registerBackgroundTasks()
    }

    private func registerBackgroundTasks() {
        // Register background task for checking goals
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AppConstants.backgroundTaskIdentifier,
            using: nil
        ) { task in
            goalService.checkAndNotifyGoals()
            task.setTaskCompleted(success: true)
        }
    }
}
