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
