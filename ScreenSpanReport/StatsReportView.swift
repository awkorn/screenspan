import SwiftUI
import DeviceActivity
import Charts

/// Stats view rendered in the DeviceActivityReport extension
/// Displays hero years number, donut chart, stat cards, and reclaim preview
struct StatsReportView: View {
    let dailyAverageHours: Double

    // Shared UserDefaults
    @AppStorage(SharedConstants.UserDefaultsKey.currentAge.rawValue, store: .appGroup)
    private var currentAge: Int = 30

    @AppStorage(SharedConstants.UserDefaultsKey.targetAge.rawValue, store: .appGroup)
    private var targetAge: Int = SharedConstants.DefaultValues.targetAge

    @AppStorage(SharedConstants.UserDefaultsKey.screenTimeGoalMinutes.rawValue, store: .appGroup)
    private var screenTimeGoalMinutes: Int = 120

    @AppStorage(SharedConstants.UserDefaultsKey.onboardingProjectedYears.rawValue, store: .appGroup)
    private var onboardingProjectedYears: Double = 0

    @AppStorage(SharedConstants.UserDefaultsKey.subscriptionStatus.rawValue, store: .appGroup)
    private var subscriptionStatus: String = "free"

    private var projection: ProjectionResult {
        ProjectionCalculator.calculateProjectionFromDaily(
            currentAge: currentAge,
            targetAge: targetAge,
            dailyHours: dailyAverageHours
        )
    }

    private var reclaim: ReclaimResult {
        ProjectionCalculator.calculateReclaim(
            currentProjection: projection,
            goalDailyMinutes: Double(screenTimeGoalMinutes),
            currentAge: currentAge,
            targetAge: targetAge
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero Years Number
                VStack(spacing: 8) {
                    Text("Years Reclaimed")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text(String(format: "%.1f", reclaim.yearsReclaimed))
                        .font(.system(size: 48, weight: .bold, design: .default))
                        .foregroundColor(.screenSpanBlue)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.screenSpanOffWhite)
                .cornerRadius(12)

                // Donut Chart
                VStack(spacing: 12) {
                    Chart {
                        SectorMark(
                            angle: .value("Reclaimed", reclaim.yearsReclaimed),
                            innerRadius: .ratio(0.7),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color.screenSpanBlue)

                        SectorMark(
                            angle: .value("Without Change", projection.yearsOnPhone),
                            innerRadius: .ratio(0.7),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color.screenSpanLightGray)
                    }
                    .frame(height: 200)

                    HStack(spacing: 16) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.screenSpanBlue)
                                .frame(width: 12, height: 12)
                            Text("Reclaimed")
                                .font(.caption)
                        }
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.screenSpanLightGray)
                                .frame(width: 12, height: 12)
                            Text("Without Change")
                                .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color.screenSpanOffWhite)
                .cornerRadius(12)

                // Stat Cards
                VStack(spacing: 12) {
                    StatCard(
                        label: "Months",
                        value: String(Int(reclaim.monthsReclaimed)),
                        icon: "calendar"
                    )
                    StatCard(
                        label: "Days",
                        value: String(Int(projection.daysOnPhone)),
                        icon: "calendar.circle"
                    )
                    StatCard(
                        label: "Hours",
                        value: String(Int(projection.hoursOnPhone)),
                        icon: "clock"
                    )
                }

                // Reclaim Preview
                VStack(spacing: 12) {
                    Text("Your Potential")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("At current pace, you'll reclaim \(String(format: "%.1f", reclaim.yearsReclaimed)) years.")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.screenSpanOffWhite)
                    .cornerRadius(8)
                }
                .padding(.top, 12)
            }
            .padding()
        }
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.screenSpanBlue)
                .frame(width: 32, height: 32)
                .background(Color.screenSpanBlue.opacity(0.1))
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            Spacer()
        }
        .padding()
        .background(Color.screenSpanOffWhite)
        .cornerRadius(8)
    }
}
