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

/// Projection and grid reveal share the same loaded configuration, too.
struct OnboardingOverviewReportView: View {
    let payload: ScreenTimeReportPayload
    @State private var showGrid = false

    var body: some View {
        VStack(spacing: 0) {
            if showGrid {
                ChartReportView(payload: payload)
            } else {
                OnboardingProjectionReportView(payload: payload)
            }
            if payload.isAvailable {
                Button(showGrid ? "See your projection" : "See your life chart →") {
                    showGrid.toggle()
                }
                .font(.geist(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: "#0063D6"))
                .padding(16)
            }
        }
        .background(Color.white)
        .screenSpanLightSurface()
    }
}
