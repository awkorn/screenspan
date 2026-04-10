import SwiftUI
import DeviceActivity
import Charts

/// Weekly trends rendered in the DeviceActivityReport extension
/// Premium-gated view with line chart placeholder for weekly averages
struct HistoryReportView: View {
    let dailyAverageHours: Double

    @State private var weeklyData: [WeeklyTrendData] = []
    @State private var hasLoadedData = false

    // Shared UserDefaults
    @AppStorage(SharedConstants.UserDefaultsKey.subscriptionStatus.rawValue, store: .appGroup)
    private var subscriptionStatus: String = "free"

    @AppStorage(SharedConstants.UserDefaultsKey.screenTimeGoalMinutes.rawValue, store: .appGroup)
    private var screenTimeGoalMinutes: Int = 120

    var isPremium: Bool {
        subscriptionStatus == "premium"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isPremium {
                    PremiumHistoryContent(
                        weeklyData: weeklyData,
                        screenTimeGoalMinutes: screenTimeGoalMinutes,
                        hasLoadedData: hasLoadedData
                    )
                } else {
                    PremiumGateView()
                }
            }
            .padding()
        }
        .onAppear {
            if isPremium {
                generateWeeklyData()
            }
        }
    }

    private func generateWeeklyData() {
        let calendar = Calendar.current
        var data: [WeeklyTrendData] = []

        for weekOffset in stride(from: -8, through: 0, by: 1) {
            let weekStart = calendar.date(byAdding: .day, value: weekOffset * 7, to: Date()) ?? Date()
            let weekLabel = calendar.component(.weekOfYear, from: weekStart)

            // Placeholder: In real implementation, extract from DeviceActivityResults
            let averageHours = Double.random(in: 3...7)
            let delta = Double.random(in: -1...1)

            data.append(WeeklyTrendData(
                weekNumber: weekLabel,
                averageHours: averageHours,
                delta: delta
            ))
        }

        self.weeklyData = data
        self.hasLoadedData = true
    }
}

struct WeeklyTrendData: Identifiable {
    let id = UUID()
    let weekNumber: Int
    let averageHours: Double
    let delta: Double
}

struct PremiumHistoryContent: View {
    let weeklyData: [WeeklyTrendData]
    let screenTimeGoalMinutes: Int
    let hasLoadedData: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Weekly Trend Chart
            VStack(spacing: 12) {
                Text("Weekly Average")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if hasLoadedData && !weeklyData.isEmpty {
                    Chart {
                        ForEach(weeklyData) { data in
                            LineMark(
                                x: .value("Week", data.weekNumber),
                                y: .value("Hours", data.averageHours)
                            )
                            .foregroundStyle(Color.screenSpanBlue)

                            PointMark(
                                x: .value("Week", data.weekNumber),
                                y: .value("Hours", data.averageHours)
                            )
                            .foregroundStyle(Color.screenSpanBlue)
                        }

                        // Goal line
                        RuleMark(y: .value("Goal", Double(screenTimeGoalMinutes) / 60))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                            .foregroundStyle(Color.screenSpanRed.opacity(0.5))
                    }
                    .frame(height: 220)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.screenSpanOffWhite)
                        ProgressView()
                            .tint(Color.screenSpanBlue)
                    }
                    .frame(height: 220)
                }
            }
            .padding()
            .background(Color.screenSpanOffWhite)
            .cornerRadius(12)

            // Trend Summary
            if !weeklyData.isEmpty {
                VStack(spacing: 12) {
                    let latestData = weeklyData.last ?? weeklyData[0]

                    TrendDeltaCard(
                        label: "This Week vs Last",
                        delta: latestData.delta,
                        unit: "hrs"
                    )

                    LifeReclaimedCallout(
                        message: "Keep it up! You're trending toward your goal."
                    )

                    CelebrationMessage(
                        delta: latestData.delta
                    )
                }
            } else {
                EmptyStateView()
            }
        }
    }
}

struct PremiumGateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundColor(.screenSpanBlue)

            VStack(spacing: 8) {
                Text("Premium Feature")
                    .font(.headline)

                Text("Weekly trends and insights are available with a Premium subscription.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            Button(action: {}) {
                Text("Upgrade to Premium")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.screenSpanBlue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color.screenSpanOffWhite)
        .cornerRadius(12)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.title2)
                .foregroundColor(.gray)

            Text("Not Enough Data")
                .font(.headline)

            Text("Check back after tracking for a full week to see trends.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.screenSpanOffWhite)
        .cornerRadius(8)
    }
}

struct TrendDeltaCard: View {
    let label: String
    let delta: Double
    let unit: String

    var deltaLabel: String {
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", delta)) \(unit)"
    }

    var deltaColor: Color {
        delta < 0 ? .screenSpanBlue : .screenSpanRed
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.gray)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: delta < 0 ? "arrow.down" : "arrow.up")
                    .font(.caption)
                Text(deltaLabel)
                    .font(.headline)
            }
            .foregroundColor(deltaColor)
        }
        .padding()
        .background(Color.screenSpanOffWhite)
        .cornerRadius(8)
    }
}

struct LifeReclaimedCallout: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .foregroundColor(.screenSpanBlue)

            Text(message)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding()
        .background(Color.screenSpanBlue.opacity(0.1))
        .cornerRadius(8)
    }
}

struct CelebrationMessage: View {
    let delta: Double

    var celebrationText: String {
        if delta < -2 {
            return "Fantastic improvement!"
        } else if delta < 0 {
            return "Good progress this week!"
        } else {
            return "Challenge yourself further!"
        }
    }

    var body: some View {
        Text(celebrationText)
            .font(.caption)
            .foregroundColor(.screenSpanBlue)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
            .background(Color.screenSpanBlue.opacity(0.05))
            .cornerRadius(8)
    }
}
