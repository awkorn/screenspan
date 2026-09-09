import SwiftUI
@main
struct PreviewApp: App {
    init() {
        AppGroupManager.shared.currentAge = 25
        AppGroupManager.shared.targetAge = 80
        AppGroupManager.shared.screenTimeGoalMinutes = 120
    }
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 0) {
                Text("DESIGN PREVIEW · SAMPLE DATA").font(.caption2)
                    .foregroundStyle(ScreenSpanAppearance.text).padding(8)
                DashboardReportView(payload: fixture)
            }
            .background(Color.white)
            .preferredColorScheme(CommandLine.arguments.contains("--dark") ? .dark : .light)
        }
    }
    var fixture: ScreenTimeReportPayload {
        let start = ActivitySummary.projectionInterval().start
        let days = [4.2, 3.1, 5.0, 2.8, 3.5, 4.0, 2.5].enumerated().map {
            ActivityDay(date: Calendar.current.date(byAdding: .day, value: $0.offset, to: start)!, hours: $0.element)
        }
        return ScreenTimeReportPayload(dailyAverageHours: days.map(\.hours).reduce(0,+) / 7, days: days)
    }
}
