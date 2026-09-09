import DeviceActivity
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
        OnboardingProjectionReportScene { payload in
            OnboardingProjectionReportView(payload: payload)
        }
        OnboardingLifeChartReportScene { payload in
            OnboardingLifeChartReportView(payload: payload)
        }
        HistoryReportScene { payload in
            HistoryReportView(payload: payload)
        }
        OnboardingPaywallReclaimReportScene { payload in
            OnboardingPaywallReclaimReportView(payload: payload)
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

struct OnboardingProjectionReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .onboardingProjection
    let content: (ScreenTimeReportPayload) -> OnboardingProjectionReportView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> ScreenTimeReportPayload {
        await extractDailyAverage(from: data)
    }
}

struct OnboardingLifeChartReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .onboardingLifeChart
    let content: (ScreenTimeReportPayload) -> OnboardingLifeChartReportView

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

struct OnboardingPaywallReclaimReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .onboardingPaywallReclaim
    let content: (ScreenTimeReportPayload) -> OnboardingPaywallReclaimReportView

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
    let logger = Logger(subsystem: "com.screenspan.deviceactivity", category: "ReportLoading")
    let started = ContinuousClock.now
    logger.info("Report aggregation started")
    var summary = ActivitySummary()
    for await activityData in results {
        for await segment in activityData.activitySegments {
            guard !Task.isCancelled else { return .unavailable }
            summary.add(date: segment.dateInterval.start, duration: segment.totalActivityDuration)
        }
    }
    // Timing only; do not log usage, sample counts, or application identities.
    let elapsed = started.duration(to: .now)
    logger.info("Report aggregation finished in \(String(describing: elapsed), privacy: .public)")
    return ScreenTimeReportPayload(dailyAverageHours: summary.dailyAverageHours, days: summary.days)
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

struct OnboardingProjectionReportView: View {
    let payload: ScreenTimeReportPayload

    @AppStorage(SharedConstants.UserDefaultsKey.currentAge.rawValue, store: .appGroup)
    private var currentAge: Int = 30

    @AppStorage(SharedConstants.UserDefaultsKey.targetAge.rawValue, store: .appGroup)
    private var targetAge: Int = SharedConstants.DefaultValues.targetAge

    @State private var displayedYears = 0.0
    @State private var timerRotation = 0.0
    @State private var countingTask: Task<Void, Never>?

    private let backgroundColor = Color.white
    private let titleColor = Color(hex: "#051425")
    private let mutedColor = Color(hex: "#797979")
    private let blurredRedColor = Color(hex: "#F63232")
    private let yearsTextColor = Color.white
    private let boxBackground = Color(hex: "#FFC2C2")
    private let boxStroke = Color(hex: "#C82020")

    private var resolvedCurrentAge: Int { max(currentAge, 1) }
    private var resolvedTargetAge: Int { max(targetAge, resolvedCurrentAge) }

    private var projection: ProjectionResult {
        ProjectionCalculator.calculateProjectionFromDaily(
            currentAge: resolvedCurrentAge,
            targetAge: resolvedTargetAge,
            dailyHours: payload.dailyAverageHours ?? 0
        )
    }

    private var targetYears: Double {
        max(projection.yearsOnPhone, 0)
    }

    private var targetPercent: Double {
        max(projection.percentOfWakingLife, 0)
    }

    private var yearsFormatted: String {
        String(format: "%.1f", displayedYears)
    }

    private var percentageFormatted: String {
        String(format: "%.0f", targetPercent)
    }

