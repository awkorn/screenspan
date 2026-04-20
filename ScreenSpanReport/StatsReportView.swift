import SwiftUI
import DeviceActivity

/// Stats view rendered inside the `DeviceActivityReport` extension.
///
/// IMPORTANT: This view is the ONLY place allowed to render raw numeric
/// screen-time values. The host app passes no usage data in; it instead
/// embeds this whole view via `DeviceActivityReport(.stats, filter:)`.
///
/// Takes a single scalar (`dailyAverageHours`) that is produced by the
/// extension's `DeviceActivityReportScene` from `DeviceActivityResults`,
/// and derives projection math from it + user-entered age settings
/// (currentAge / targetAge) read from the shared App Group.
///
/// Visuals mirror the original `StatsTabView` from the host app:
///  • hero "X.X YEARS" + "projected on your phone" subtitle
///  • `DonutChartView` of phone hours vs. remaining waking hours
///  • three stat tiles (months / days / hours on phone)
struct StatsReportView: View {
    let dailyAverageHours: Double

    @AppStorage(SharedConstants.UserDefaultsKey.currentAge.rawValue, store: .appGroup)
    private var currentAge: Int = 30

    @AppStorage(SharedConstants.UserDefaultsKey.targetAge.rawValue, store: .appGroup)
    private var targetAge: Int = SharedConstants.DefaultValues.targetAge

    private var projection: ProjectionResult {
        ProjectionCalculator.calculateProjectionFromDaily(
            currentAge: currentAge,
            targetAge: targetAge,
            dailyHours: dailyAverageHours
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 36) {
                heroYearsSection
                donutChartSection
                statCardsSection
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 120)
        }
        .background(Color.white.ignoresSafeArea())
    }

    private var heroYearsSection: some View {
        VStack(spacing: 8) {
            Text(yearsTitle)
                .font(.geist(size: 36, weight: .heavy))
                .foregroundStyle(Color(hex: "#0A1F38"))
                .multilineTextAlignment(.center)
                .monospacedDigit()

            Text("projected on your phone")
                .font(.geist(size: 16, weight: .medium))
                .foregroundStyle(Color(hex: "#595959"))
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 24)
    }

    private var donutChartSection: some View {
        VStack(spacing: 16) {
            DonutChartView(
                phoneTime: projection.dailyPhoneHours,
                totalWakingHours: SharedConstants.DefaultValues.wakeHoursPerDay
            )
        }
    }

    private var statCardsSection: some View {
        HStack(spacing: 14) {
            statTile(
                icon: "calendar",
                value: formatWholeNumber(projection.monthsOnPhone),
                label: "months"
            )

            statTile(
                icon: "sun.max",
                value: formatWholeNumber(projection.daysOnPhone),
                label: "days"
            )

            statTile(
                icon: "clock",
                value: formatWholeNumber(projection.hoursOnPhone),
                label: "hours"
            )
        }
    }

    private var yearsTitle: String {
        String(format: "%.1f YEARS", projection.yearsOnPhone)
    }

    private func statTile(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.geist(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: "#235187"))
                .frame(height: 20)

            Text(value)
                .font(.geist(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "#0D141C"))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.geist(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: "#595959"))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 102)
        .background(Color(hex: "#F6F7FA"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func formatWholeNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSNumber(value: value)) ?? String(Int(value.rounded()))
    }
}
