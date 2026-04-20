import SwiftUI
import DeviceActivity

/// Life grid chart tab.
///
/// PRIVACY MODEL
/// -------------
/// The life grid visualization is derived from daily screen time hours,
/// which are per-user Screen Time data. Per Apple's privacy model, that
/// data may only be touched inside the `DeviceActivityReport` extension.
/// This view is a thin host that embeds the `ScreenSpanReport` extension
/// via `DeviceActivityReport(.chart, filter:)`; the grid, the goal
/// slider's usage-derived reference values, and the legend are all drawn
/// by the extension process.
struct ChartTabView: View {
    @EnvironmentObject private var authService: AuthorizationService

    var body: some View {
        Group {
            if authService.isAuthorized {
                DeviceActivityReport(
                    .chart,
                    filter: .screenSpanDaily
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                authorizationRequiredView
            }
        }
        .background(Color.white.ignoresSafeArea())
    }

    private var authorizationRequiredView: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "square.grid.3x3.topleft.filled")
                .font(.geist(size: 40, weight: .semibold))
                .foregroundStyle(Color(hex: "#102847"))

            VStack(spacing: 8) {
                Text("Enable Screen Time to load your Life Grid")
                    .font(.geist(size: 22, weight: .bold))
                    .foregroundStyle(Color(hex: "#102847"))

                Text("The Life Grid now comes from the Device Activity report extension, so the chart stays empty until Screen Time access is approved.")
                    .font(.geist(size: 15))
                    .foregroundStyle(Color(hex: "#595959"))
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await authService.requestAuthorization()
                }
            } label: {
                Text("Allow Screen Time Access")
                    .onboardingPrimaryButtonStyle()
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}