    var body: some View {
        Group {
            if payload.isAvailable {
                VStack(spacing: 0) {
                    Spacer(minLength: 16)

                    HStack(spacing: 8) {
                        Image(systemName: "hourglass")
                            .font(.geist(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: "#C82020"))
                            .rotationEffect(.degrees(timerRotation))

                        Text("TIME ANALYSIS COMPLETE")
                            .font(.geist(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "#575757"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#ECECEF"))
                            .overlay(
                                Capsule()
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )
                    )

                    Spacer(minLength: 44)

                    VStack(spacing: 10) {
                        Text(yearsFormatted)
                            .font(.geist(size: 80, weight: .bold))
                            .foregroundStyle(yearsTextColor)
                            .monospacedDigit()
                            .shadow(color: .black.opacity(0.20), radius: 2, x: 0, y: 2)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                Circle()
                                    .fill(blurredRedColor.opacity(0.42))
                                    .frame(width: 270, height: 210)
                                    .blur(radius: 36)
                            )

                        Text("YEARS")
                            .font(.geist(size: 28, weight: .bold))
                            .foregroundStyle(Color(hex: "#C82020"))

                        Text("of your waking life")
                            .font(.geist(size: 20, weight: .semibold))
                            .italic()
                            .foregroundStyle(mutedColor)

                        Text("staring at your phone.")
                            .font(.geist(size: 24, weight: .bold))
                            .foregroundStyle(titleColor)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                    Spacer(minLength: 36)

                    HStack(spacing: 10) {
                        Image(systemName: "clock")
                            .font(.geist(size: 18, weight: .semibold))
                            .foregroundStyle(Color(hex: "#D92A2A"))

                        Text("That’s \(percentageFormatted)% of every waking hour you have left.")
                            .font(.geist(size: 16, weight: .semibold))
                            .foregroundStyle(titleColor)
                            .lineLimit(2)

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(boxBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(boxStroke, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)

                    Spacer()
                }
                .onAppear {
                    startAnimations()
                }
                .onDisappear {
                    countingTask?.cancel()
                }
            } else {
                OnboardingProjectionUnavailableView()
            }
        }
        .background(backgroundColor)
    }

    private func startAnimations() {
        withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
            timerRotation = 360
        }

        countingTask?.cancel()
        countingTask = Task {
            let steps = 55
            for step in 1...steps {
                if Task.isCancelled { return }
                let progress = Double(step) / Double(steps)
                let eased = 1 - pow(1 - progress, 3)

                await MainActor.run {
                    displayedYears = targetYears * eased
                }

                try? await Task.sleep(nanoseconds: 28_000_000)
            }

            await MainActor.run {
                displayedYears = targetYears
            }
        }
    }
}

struct OnboardingLifeChartReportView: View {
    let payload: ScreenTimeReportPayload

    @AppStorage(SharedConstants.UserDefaultsKey.currentAge.rawValue, store: .appGroup)
    private var currentAge: Int = 30

    @AppStorage(SharedConstants.UserDefaultsKey.targetAge.rawValue, store: .appGroup)
    private var targetAge: Int = SharedConstants.DefaultValues.targetAge

    private let titleColor = Color(hex: "#051425")
    private let livedColor = Color(hex: "#0063D6")
    private let screenTimeColor = Color(hex: "#F63232")
    private let remainingColor = Color(hex: "#D9D9D9")
    private let columnCount = 26
    private let spacing: CGFloat = 3

    private var resolvedCurrentAge: Int { max(currentAge, 1) }
    private var resolvedTargetAge: Int { max(targetAge, resolvedCurrentAge) }

    private var lifeGridData: LifeGridData {
        let projection = ProjectionCalculator.calculateProjectionFromDaily(
            currentAge: resolvedCurrentAge,
            targetAge: resolvedTargetAge,
            dailyHours: payload.dailyAverageHours ?? 0
        )

        return ProjectionCalculator.calculateLifeGrid(
            currentAge: resolvedCurrentAge,
            targetAge: resolvedTargetAge,
            monthsOnPhone: projection.monthsOnPhone
        )
    }

    private var monthStates: [OnboardingLifeChartMonthState] {
        var states: [OnboardingLifeChartMonthState] = []
        states.reserveCapacity(lifeGridData.totalMonths)

        states.append(contentsOf: Array(repeating: .lived, count: lifeGridData.monthsLived))
        states.append(contentsOf: Array(repeating: .screenTime, count: lifeGridData.phoneMonths))
        states.append(contentsOf: Array(repeating: .remaining, count: max(lifeGridData.freeMonths, 0)))

        if states.count < lifeGridData.totalMonths {
            states.append(
                contentsOf: Array(
                    repeating: .remaining,
                    count: lifeGridData.totalMonths - states.count
                )
            )
        }

        return Array(states.prefix(lifeGridData.totalMonths))
    }

    private var gridWidth: CGFloat {
        UIScreen.main.bounds.width - 48
    }

    private var cellSize: CGFloat {
        max((gridWidth - (CGFloat(columnCount - 1) * spacing)) / CGFloat(columnCount), 4)
    }

    private var rowCount: Int {
        Int(ceil(Double(monthStates.count) / Double(columnCount)))
    }

    private var gridHeight: CGFloat {
        (CGFloat(rowCount) * cellSize) + (CGFloat(max(rowCount - 1, 0)) * spacing)
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(cellSize), spacing: spacing, alignment: .top),
            count: columnCount
        )
    }

    var body: some View {
        Group {
            if payload.isAvailable {
                VStack(spacing: 0) {
                    chartGrid

                    legend
                        .padding(.top, 18)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                OnboardingLifeChartUnavailableView()
            }
        }
        .background(Color.white)
    }

    private var chartGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: spacing) {
            ForEach(Array(monthStates.enumerated()), id: \.offset) { _, state in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color(for: state))
                    .frame(width: cellSize, height: cellSize)
            }
        }
        .frame(width: gridWidth, height: gridHeight, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: livedColor, label: "Lived")
            legendItem(color: screenTimeColor, label: "Screen time")
            legendItem(color: remainingColor, label: "Remaining time")
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            Text(label)
                .font(.geist(size: 12))
                .foregroundStyle(titleColor)
        }
    }

    private func color(for state: OnboardingLifeChartMonthState) -> Color {
        switch state {
        case .lived:
            return livedColor
        case .screenTime:
            return screenTimeColor
        case .remaining:
            return remainingColor
        }
    }
}

