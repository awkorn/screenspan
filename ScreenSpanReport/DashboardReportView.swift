import SwiftUI

/// All three pages use this configuration in one report instance. Tab selection
/// stays inside the extension and never changes the host's context or filter.
struct DashboardReportView: View {
    let payload: ScreenTimeReportPayload
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            if payload.isAvailable {
                Text("iPhone activity · \(payload.days.count) reported days · excludes today")
                    .font(.geist(size: 11))
                    .foregroundStyle(ScreenSpanAppearance.secondaryText)
                    .padding(.top, 8)
                Group {
                    switch page {
                    case 1: StatsReportView(payload: payload)
                    case 2: HistoryReportView(payload: payload)
                    default: ChartReportView(payload: payload)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(spacing: 6) {
                    tab("Life Grid", icon: "square.grid.3x3", value: 0)
                    tab("Stats", icon: "chart.pie", value: 1)
                    tab("Progress", icon: "chart.line.uptrend.xyaxis", value: 2)
                }
                .padding(7)
                .background(Color(hex: "#F6F7FA"), in: Capsule())
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
            } else {
                ScreenTimeUnavailableView(
                    title: "No recent activity available",
                    message: "Use this iPhone with Screen Time enabled, then try Refresh. Your report uses the last seven completed days."
                )
            }
        }
        .background(Color.white)
        .screenSpanLightSurface()
    }

    private func tab(_ title: String, icon: String, value: Int) -> some View {
        Button { page = value } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                Text(title).font(.geist(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(page == value ? Color.white : Color(hex: "#595959"))
            .background(page == value ? Color(hex: "#0A1F38") : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(page == value ? .isSelected : [])
    }
}

/// Both onboarding panels are rendered from one configuration. The host moves
/// its viewport in the required order; there is no optional in-report toggle.
struct OnboardingOverviewReportView: View {
    let payload: ScreenTimeReportPayload
    @AppStorage(SharedConstants.UserDefaultsKey.currentAge.rawValue, store: .appGroup)
    private var currentAge = 25
    @AppStorage(SharedConstants.UserDefaultsKey.targetAge.rawValue, store: .appGroup)
    private var targetAge = 80

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ScrollView {
                    OnboardingProjectionReportView(payload: payload)
                        .frame(minHeight: proxy.size.height / 2)
                }
                .frame(height: proxy.size.height / 2)
                .clipped()

                lifeChart
                    .frame(height: proxy.size.height / 2)
                    .clipped()
            }
        }
        .background(Color.white)
        .screenSpanLightSurface()
    }

    @ViewBuilder
    private var lifeChart: some View {
        if let average = payload.dailyAverageHours {
            let projection = ProjectionCalculator.calculateProjectionFromDaily(
                currentAge: currentAge, targetAge: targetAge, dailyHours: average)
            ScrollView {
                VStack(spacing: 18) {
                    LifeGridView(goalGridData: ProjectionCalculator.calculateLifeGrid(
                        currentAge: currentAge, targetAge: targetAge,
                        monthsOnPhone: projection.monthsOnPhone))
                    HStack(spacing: 16) {
                        legend("Lived", color: Color(hex: "#0063D6"))
                        legend("Screen time", color: Color(hex: "#F63232"))
                        legend("Remaining", color: Color(hex: "#D9D9D9"))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        } else {
            ScreenTimeUnavailableView(
                title: "Your life chart needs recent activity",
                message: "Screen Time has not returned activity yet. You can still choose a goal on the next screen.")
        }
    }

    private func legend(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).font(.geist(size: 12))
        }
    }
}
