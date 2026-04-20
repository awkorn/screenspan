import DeviceActivity
import SwiftUI
import _DeviceActivity_SwiftUI

@main
struct ScreenSpanReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        StatsReportScene { dailyAverageHours in
            StatsReportView(dailyAverageHours: dailyAverageHours)
        }
        ChartReportScene { dailyAverageHours in
            ChartReportView(dailyAverageHours: dailyAverageHours)
        }
        HistoryReportScene { dailyAverageHours in
            HistoryReportView(dailyAverageHours: dailyAverageHours)
        }
        OnboardingGoalReportScene { dailyAverageHours in
            OnboardingGoalReportView(dailyAverageHours: dailyAverageHours)
        }
    }
}

struct StatsReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .stats
    let content: (Double) -> StatsReportView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> Double {
        await extractDailyAverage(from: data)
    }
}

struct ChartReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .chart
    let content: (Double) -> ChartReportView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> Double {
        await extractDailyAverage(from: data)
    }
}

struct HistoryReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .history
    let content: (Double) -> HistoryReportView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> Double {
        await extractDailyAverage(from: data)
    }
}

struct OnboardingGoalReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .onboardingGoal
    let content: (Double) -> OnboardingGoalReportView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> Double {
        await extractDailyAverage(from: data)
    }
}

/// Extract the average daily Screen Time, in hours, from the
/// `DeviceActivityResults` handed to the extension.
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
) async -> Double {
    var totalDuration: TimeInterval = 0
    var segmentCount = 0

    for await activityData in results {
        for await segment in activityData.activitySegments {
            totalDuration += segment.totalActivityDuration
            segmentCount += 1
        }
    }

    guard segmentCount > 0 else {
        return SharedConstants.DefaultValues.defaultDailyAvgHours
    }

    return (totalDuration / Double(segmentCount)) / 3600
}

struct OnboardingGoalReportView: View {
    let dailyAverageHours: Double

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