private enum OnboardingLifeChartMonthState {
    case lived
    case screenTime
    case remaining
}

struct OnboardingPaywallReclaimReportView: View {
    let payload: ScreenTimeReportPayload

    @AppStorage(SharedConstants.UserDefaultsKey.currentAge.rawValue, store: .appGroup)
    private var currentAge: Int = 30

    @AppStorage(SharedConstants.UserDefaultsKey.targetAge.rawValue, store: .appGroup)
    private var targetAge: Int = SharedConstants.DefaultValues.targetAge

    @AppStorage(SharedConstants.UserDefaultsKey.screenTimeGoalMinutes.rawValue, store: .appGroup)
    private var screenTimeGoalMinutes: Int = 0

    private let subtitleColor = Color(hex: "#595959")

    private var resolvedCurrentAge: Int { max(currentAge, 1) }
    private var resolvedTargetAge: Int { max(targetAge, resolvedCurrentAge) }
    private var dailyAverageHours: Double { payload.dailyAverageHours ?? 0 }
    private var goalDailyMinutes: Double { Double(screenTimeGoalMinutes) }

    private var reclaimedYearsRounded: Int {
        guard payload.isAvailable, dailyAverageHours > 0, goalDailyMinutes > 0 else {
            return 0
        }

        let projection = ProjectionCalculator.calculateProjectionFromDaily(
            currentAge: resolvedCurrentAge,
            targetAge: resolvedTargetAge,
            dailyHours: dailyAverageHours
        )
        let reclaim = ProjectionCalculator.calculateReclaim(
            currentProjection: projection,
            goalDailyMinutes: goalDailyMinutes,
            currentAge: resolvedCurrentAge,
            targetAge: resolvedTargetAge
        )

        return max(Int(reclaim.yearsReclaimed.rounded()), 0)
    }

    var body: some View {
        Text("Reclaim those \(reclaimedYearsRounded) years of your life")
            .font(.geist(size: 18))
            .foregroundColor(subtitleColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color.white)
    }
}

struct ScreenTimeReportPayload: Sendable {
    let dailyAverageHours: Double?
    var days: [ActivityDay] = []

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

private struct OnboardingProjectionUnavailableView: View {
    private let titleColor = Color(hex: "#051425")
    private let mutedColor = Color(hex: "#797979")
    private let boxBackground = Color(hex: "#FFF1F1")
    private let boxStroke = Color(hex: "#F2B7B7")

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.geist(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#C82020"))

                Text("SCREEN TIME UNAVAILABLE")
                    .font(.geist(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#575757"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(Color(hex: "#ECECEF"))
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            )

            Spacer(minLength: 44)

            VStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: "#FDECEC"))
                    .frame(width: 110, height: 110)
                    .overlay {
                        Image(systemName: "iphone.slash")
                            .font(.geist(size: 36, weight: .semibold))
                            .foregroundStyle(Color(hex: "#C82020"))
                    }

                Text("We couldn't analyze your Screen Time")
                    .font(.geist(size: 28, weight: .bold))
                    .foregroundStyle(titleColor)
                    .multilineTextAlignment(.center)

                Text("Grant access and make sure this device has recent activity, then try again.")
                    .font(.geist(size: 18))
                    .foregroundStyle(mutedColor)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 36)

            VStack(alignment: .leading, spacing: 10) {
                unavailableStep(icon: "lock.open", text: "Allow Screen Time access")
                unavailableStep(icon: "clock", text: "Use your phone for a bit so iOS has activity to report")
                unavailableStep(icon: "arrow.clockwise", text: "Return here and try the analysis again")
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(boxBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(boxStroke, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func unavailableStep(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.geist(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: "#C82020"))
                .frame(width: 18)

            Text(text)
                .font(.geist(size: 14, weight: .medium))
                .foregroundStyle(titleColor)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

private struct OnboardingLifeChartUnavailableView: View {
    private let titleColor = Color(hex: "#051425")

    var body: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "#FAFBFD"))
                .overlay {
                    VStack(spacing: 14) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.geist(size: 28, weight: .semibold))
                            .foregroundStyle(Color(hex: "#C82020"))

                        Text("Your life chart will appear here")
                            .font(.geist(size: 20, weight: .bold))
                            .foregroundStyle(titleColor)
                            .multilineTextAlignment(.center)

                        Text("We need recent Screen Time activity before we can paint this grid with real data.")
                            .font(.geist(size: 14, weight: .medium))
                            .foregroundStyle(Color(hex: "#595959"))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(hex: "#E5E8EE"), lineWidth: 1)
                )

            HStack(spacing: 16) {
                legendItem(color: Color(hex: "#C5D9F5"), label: "Lived")
                legendItem(color: Color(hex: "#F7C9C9"), label: "Screen time")
                legendItem(color: Color(hex: "#E9EDF3"), label: "Remaining time")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            Text(label)
                .font(.geist(size: 12))
                .foregroundStyle(titleColor)
        }
    }
}
