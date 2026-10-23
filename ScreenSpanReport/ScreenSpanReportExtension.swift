import DeviceActivity
import ManagedSettings
import SwiftUI
import _DeviceActivity_SwiftUI
import OSLog

@main
struct ScreenSpanReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        DashboardReportScene { DashboardReportView(payload: $0) }
        OnboardingOverviewReportScene { OnboardingOverviewReportView(payload: $0) }
        StatsReportScene { payload in
            StatsReportView(payload: payload)
        }
        ChartReportScene { payload in
            ChartReportView(payload: payload)
        }
        HistoryReportScene { payload in
            HistoryReportView(payload: payload)
        }
    }
}

struct StatsReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .stats
    let content: (ScreenTimeReportPayload) -> StatsReportView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> ScreenTimeReportPayload {
        await extractDailyAverage(from: data)
    }
}

struct ChartReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .chart
    let content: (ScreenTimeReportPayload) -> ChartReportView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> ScreenTimeReportPayload {
        await extractDailyAverage(from: data)
    }
}

struct HistoryReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .history
    let content: (ScreenTimeReportPayload) -> HistoryReportView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> ScreenTimeReportPayload {
        await extractDailyAverage(from: data)
    }
}

// No global cache: a context-only cache could return another filter's data or
// survive an authorization change. One mounted dashboard reuses its payload.
// Activity-derived values stay in the report process; never persist or export.
private func extractDailyAverage(
    from results: DeviceActivityResults<DeviceActivityData>
) async -> ScreenTimeReportPayload {
    let logger = Logger(subsystem: "com.screenspan.deviceactivityreport", category: "ReportLoading")
    let started = ContinuousClock.now
    logger.info("Report aggregation started")
    var summary = ActivitySummary()
    let recentInterval = ActivitySummary.projectionInterval()
    var apps: [Application: AppTotals] = [:]
    var pickups = 0
    var notifications = 0
    for await activityData in results {
        for await segment in activityData.activitySegments {
            guard !Task.isCancelled else { return .unavailable }
            summary.add(date: segment.dateInterval.start, duration: segment.totalActivityDuration)
            // Per-app detail only for the seven days Stats describes; older
            // days need just their totals, which keeps the long query cheap.
            guard recentInterval.contains(segment.dateInterval.start) else { continue }
            pickups += segment.totalPickupsWithoutApplicationActivity
            for await category in segment.categories {
                for await app in category.applications {
                    apps[app.application, default: AppTotals()].add(app)
                    pickups += app.numberOfPickups
                    notifications += app.numberOfNotifications
                }
            }
        }
    }
    // Timing only; do not log usage, sample counts, or application identities.
    let elapsed = started.duration(to: .now)
    logger.info("Report aggregation finished in \(String(describing: elapsed), privacy: .public)")
    // Life Grid and Stats always describe the last seven completed days, even
    // when the dashboard query reaches further back for Progress.
    let history = summary.days
    let recent = history.within(recentInterval)
    let dayCount = Double(max(recent.count, 1))
    let topApps = apps
        .map { AppUsage(application: $0.key, dailyHours: $0.value.seconds / 3600 / dayCount,
                        pickupsPerDay: Double($0.value.pickups) / dayCount) }
        .filter { $0.dailyHours >= 1.0 / 60 }
        .sorted { $0.dailyHours > $1.dailyHours }
    return ScreenTimeReportPayload(
        dailyAverageHours: ActivityDay.averageHours(of: recent),
        days: recent,
        history: history,
        topApps: Array(topApps.prefix(5)),
        pickupsPerDay: recent.isEmpty ? nil : Double(pickups) / dayCount,
        notificationsPerDay: recent.isEmpty ? nil : Double(notifications) / dayCount
    )
}

private struct AppTotals {
    var seconds: TimeInterval = 0
    var pickups = 0

    mutating func add(_ app: DeviceActivityData.ApplicationActivity) {
        if app.totalActivityDuration.isFinite, app.totalActivityDuration > 0 { seconds += app.totalActivityDuration }
        pickups += app.numberOfPickups
    }
}

/// Seven-day per-app average. Rendered only inside this extension; app
/// identities are never logged, stored, or returned to the host.
struct AppUsage: Identifiable {
    let id = UUID()
    let application: Application?
    var fallbackName: String = "App"
    let dailyHours: Double
    var pickupsPerDay: Double = 0
}

struct DashboardReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .dashboard
    let content: (ScreenTimeReportPayload) -> DashboardReportView
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ScreenTimeReportPayload {
        await extractDailyAverage(from: data)
    }
}

struct OnboardingOverviewReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .onboardingOverview
    let content: (ScreenTimeReportPayload) -> OnboardingOverviewReportView
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ScreenTimeReportPayload {
        await extractDailyAverage(from: data)
    }
}

struct ScreenTimeReportPayload {
    /// Average of `days`, the last seven completed days.
    let dailyAverageHours: Double?
    var days: [ActivityDay] = []
    /// Every completed day the query returned, including the week before the
    /// user started. Used only by Progress.
    var history: [ActivityDay] = []
    /// Up to five apps by daily average over `days`.
    var topApps: [AppUsage] = []
    var pickupsPerDay: Double?
    var notificationsPerDay: Double?

    static func available(_ dailyAverageHours: Double) -> ScreenTimeReportPayload {
        ScreenTimeReportPayload(dailyAverageHours: dailyAverageHours)
    }

    static let unavailable = ScreenTimeReportPayload(dailyAverageHours: nil)

    var isAvailable: Bool {
        dailyAverageHours != nil
    }
}

struct ScreenTimeUnavailableView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.geist(size: 28, weight: .semibold))
                .foregroundStyle(Color(hex: "#C82020"))

            Text(title)
                .font(.geist(size: 20, weight: .bold))
                .foregroundStyle(Color(hex: "#051425"))
                .multilineTextAlignment(.center)

            Text(message)
                .font(.geist(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: "#595959"))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .background(Color.white)
    }
}
