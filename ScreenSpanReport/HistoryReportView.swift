import SwiftUI
import Charts

/// Real daily segments only. No invented history, baseline, or savings claim.
struct HistoryReportView: View {
    let payload: ScreenTimeReportPayload
    @AppStorage(SharedConstants.UserDefaultsKey.screenTimeGoalMinutes.rawValue, store: .appGroup)
    private var goalMinutes: Double = 120
    @AppStorage(SharedConstants.UserDefaultsKey.currentAge.rawValue, store: .appGroup)
    private var currentAge = 25
    @AppStorage(SharedConstants.UserDefaultsKey.targetAge.rawValue, store: .appGroup)
    private var targetAge = 80

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Screen time over time")
                    .font(.geist(size: 26, weight: .bold))
                Text("Last seven completed days. Gaps mean activity was unavailable.")
                    .font(.geist(size: 14))
                    .foregroundStyle(ScreenSpanAppearance.secondaryText)

                Chart {
                    ForEach(payload.days) { day in
                        BarMark(x: .value("Day", day.date, unit: .day), y: .value("Hours", day.hours))
                            .foregroundStyle(Color(hex: "#0063D6"))
                    }
                    RuleMark(y: .value("Daily goal", goalMinutes / 60))
                        .foregroundStyle(Color(hex: "#F63232"))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Goal").font(.caption2).foregroundStyle(ScreenSpanAppearance.secondaryText)
                        }
                }
                .chartXScale(domain: ActivitySummary.projectionInterval().start...ActivitySummary.projectionInterval().end)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 2)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(ScreenSpanAppearance.secondaryText)
                    }
                }
                .chartYAxis {
                    AxisMarks {
                        AxisGridLine().foregroundStyle(Color(hex: "#D9DDE5"))
                        AxisValueLabel().foregroundStyle(ScreenSpanAppearance.secondaryText)
                    }
                }
                .chartYAxisLabel {
                    Text("hours").foregroundStyle(ScreenSpanAppearance.secondaryText)
                }
                .frame(height: 190)
                .padding(18)
                .background(Color(hex: "#F6F7FA"), in: RoundedRectangle(cornerRadius: 18))
                if let average = payload.dailyAverageHours {
                    reclaimSection(average: average)
                    metric("Daily average", hours: average, icon: "chart.bar")
                    metric("Your daily goal", hours: goalMinutes / 60, icon: "target")
                }
                Text("Daily activity")
                    .font(.geist(size: 18, weight: .semibold))
                ForEach(payload.days.reversed()) { day in
                    metric(day.date.formatted(date: .abbreviated, time: .omitted), hours: day.hours, icon: "calendar")
                }
                Text("Projections describe what could happen if a daily average continues. They are not a measurement of time already reclaimed.")
                    .font(.geist(size: 12))
                    .foregroundStyle(ScreenSpanAppearance.secondaryText)
            }
            .padding(24)
        }
        .background(Color.white)
        .screenSpanLightSurface()
    }

    private func reclaimSection(average: Double) -> some View {
        let projection = ProjectionCalculator.calculateProjectionFromDaily(
            currentAge: currentAge, targetAge: targetAge, dailyHours: average)
        let reclaim = ProjectionCalculator.calculateReclaim(
            currentProjection: projection, goalDailyMinutes: goalMinutes,
            currentAge: currentAge, targetAge: targetAge)
        return VStack(alignment: .leading, spacing: 14) {
            Text("At your goal, you could reclaim")
                .font(.geist(size: 18, weight: .semibold))
            HStack(spacing: 10) {
                reclaimTile(String(format: "%.1f", reclaim.yearsReclaimed), unit: "years", icon: "calendar")
                reclaimTile(String(format: "%.0f", reclaim.monthsReclaimed), unit: "months", icon: "calendar.badge.clock")
                reclaimTile(String(format: "%.0f", reclaim.yearsReclaimed * 365), unit: "days", icon: "sun.max")
            }
            Text("Equivalent time by age \(targetAge), if you sustain your goal instead of this average.")
                .font(.geist(size: 12)).foregroundStyle(ScreenSpanAppearance.secondaryText)
        }
    }

    private func reclaimTile(_ value: String, unit: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Color(hex: "#235187"))
            Text(value).font(.geist(size: 22, weight: .bold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(unit).font(.geist(size: 13)).foregroundStyle(ScreenSpanAppearance.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color(hex: "#F6F7FA"), in: RoundedRectangle(cornerRadius: 14))
    }

    private func metric(_ title: String, hours: Double, icon: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon).foregroundStyle(Color(hex: "#235187"))
            Text(title).font(.geist(size: 14))
            Spacer()
            Text(duration(hours)).font(.geist(size: 17, weight: .semibold)).monospacedDigit()
        }
        .padding(18)
        .background(Color(hex: "#F6F7FA"), in: RoundedRectangle(cornerRadius: 12))
    }

    private func duration(_ hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
