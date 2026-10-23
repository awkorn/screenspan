import SwiftUI

/// All three pages use this configuration in one report instance. Tab selection
/// stays inside the extension and never changes the host's context or filter.
struct DashboardReportView: View {
    let payload: ScreenTimeReportPayload
    @State private var page = 0
    @AppStorage(SharedConstants.UserDefaultsKey.dashboardBottomInset.rawValue, store: .appGroup)
    private var hostBottomInset = 0.0

    var body: some View {
        // The host extends the report under the home indicator; the tab bar
        // sits above it whether or not iOS passes the safe area through.
        GeometryReader { proxy in
            content(bottomInset: max(proxy.safeAreaInsets.bottom, hostBottomInset))
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .background(Color.white)
        .screenSpanLightSurface()
    }

    private func content(bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            if payload.isAvailable {
                Group {
                    switch page {
                    case 1: StatsReportView(payload: payload)
                    case 2: HistoryReportView(payload: payload)
                    default: ChartReportView(payload: payload)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Floats over the page; scrolling content shows around it.
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    tabBar.padding(.bottom, bottomInset + 6)
                }
            } else {
                ScreenTimeUnavailableView(
                    title: "No recent activity available",
                    message: "Use this iPhone with Screen Time enabled, then try Refresh. Your report uses the last seven completed days."
                )
                .padding(.bottom, bottomInset)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            tab("Life Grid", icon: "square.grid.3x3", value: 0)
            tab("Stats", icon: "chart.pie", value: 1)
            tab("Progress", icon: "chart.line.uptrend.xyaxis", value: 2)
        }
        .padding(4)
        .background(Color(hex: "#F6F7FA"), in: Capsule())
        // Keeps the bar distinct over cards of the same gray.
        .overlay(Capsule().strokeBorder(Color(hex: "#E1E5EB"), lineWidth: 1))
        .padding(.horizontal, 40)
    }

    private func tab(_ title: String, icon: String, value: Int) -> some View {
        Button { page = value } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                Text(title).font(.geist(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .foregroundStyle(page == value ? Color.white : Color(hex: "#595959"))
            .background(page == value ? Color(hex: "#0A1F38") : .clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(page == value ? .isSelected : [])
    }
}

/// Data-source footnote for the pages built from the last seven days
/// (Life Grid and Stats). Progress uses a longer window, so it omits this.
struct ReportSourceNote: View {
    let payload: ScreenTimeReportPayload

    var body: some View {
        Text("iPhone activity · \(payload.days.count) reported days · excludes today")
            .font(.geist(size: 11))
            .foregroundStyle(ScreenSpanAppearance.secondaryText)
    }
}

/// Every onboarding reveal panel is rendered from one configuration. The host
/// moves its viewport in order; activity and app identities stay in here.
/// Without recent activity, the panels fall back to the user's own guess and
/// say so, rather than showing an invented number.
struct OnboardingOverviewReportView: View {
    let payload: ScreenTimeReportPayload
    @AppStorage(SharedConstants.UserDefaultsKey.currentAge.rawValue, store: .appGroup)
    private var currentAge = 25
    @AppStorage(SharedConstants.UserDefaultsKey.targetAge.rawValue, store: .appGroup)
    private var targetAge = 80
    @AppStorage(SharedConstants.UserDefaultsKey.estimatedDailyMinutes.rawValue, store: .appGroup)
    private var estimatedMinutes = 0.0

    var body: some View {
        if let data = revealData {
            OnboardingRevealPanels(data: data)
        } else {
            ScreenTimeUnavailableView(
                title: "No recent activity yet",
                message: "Screen Time hasn't reported activity on this iPhone. Go back and add your estimate to see your projection.")
        }
    }

    private var revealData: RevealData? {
        let guess = estimatedMinutes > 0 ? estimatedMinutes / 60 : nil
        let intentions = TimeIntention.resolve(
            UserDefaults.appGroup.stringArray(forKey: SharedConstants.UserDefaultsKey.timeIntentions.rawValue))
        if let measured = payload.dailyAverageHours {
            return RevealData(
                dailyHours: measured, isMeasured: true, guessHours: guess,
                currentAge: currentAge, targetAge: targetAge,
                pickupsPerDay: payload.pickupsPerDay,
                topApps: payload.topApps.prefix(3).map {
                    RevealApp(dailyHours: $0.dailyHours, label: AnyView(AppNameLabel(app: $0)))
                },
                intentions: intentions)
        }
        guard let guess else { return nil }
        return RevealData(dailyHours: guess, isMeasured: false, guessHours: guess,
                          currentAge: currentAge, targetAge: targetAge, intentions: intentions)
    }
}
