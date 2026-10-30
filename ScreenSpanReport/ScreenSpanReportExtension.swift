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
        AppAveragesReportScene { AppAveragesReportView(payload: $0) }
        PlanCheckInReportScene { PlanCheckInReportView(payload: $0) }
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
func extractDailyAverage(
    from results: DeviceActivityResults<DeviceActivityData>
) async -> ScreenTimeReportPayload {
    let logger = Logger(subsystem: "com.screenspan.deviceactivityreport", category: "ReportLoading")
    let started = ContinuousClock.now
    logger.info("Report aggregation started")
    var summary = ActivitySummary()
    let recentInterval = ActivitySummary.projectionInterval()
    var apps: [Application: AppTotals] = [:]
    var pickups = 0
    let plan = BlockingConfiguration.load().plan
    var planned = PlannedUsage(plan: plan)
    for await activityData in results {
        for await segment in activityData.activitySegments {
            guard !Task.isCancelled else { return .unavailable }
            let day = segment.dateInterval.start
            summary.add(date: day, duration: segment.totalActivityDuration)
            // Per-app detail only for the seven days Stats describes and, with
            // a plan, its apps from the week before it; other days need just
            // their totals, which keeps the long query cheap.
            let needsApps = recentInterval.contains(day)
            let needsPlan = planned.covers(day)
            guard needsApps || needsPlan else { continue }
            if needsPlan { planned.markReported(day) }
            if needsApps { pickups += segment.totalPickupsWithoutApplicationActivity }
            for await category in segment.categories {
                if needsPlan { planned.add(category: category.category.token, duration: category.totalActivityDuration, on: day) }
                for await app in category.applications {
                    if needsApps {
                        apps[app.application, default: AppTotals()].add(app)
                        pickups += app.numberOfPickups
                    }
                    if needsPlan { planned.add(application: app.application.token, duration: app.totalActivityDuration, on: day) }
                }
                if needsPlan && planned.watchesWebDomains {
                    for await site in category.webDomains {
                        planned.add(webDomain: site.webDomain.token, duration: site.totalActivityDuration, on: day)
                    }
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
        plan: plan,
        planUsage: planned.days
    )
}

/// Daily totals for each planned app, from the week before its first limit,
/// so the plan can be compared with where it started. Reported days without
/// the app count as zero; unreported days stay missing.
private struct PlannedUsage {
    private var ids: [AnyHashable: [UUID]] = [:]
    private var seconds: [UUID: [Date: TimeInterval]] = [:]
    private let start: Date?
    private let calendar = Calendar.current
    let watchesWebDomains: Bool

    init(plan: ReductionPlan) {
        for app in plan.apps {
            for token in app.selection.applicationTokens { ids[AnyHashable(token), default: []].append(app.id) }
            for token in app.selection.categoryTokens { ids[AnyHashable(token), default: []].append(app.id) }
            for token in app.selection.webDomainTokens { ids[AnyHashable(token), default: []].append(app.id) }
        }
        watchesWebDomains = plan.apps.contains { !$0.selection.webDomainTokens.isEmpty }
        let calendar = Calendar.current
        start = plan.apps.map { calendar.startOfDay(for: $0.course.steps[0].startedAt) }.min()
            .flatMap { calendar.date(byAdding: .day, value: -7, to: $0) }
    }

    func covers(_ day: Date) -> Bool {
        start.map { day >= $0 } ?? false
    }

    mutating func markReported(_ day: Date) {
        let day = calendar.startOfDay(for: day)
        for id in Set(ids.values.joined()) { seconds[id, default: [:]][day, default: 0] += 0 }
    }

    mutating func add(application token: ApplicationToken?, duration: TimeInterval, on day: Date) {
        add(token.map(AnyHashable.init), duration, day)
    }

    mutating func add(category token: ActivityCategoryToken?, duration: TimeInterval, on day: Date) {
        add(token.map(AnyHashable.init), duration, day)
    }

    mutating func add(webDomain token: WebDomainToken?, duration: TimeInterval, on day: Date) {
        add(token.map(AnyHashable.init), duration, day)
    }

    private mutating func add(_ token: AnyHashable?, _ duration: TimeInterval, _ day: Date) {
        guard let token, let matches = ids[token], duration.isFinite, duration > 0 else { return }
        for id in matches { seconds[id, default: [:]][calendar.startOfDay(for: day), default: 0] += duration }
    }

    var days: [UUID: [ActivityDay]] {
        seconds.mapValues { byDay in
            byDay.map { ActivityDay(date: $0.key, hours: $0.value / 3600) }.sorted { $0.date < $1.date }
        }
    }
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
    /// The user's plan as it was when the report loaded.
    var plan = ReductionPlan()
    /// Daily hours for each planned app, keyed by `PlannedApp.id`.
    var planUsage: [UUID: [ActivityDay]] = [:]

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
