import DeviceActivity
import SwiftUI
import _DeviceActivity_SwiftUI

@main
struct ScreenSpanReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
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
        OnboardingGoalReportScene { payload in
            OnboardingGoalReportView(payload: payload)
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

struct OnboardingGoalReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .onboardingGoal
    let content: (ScreenTimeReportPayload) -> OnboardingGoalReportView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> ScreenTimeReportPayload {
        await extractDailyAverage(from: data)
    }
}

/// Extract the average daily Screen Time, in hours, from the
/// `DeviceActivityResults` handed to the extension.
///
/// For daily projection filters, segments are bucketed by calendar day
/// before averaging so multiple devices contribute to the same daily total.
///
/// PRIVACY MODEL — DO NOT VIOLATE
/// ------------------------------
/// The `Double` returned here is a per-user Screen Time-derived value.
/// It is legal *only* because it stays inside the extension process:
/// it flows directly into `makeConfiguration(representing:)`, which
/// hands it to the SwiftUI view hierarchy hosted by the extension and
/// rendered to the host app as opaque pixels via
/// `DeviceActivityReport(filter:)`.
///
/// This value MUST NEVER cross the extension/host boundary.
/// Specifically, it must not be:
///   • written to the App Group `UserDefaults` (or any shared file
///     in the App Group container),
///   • posted via Darwin notifications, URL schemes, custom paste-
///     boards, keychain items, or pushed to a server,
///   • encoded into any string the host app could read back.
///
/// Doing any of the above turns this scalar into a Screen Time data
/// leak and is a hard App Review rejection. If you need the host to
/// display a usage figure, route it through another extension scene
/// — never through cross-process state.
private func extractDailyAverage(
    from results: DeviceActivityResults<DeviceActivityData>
) async -> ScreenTimeReportPayload {
    var durationByDay: [Date: TimeInterval] = [:]
    let calendar = Calendar.current

    for await activityData in results {
        for await segment in activityData.activitySegments {
            let day = calendar.startOfDay(for: segment.dateInterval.start)
            durationByDay[day, default: 0] += segment.totalActivityDuration
        }
    }

    guard !durationByDay.isEmpty else {
        return .unavailable
    }

    let totalDuration = durationByDay.values.reduce(0, +)
    return .available((totalDuration / Double(durationByDay.count)) / 3600)
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

struct OnboardingGoalReportView: View {
    let payload: ScreenTimeReportPayload

    @AppStorage(SharedConstants.UserDefaultsKey.currentAge.rawValue, store: .appGroup)
    private var currentAge: Int = 30

    @AppStorage(SharedConstants.UserDefaultsKey.targetAge.rawValue, store: .appGroup)
    private var targetAge: Int = SharedConstants.DefaultValues.targetAge

    @AppStorage(SharedConstants.UserDefaultsKey.screenTimeGoalMinutes.rawValue, store: .appGroup)
    private var screenTimeGoalMinutes: Int = 0

    @State private var draftGoalHours: Double = 0

    private let goalSliderColor = Color(hex: "#C82020")
    private let currentUsageColor = Color(hex: "#C82020")
    private let goalUsageColor = Color(hex: "#0063D6")
    private let labelColor = Color(hex: "#3F4854")
    private let bodyColor = Color(hex: "#102847")
    private let reclaimBackgroundColor = Color(hex: "#D7EAFF")

    private var resolvedCurrentAge: Int { max(currentAge, 1) }
    private var resolvedTargetAge: Int { max(targetAge, resolvedCurrentAge) }
    private var dailyAverageHours: Double { payload.dailyAverageHours ?? 0 }

    private var maxSliderHours: Double {
        max(dailyAverageHours, 0.1)
    }

    private var storedGoalHours: Double {
        Double(screenTimeGoalMinutes) / 60.0
    }

    private var currentUsageFormatted: String {
        String(format: "%.1f", dailyAverageHours)
    }

    private var goalUsageFormatted: String {
        String(format: "%.1f", draftGoalHours)
    }

    private var currentProjection: ProjectionResult {
        ProjectionCalculator.calculateProjectionFromDaily(
            currentAge: resolvedCurrentAge,
            targetAge: resolvedTargetAge,
            dailyHours: dailyAverageHours
        )
    }

    private var reclaimResult: ReclaimResult {
        ProjectionCalculator.calculateReclaim(
            currentProjection: currentProjection,
            goalDailyMinutes: draftGoalHours * 60,
            currentAge: resolvedCurrentAge,
            targetAge: resolvedTargetAge
        )
    }

    private var reclaimedYearsRounded: Int {
        Int(reclaimResult.yearsReclaimed.rounded())
    }

    var body: some View {
        Group {
            if payload.isAvailable {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("0h")
                                .font(.geist(size: 14, weight: .medium))
                                .foregroundColor(labelColor)

                            Spacer()

                            Text(formattedHours(maxSliderHours))
                                .font(.geist(size: 14, weight: .medium))
                                .foregroundColor(labelColor)
                        }

                        Slider(
                            value: Binding(
                                get: { draftGoalHours },
                                set: { newValue in
                                    let clamped = min(max(newValue, 0), maxSliderHours)
                                    draftGoalHours = clamped
                                    screenTimeGoalMinutes = Int((clamped * 60).rounded())
                                }
                            ),
                            in: 0...maxSliderHours,
                            step: 0.1
                        )
                        .tint(goalSliderColor)
                    }

                    HStack(spacing: 12) {
                        usageSummaryColumn(
                            title: "Your current usage",
                            value: currentUsageFormatted,
                            accentColor: currentUsageColor,
                            textAlignment: .leading,
                            frameAlignment: .leading
                        )

                        Spacer()

                        Image(systemName: "arrow.right")
                            .font(.geist(size: 20, weight: .semibold))
                            .foregroundColor(labelColor)

                        Spacer()

                        usageSummaryColumn(
                            title: "Your goal",
                            value: goalUsageFormatted,
                            accentColor: goalUsageColor,
                            textAlignment: .trailing,
                            frameAlignment: .trailing
                        )
                    }
                    .padding(16)
                    .background(Color.screenSpanCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    HStack(spacing: 12) {
                        Image(systemName: "figure.walk")
                            .font(.geist(size: 22, weight: .semibold))
                            .foregroundColor(goalUsageColor)

                        Text("You'd reclaim \(reclaimedYearsRounded) years of your life!")
                            .font(.geist(size: 16, weight: .semibold))
                            .foregroundColor(bodyColor)

                        Spacer()
                    }
                    .padding(16)
                    .background(reclaimBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color.white)
                .onAppear {
                    let initialGoal = storedGoalHours > 0 ? min(storedGoalHours, maxSliderHours) : maxSliderHours
                    draftGoalHours = min(max(initialGoal, 0), maxSliderHours)
                    screenTimeGoalMinutes = Int((draftGoalHours * 60).rounded())
                }
            } else {
                OnboardingGoalUnavailableView()
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
            }
        }
        .background(Color.white)
    }

    private func usageSummaryColumn(
        title: String,
        value: String,
        accentColor: Color,
        textAlignment: HorizontalAlignment,
        frameAlignment: Alignment
    ) -> some View {
        VStack(alignment: textAlignment, spacing: 6) {
            Text(title)
                .font(.geist(size: 13, weight: .medium))
                .foregroundColor(labelColor)

            HStack(spacing: 4) {
                Text(value)
                    .font(.geist(size: 17, weight: .semibold))
                    .foregroundColor(accentColor)
                    .monospacedDigit()

                Text("hours/day")
                    .font(.geist(size: 15, weight: .medium))
                    .foregroundColor(bodyColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    private func formattedHours(_ hours: Double) -> String {
        let roundedHours = (hours * 10).rounded() / 10
        if roundedHours == roundedHours.rounded() {
            return "\(Int(roundedHours))h"
        }

        return String(format: "%.1fh", roundedHours)
    }
}

struct ScreenTimeReportPayload: Codable, Sendable {
    let dailyAverageHours: Double?

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

private struct OnboardingGoalUnavailableView: View {
    var body: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.screenSpanCardBackground)
                .frame(height: 84)
                .overlay {
                    VStack(spacing: 10) {
                        HStack {
                            Text("0h")
                            Spacer()
                            Text("--")
                        }
                        .font(.geist(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "#7F8893"))

                        Capsule()
                            .fill(Color(hex: "#E3E6EB"))
                            .frame(height: 7)
                    }
                    .padding(.horizontal, 16)
                }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "target")
                        .font(.geist(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: "#C82020"))

                    Text("We need real Screen Time data to suggest a goal.")
                        .font(.geist(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: "#102847"))
                }

                Text("Once iOS reports recent activity, we can show your current usage and how many years you could reclaim.")
                    .font(.geist(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "#595959"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(Color(hex: "#FFF1F1"))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(hex: "#F2B7B7"), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
