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
