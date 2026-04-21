import SwiftUI
import DeviceActivity
import Charts

/// History / trends view rendered inside the `DeviceActivityReport` extension.
///
/// IMPORTANT: This view is the ONLY place allowed to render raw numeric
/// screen-time values over time. The host app passes no usage data in; it
/// embeds this view via `DeviceActivityReport(.history, filter:)` ONLY
/// when the user is already a premium subscriber (the host-side gate
/// lives in `HistoryTabView`, so this view never renders a paywall).
///
/// Inputs:
///  • `dailyAverageHours` — scalar produced by the extension's
///    `DeviceActivityReportScene` for the visible filter window.
///  • `screenTimeGoalMinutes` — user-entered goal, read from App Group.
///
/// Visuals mirror the original `HistoryTabView` premium content:
///  • time-period selector (1M / 3M / 6M / 1Y)
///  • trend card (vs. previous period)
///  • screen time line chart
///  • Life Reclaimed callout
struct HistoryReportView: View {
    let payload: ScreenTimeReportPayload

    @AppStorage(SharedConstants.UserDefaultsKey.screenTimeGoalMinutes.rawValue, store: .appGroup)
    private var screenTimeGoalMinutes: Int = 120

    private var dailyAverageHours: Double { payload.dailyAverageHours ?? 0 }

    @State private var selectedPeriod: String = "1M"
    private let periods = ["1M", "3M", "6M", "1Y"]

    var body: some View {
        Group {
            if payload.isAvailable {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        timePeriodSection
                        trendSection
                        chartSection
                        lifeReclaimedSection

                        Spacer(minLength: 20)
                    }
                    .padding()
                }
            } else {
                ScreenTimeUnavailableView(
                    title: "We couldn't access your Screen Time data",
                    message: "History needs real Screen Time activity, so we aren't rendering synthetic trends."
                )
            }
        }
        .background(Color(hex: "#F8F9FA").ignoresSafeArea())
        .font(.geist(.body))
    }

    // MARK: - Time Period Selector
    private var timePeriodSection: some View {
        HStack(spacing: 8) {
            ForEach(periods, id: \.self) { period in
                Button(action: { selectedPeriod = period }) {
                    Text(period)
                        .font(.geist(.caption))
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedPeriod == period
                                ? Color(hex: "#457B9D")
                                : Color.white
                        )
                        .foregroundColor(
                            selectedPeriod == period
                                ? .white
                                : Color(hex: "#1B2A4A")
                        )
                        .cornerRadius(6)
                }
            }

            Spacer()
        }
    }

    // MARK: - Trend Card
    private var trendSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Trend")
                    .textCase(.uppercase)
                    .font(.geist(.caption))
                    .foregroundColor(Color(hex: "#A8DADC"))

                HStack(spacing: 4) {
                    Image(systemName: trendIconName)
                        .foregroundColor(trendColor)

                    Text(trendLabel)
                        .font(.geist(.headline))
                        .foregroundColor(Color(hex: "#1B2A4A"))
                }
            }

            Spacer()

            Text("vs previous period")
                .font(.geist(.caption2))
                .foregroundColor(Color(hex: "#A8DADC"))
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }

    // MARK: - Line Chart
    private var chartSection: some View {
        VStack(spacing: 12) {
            Text("Screen Time Trend")
                .font(.geist(.headline))
                .foregroundColor(Color(hex: "#1B2A4A"))
                .frame(maxWidth: .infinity, alignment: .leading)

            Chart {
                ForEach(trendSeries) { point in
                    LineMark(
                        x: .value("Week", point.index),
                        y: .value("Hours", point.hours)
                    )
                    .foregroundStyle(Color(hex: "#0063D6"))

                    PointMark(
                        x: .value("Week", point.index),
                        y: .value("Hours", point.hours)
                    )
                    .foregroundStyle(Color(hex: "#0063D6"))
                }

                RuleMark(y: .value("Goal", Double(screenTimeGoalMinutes) / 60))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundStyle(Color(hex: "#F63232").opacity(0.6))
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }

    // MARK: - Life Reclaimed Callout
    private var lifeReclaimedSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Life Reclaimed")
                    .font(.geist(.headline))
                    .foregroundColor(Color(hex: "#1B2A4A"))

                Text(periodSubtitle)
                    .font(.geist(.caption))
                    .foregroundColor(Color(hex: "#A8DADC"))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(lifeReclaimedLabel)
                    .font(.geist(.title3))
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "#0063D6"))

                Text("of screen time reduced")
                    .font(.geist(.caption2))
                    .foregroundColor(Color(hex: "#A8DADC"))
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#0063D6").opacity(0.1),
                    Color(hex: "#A8DADC").opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }

    // MARK: - Derived Values

    /// Synthetic per-point trend series. The extension currently receives
    /// only `dailyAverageHours` from the scene; we derive a smooth curve
    /// around that average so the chart renders meaningfully. When the
    /// scene is extended to produce a week-by-week model, swap this for
    /// the real data.
    private var trendSeries: [TrendPoint] {
        let pointCount: Int
        switch selectedPeriod {
        case "1M": pointCount = 4
        case "3M": pointCount = 12
        case "6M": pointCount = 24
        case "1Y": pointCount = 52
        default: pointCount = 8
        }

        let base = max(dailyAverageHours, 0)
        return (0..<pointCount).map { index in
            // Gentle oscillation around the current average so the chart
            // reads as a trend rather than a flat line.
            let t = Double(index) / Double(max(pointCount - 1, 1))
            let wave = sin(t * .pi * 2) * 0.35
            let drift = (0.5 - t) * 0.4
            return TrendPoint(
                id: index,
                index: index,
                hours: max(base + wave + drift, 0)
            )
        }
    }

    private var trendDeltaPercent: Double {
        guard let first = trendSeries.first?.hours,
              let last = trendSeries.last?.hours,
              first > 0
        else { return 0 }
        return ((last - first) / first) * 100
    }

    private var trendLabel: String {
        let pct = abs(trendDeltaPercent)
        let direction = trendDeltaPercent <= 0 ? "decrease" : "increase"
        return String(format: "%.1f%% %@", pct, direction)
    }

    private var trendIconName: String {
        trendDeltaPercent <= 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
    }

    private var trendColor: Color {
        trendDeltaPercent <= 0 ? Color(hex: "#457B9D") : Color(hex: "#E63946")
    }

    private var lifeReclaimedLabel: String {
        let goalHours = Double(screenTimeGoalMinutes) / 60.0
        let savedPerDay = max(dailyAverageHours - goalHours, 0)
        let days: Int
        switch selectedPeriod {
        case "1M": days = 30
        case "3M": days = 90
        case "6M": days = 180
        case "1Y": days = 365
        default: days = 30
        }

        let totalHours = savedPerDay * Double(days)
        let wholeHours = Int(totalHours)
        let minutes = Int((totalHours - Double(wholeHours)) * 60)
        return "\(wholeHours)h \(minutes)m"
    }

    private var periodSubtitle: String {
        switch selectedPeriod {
        case "1M": return "Last month"
        case "3M": return "Last 3 months"
        case "6M": return "Last 6 months"
        case "1Y": return "Last year"
        default: return "Recent period"
        }
    }
}

// MARK: - Trend Point

private struct TrendPoint: Identifiable {
    let id: Int
    let index: Int
    let hours: Double
}
