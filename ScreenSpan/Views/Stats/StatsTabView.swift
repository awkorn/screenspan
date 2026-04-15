import SwiftUI

/// Statistics tab displaying user's screen time metrics
struct StatsTabView: View {
    @State private var viewModel = StatsViewModel()

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
        .task {
            viewModel.loadData()
        }
    }

    private var heroYearsSection: some View {
        VStack(spacing: 8) {
            Text(yearsTitle)
                .font(.system(size: 36, weight: .heavy))
                .foregroundStyle(Color(hex: "#0A1F38"))
                .multilineTextAlignment(.center)
                .monospacedDigit()

            Text("projected on your phone")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(hex: "#595959"))
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 24)
    }

    private var donutChartSection: some View {
        VStack(spacing: 16) {
            DonutChartView(
                phoneTime: projection?.dailyPhoneHours ?? 0,
                totalWakingHours: SharedConstants.DefaultValues.wakeHoursPerDay
            )
        }
    }

    private var statCardsSection: some View {
        HStack(spacing: 14) {
            statTile(
                icon: "calendar",
                value: projection.map { formatWholeNumber($0.monthsOnPhone) } ?? "--",
                label: "months"
            )

            statTile(
                icon: "sun.max",
                value: projection.map { formatWholeNumber($0.daysOnPhone) } ?? "--",
                label: "days"
            )

            statTile(
                icon: "clock",
                value: projection.map { formatWholeNumber($0.hoursOnPhone) } ?? "--",
                label: "hours"
            )
        }
    }

    private var projection: ProjectionResult? {
        viewModel.projection
    }

    private var yearsTitle: String {
        guard let projection else { return "-- YEARS" }
        return String(format: "%.1f YEARS", projection.yearsOnPhone)
    }

    private func statTile(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: "#235187"))
                .frame(height: 20)

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "#0D141C"))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 14, weight: .medium))
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
