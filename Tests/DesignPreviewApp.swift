import SwiftUI
@main
struct PreviewApp: App {
    @State private var onboardingPage = 0
    init() {
        AppGroupManager.shared.currentAge = 25
        AppGroupManager.shared.targetAge = 80
        AppGroupManager.shared.screenTimeGoalMinutes = 120
        AppGroupManager.shared.trackingStartDate = Calendar.current.date(byAdding: .day, value: -21, to: Date())
    }
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 0) {
                Text("DESIGN PREVIEW · SAMPLE DATA").font(.caption2)
                    .foregroundStyle(ScreenSpanAppearance.text).padding(8)
                if CommandLine.arguments.contains("--onboarding") {
                    Text(onboardingPage == 0 ? "Your Screen Time projection" : "Your life chart")
                        .font(.title2.bold()).foregroundStyle(ScreenSpanAppearance.text)
                        .padding()
                    if onboardingPage < 2 {
                        OnboardingReportViewport(showsLifeChart: onboardingPage == 1) {
                            OnboardingOverviewReportView(payload: fixture)
                        }
                        Button(onboardingPage == 0 ? "See your life chart" : "Reclaim your life") {
                            onboardingPage += 1
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    } else {
                        Text("Goal setting reached").foregroundStyle(ScreenSpanAppearance.text)
                        Spacer()
                    }
                } else {
                    DashboardReportView(payload: fixture)
                }
            }
            .background(Color.white)
            .preferredColorScheme(CommandLine.arguments.contains("--dark") ? .dark : .light)
        }
    }
    /// Seven sample days before a start 21 days ago, then a gradual decline.
    var fixture: ScreenTimeReportPayload {
        let today = Calendar.current.startOfDay(for: Date())
        let hours = [5.4, 4.8, 5.9, 5.1, 4.6, 5.3, 4.9,
                     4.7, 4.1, 4.9, 3.8, 4.2, 3.5, 4.0, 3.6, 3.1, 3.9, 3.3, 2.9, 3.4,
                     3.0, 2.6, 3.2, 2.4, 2.8, 3.1, 2.5, 2.7]
        let history = hours.enumerated().map {
            ActivityDay(date: Calendar.current.date(byAdding: .day, value: $0.offset - hours.count, to: today)!, hours: $0.element)
        }
        let days = history.within(ActivitySummary.projectionInterval())
        let apps = [("Instagram", 0.9), ("Safari", 0.45), ("Messages", 0.35), ("YouTube", 0.3), ("Mail", 0.15)]
            .map { AppUsage(application: nil, fallbackName: $0.0, dailyHours: $0.1) }
        return ScreenTimeReportPayload(dailyAverageHours: ActivityDay.averageHours(of: days), days: days, history: history,
                                       topApps: apps, pickupsPerDay: 84, notificationsPerDay: 131)
    }
}
